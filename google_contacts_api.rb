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
        @_h["title"]=[{'type'=> 'text', 'content' => options[:fullName]}]
        @_h['gd:name'] = []
        @_h['gd:name'] << {'gd:givenName' => [options[:givenName]], 'gd:familyName' => [options[:familyName]]
          }
      end
      self
    end

    def add_organization(options)
      @_h['gd:organization'] ||= []
      @_h['gd:organization'] << 
        {'rel' => "http://schemas.google.com/g/2005#work", 'primary' => 'true',
        'gd:orgName' => [options[:organization_name]]}

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
    attr_reader :contact_list
    attr_accessor :batch_endpoint
    
    def initialize config
      super config
      @endpoint= config['endpoint'] || '/m8/feeds/contacts/cclr.org/full'
      @host = config['host'] || 'https://www.google.com'
      @batch_endpoint = config['batch_endpoint'] || '/m8/feeds/contacts/cclr.org/private/full/batch'
      @contact_list = nil
    end

    def contact_list_info
      mesg = ''
      mesg += "#{@contact_list.size} entries.\n"

      # mesg += @contact_list.to_s
      mesg += pp(@contact_list)

      mesg
    end

    def fetch_all_contacts
      self.authenticate
      contact_resp = all_contacts_data

      @atom_body = contact_resp.body
      @contact_list = atom_to_array contact_resp.body
    end

    def fetch_one_contact(id_url)
      self.authenticate
      execute_hash = {uri: id_url, # "https://www.google.com/m8/feeds/contacts/cclr.org/full",
                      headers: { 'GData-Version' => '3.0', 'Content-Type' => 'application/atom+xml'}}
      resp = @client.execute execute_hash
      puts resp.body
    end

    def new_contact_atom
      return ContactAtom.new
    end

    def delete_all_contacts(atom_entries)
      return '' if atom_entries['entry'].nil?

      x.each do |contact|
        delete_ept = (contact['link'].select { |l| l['rel']=='edit' })[0]['href']
        puts ">>> Deleting #{delete_ept}"
        self.delete_data(delete_ept)
      end
    end

    def send_batch(entries, command='create')
      # entries is assumed to be an object of class ContactAtom
      batches = []

      counter = 0
      batch_id = 1
      current_batch = initialize_batch
      current_batch['feed'][0]['entry'] = []

      entries.each do |entry|
        counter += 1
        child = {'category' => [{'scheme' => 'http://schemas.google.com/g/2005#kind', 'term' => 'http://schemas.google.com/g/2008#contact'}],
                 'batch:id' => ["#{command}"], 'batch:operation' => [{'type' => "#{command == 'delete' ? command : 'insert'}"}]}

        if command == 'delete'
          child.merge!({'gd:etag' => 'deleteContactEtag'})
        end
        batch_id += 1

        if command == 'create'
          if entry.class==ContactAtom
            child.merge!(entry.children.delete_if { |k, v| k == 'atom:category' })
          else
            child.merge! entry
          end
        elsif command == 'delete'

          # TODO this only works for an array representing the atom feed, not for ContactAtom objects
          # child.merge! entry.select { |k,v| k=='id' || k == 'link'}
          child.merge!({'gd:etag' => "#{entry['gd$etag']}", 'id' => [entry['link'][1]['href']]})
        end

        if child['atom:category'] # There won't be any, if we didn't run an insert.
          child.delete 'atom:category'
        end
        current_batch['feed'][0]['entry'] << child

        if counter % 100 == 0
          batches << current_batch 
          puts ">>> Created a batch"

          current_batch = initialize_batch
          current_batch['feed'][0]['entry'] = []
        end
      end

      if current_batch['feed'][0]['entry'].size > 0
        batches << current_batch
        # puts current_batch.to_s
      end

      batches.each do |b|

        feed_post = XmlSimple.xml_out(b, {'KeepRoot' => true}); 
        puts ">>> Sending batch with #{b['feed'][0]['entry'].size} entries"
        feed_post = "<?xml version='1.0' encoding='UTF-8'?>\n#{feed_post}"

        resp = self.post_data(feed_post, endpoint: @host + @batch_endpoint, headers: {'Content-Type' => 'application/atom+xml'})
        pp resp.body
      end

      # TODO Return a response at the end of this.
    end

    private
    def all_contacts_data
      if 1
        execute_hash = {uri: @host + @endpoint, # "https://www.google.com/m8/feeds/contacts/cclr.org/full",
                        parameters: { 'alt' => 'json',
                                      'max-results' => '100000' },
                        headers: { 'GData-Version' => '3.0', 'Content-Type' => 'application/atom+xml'}}
        @client.execute execute_hash
      else
        # Pre Google OAuth 2.0
        @client.retrieve_data(@endpoint, @headers)
      end
    end
    
    def initialize_batch
      _h = {}
      _h['feed'] = []
      _h['feed'] << {'xmlns' => 'http://www.w3.org/2005/Atom', 'xmlns:gContact' => 'http://schemas.google.com/contact/2008',
        'xmlns:gd' => 'http://schemas.google.com/g/2005', 'xmlns:batch' => 'http://schemas.google.com/gdata/batch'}
      _h
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

    def atom_to_array(atom_str)
      #return XmlSimple.xml_in(atom_str)

      JSON.parse(atom_str)['feed']['entry']
    end

    def get_feed(uri, headers=nil)
      uri = URI.parse(uri)
      Net::HTTP.start(uri.host, uri.port) do |http|
        http.get(uri.path, headers)
      end
    end
  end
end
