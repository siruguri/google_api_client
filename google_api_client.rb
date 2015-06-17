require 'net/https'
require 'uri'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'


module GoogleApiClient
  class BadConfigException < Exception
  end
  class AuthenticationException < Exception
  end

  class GoogleApiClient
    def initialize(config=nil)
      raise BadConfigException, "Config is empty" if config.nil?

      @config=config
      @headers = { 'GData-Version' => '3.0', 'Content-Type' => 'application/atom+xml', 'If-Match' => '*'}
      @token=nil
      @http = Net::HTTP.new('www.google.com', 443)
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end


    def authenticate
      # elements of auth 

      # Only authenticate once; return '200' if successful; raise error if not
      return '200' if @token

      # Initialize the client.
      @client = Google::APIClient.new(
        :application_name => 'Example Ruby application',
        :application_version => '1.0.0'
      )

      # Initialize Google+ API. Note this will make a request to the
      # discovery service every time, so be sure to use serialization
      # in your production code. Check the samples for more details.

      # Load client secrets from your client_secrets.json.
#      client_secrets = Google::APIClient::ClientSecrets.load
      @client.authorization = :google_app_default  # in a later version, this will become the default
      @client.authorization.fetch_access_token!
      @token = true
      
      if 1
        '200'
      else
        raise AuthenticationException, "Authentication failed."
      end
    end

    def endpoint=(str)
      @endpoint = str
    end

    def retrieve_data
      # Run a get on the end point.
      @http.get(@endpoint, @headers)
    end

    def delete_data(endpoint=nil)
      # Run a delete on the end point.
      if endpoint.nil?
        endpoint = @endpoint
      end

      resp = @http.delete(endpoint, @headers)
      puts "Delete said: #{resp}\n"
      resp
    end

    def post_data(post_data, headers: nil, endpoint: nil) 
      # Post to the endpoint
      _e = endpoint || @endpoint
      # puts "Posting ... \n #{post_data} \n ... to #{_e}"

      self.authenticate
      h = @headers
      unless headers.nil?
        h = @headers.merge headers
      end

      if 1
        execute_hash = {uri: _e, # "https://www.google.com/m8/feeds/contacts/cclr.org/full/batch",
                        headers: h, http_method: 'post', body: post_data}
        ehg = {uri: 'https://www.google.com/m8/feeds/contacts/cclr.org/full/3ac44a08ef189f3',
               headers: h}
        @client.execute execute_hash
      else
        @http.post(_e, post_data, h)
      end
    end
  end

  def self.create(config)
    return GoogleApiClient.new(config)
  end
    
end
