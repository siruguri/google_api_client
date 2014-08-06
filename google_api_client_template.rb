require 'parseconfig'
require 'xmlsimple'
require 'uri'
require 'rubygems'
require 'pp'
require_relative "./google_api_client"

class GoogleContactsApi < GoogleApiClient::GoogleApiClient
  def initialize
    super
    @endpoint='/m8/feeds/contacts/cclr.org/full';
  end

  def atom_xml(elt_array) 
    str = ''
    elt_array.each do |elt|
      str += "<#{elt[0]} "

      if elt[1][:attr]
        elt[1][:attr].each do |attr_key, attr_value|
          str += "#{attr_key}='#{attr_value}' "
        end
      end
      str += " > "

      if elt[1][:children]
        str += atom_xml(elt[1][:children])
      end

      # Not checking that a tag has both children and value, which is not allowed.
      if elt[1][:value]
        str += " #{elt[1][:value]} "
      end

      # Returning str
      str += " </#{elt[0]}> "
    end

    str
  end

  def contact_list
    @http.get(@endpoint, @headers)
  end

  def generate_atom(options)
    entry_elements = 
      [["atom:entry", {attr: {"xmlns:atom" => 'http://www.w3.org/2005/Atom', "xmlns:gd" => 'http://schemas.google.com/g/2005'}, children: [
                                                                                                                                           ["atom:category", {attr: {'scheme' => 'http://schemas.google.com/g/2005#kind', 'term' => 'http://schemas.google.com/contact/2008#contact'}}],
                                                                                                                                           ["gd:name", {children:  [["gd:fullName", {value: options[:fullname]}], 
                                                                                                                                                                    ["gd:familyName", {value: options[:familyname]}]]}],
                                                                                                                                           ['atom:content', {attr: {'type' => 'text'}, value: 'Notes'}],
                                                                                                                                           ['gd:email', {attr: {'rel' => 'http://schemas.google.com/g/2005#work', 'primary' => 'true', 'address'=>options[:email], 'displayName' => options[:displayname]}}]
                                                                                                                                          ]}
       ]]

    atom_xml(entry_elements)
  end

  def new_contact(name_card)
    # Returns the response
    puts "Creating new contact..."
    new_entry_xml = api_client.generate_atom(name_card)
    headers = {'Content-Type' => 'application/atom+xml'}

    resp=self.post_data(new_entry_xml, headers); pp resp.body
    atom_array(resp)
  end

  def delete_all_contacts(atom_str)
    return '' if (x=atom_to_array(atom_str)['entry']).nil?

    x.each do |contact|
      delete_ept = (contact['link'].select { |l| l['rel']=='edit' })[0]['href']
      puts ">>> Deleting #{delete_ept}"
      self.delete_data(delete_ept)
    end
  end

  private
  def atom_to_array(atom_str)
    return XmlSimple.xml_in(atom_str)
  end

  def get_feed(uri, headers=nil)
    uri = URI.parse(uri)
    Net::HTTP.start(uri.host, uri.port) do |http|
      http.get(uri.path, headers)
    end
  end
end

begin
  config=ParseConfig.new('google_client_config.ini')
rescue Errno::EACCES => e
  $stderr.write("There needs to be a config file called google_client_config.ini (#{e.class}, #{e.message})\n")
  exit -1
end

api_client = GoogleContactsApi.new
auth_code = api_client.authenticate config
if auth_code.nil?
  $stderr.write("Authentication failed.")
  exit -1
end

# spreadsheets_uri = 'http://spreadsheets.google.com/feeds/spreadsheets/private/full'
# This is deprecated now - docs_uri = 'http://docs.google.com/feeds/docs/private/full'; uri = docs_uri
resp = api_client.contact_list

#  doc =  XmlSimple.xml_in(my_list.body)
pp resp.body
api_client.delete_all_contacts resp.body

name_card = {fullname: 'Elizabeth Bentest', familyname: 'Bentest', email: 'elizabethbentest@gmail.com', displayname: 'E. Bentest, Esq.'}

# api_client.new_contact(name_card)

