require 'xmlsimple'
require 'pp'
require_relative "./google_api_client"

module GoogleContactsApi
  def self.create config=nil
    return GoogleContactsApi.new config
  end

  class Atom
    def initialize
      @_h = {}
    end
    def children
      @_h.select do |k, v|
        v.class == Array
      end
    end
  end
  
  class ContactAtom < Atom
    def initialize
      super
      @_h.merge!({'xmlns:atom' => 'http://www.w3.org/2005/Atom', 'xmlns:gd' => 'http://schemas.google.com/g/2005'})
      @_h['atom:category']=[]
      @_h['atom:category']<<{'scheme' => 'http://schemas.google.com/g/2005#kind', 
        'term' => 'http://schemas.google.com/contact/2008#contact'}      
    end

    def to_s
      @_h.to_s
    end
    def to_atom
      x={'atom:entry' => []}
      x['atom:entry'] << @_h
      XmlSimple.xml_out(x, {'KeepRoot' => true})
    end

    def add_name(options)      
      if @_h['gd:name'].nil?
        @_h['gd:name'] = []
        @_h['gd:name'] << {'gd:givenName' => [options[:givenName]], 'gd:familyName' => [options[:familyName]],
          'gd:fullName' => [options[:fullName]]}
      end
      self
    end

    def add_email(options)
      @_h['gd:email'] ||= []
      @_h['gd:email'] << {'rel' => options[:rel], 'primary' => options[:primary].to_s, 'address' => options[:address],
        'displayName' => options[:displayName]}
      self
    end

    def add_phone(options)
      @_h['gd:phoneNumber'] ||= []
      @_h['gd:phoneNumber'] << {'rel' => options[:rel], 'primary' => options[:primary].to_s, 'content' => options[:number]}
      self
    end
  end

  class GoogleContactsApi < GoogleApiClient::GoogleApiClient
    def initialize config
      super config
      @endpoint= config[:endpoint] || '/m8/feeds/contacts/default/full';
      @batch_endpoint = config[:batch_endpoint] || '/m8/feeds/contacts/default/full/batch'
    end

    def initialize_batch
      _h = {}
      _h['feed'] = []
      _h['feed'] << {'xmlns' => 'http://www.w3.org/2005/Atom', 'xmlns:gContact' => 'http://schemas.google.com/contact/2008',
        'xmlns:gd' => 'http://schemas.google.com/g/2005', 'xmlns:batch' => 'http://schemas.google.com/gdata/batch'}

      _h['feed'][0]['category'] = []
      _h['feed'][0]['category'] << {'scheme' => 'http://schemas.google.com/g/2005#kind',
        'term' => 'http://schemas.google.com/g/2008#contact'}

      _h
    end

    def contact_list
      auth_code = self.authenticate
      if auth_code.nil?
        raise AuthenticationException, "Authentication failed."
      end

      @http.get(@endpoint, @headers)
    end
    alias :all_contacts :contact_list

    def new_contact_atom
      return ContactAtom.new
    end
    def new_contact(name_card)
      # Returns the response
      puts "Creating new contact..."
      new_entry_xml = generate_atom(name_card)
      headers = {'Content-Type' => 'application/atom+xml'}

      resp=self.post_data(new_entry_xml, headers: headers); pp resp.body
      atom_to_array(resp.body)
    end

    def delete_all_contacts(atom_str)
      return '' if (x=atom_to_array(atom_str)['entry']).nil?

      x.each do |contact|
        delete_ept = (contact['link'].select { |l| l['rel']=='edit' })[0]['href']
        puts ">>> Deleting #{delete_ept}"
        self.delete_data(delete_ept)
      end
    end

    def send_batch(entries)
      batches = []

      counter = 0
      batch_id = 1
      current_batch = self.initialize_batch
      current_batch['feed'][0]['entry'] = []

      entries.each do |entry|
        counter += 1
        child = {'batch:id' => [batch_id], 'batch:operation' => {'type' => 'insert'}}
        batch_id += 1

        child.merge! entry.children
        child['category'] = child['atom:category']
        child.delete 'atom:category'

        current_batch['feed'][0]['entry'] << child

        if counter % 100 == 0
          batches << current_batch 
          # puts current_batch.to_s

          current_batch = @api_client.initialize_batch
          current_batch['feed'][0]['entry'] = []
        end
      end

      if current_batch['feed'][0]['entry'].size > 0
        batches << current_batch
        # puts current_batch.to_s
      end


      auth_code = self.authenticate
      if auth_code.nil?
        raise AuthenticationException, "Authentication failed."
      end

      batches.each do |b|
        feed_post = XmlSimple.xml_out(b, {'KeepRoot' => true}); puts feed_post
        resp = self.post_data(feed_post, endpoint: @batch_endpoint); pp resp.body
      end
      # Return a response at the end of this.
    end

    private
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
end
