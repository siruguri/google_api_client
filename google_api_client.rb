require 'net/https'
require 'uri'

module GoogleApiClient
  class BadConfigException < Exception
  end
  class AuthenticationException < Exception
  end

  class GoogleApiClient
    def initialize(config=nil)
      raise BadConfigException, "Config is empty" if config.nil?

      @config=config

      @token=nil
      @http = Net::HTTP.new('www.google.com', 443)
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end


    def authenticate
      # elements of auth 

      # Only authenticate once
      return '200' if @token

      path = '/accounts/ClientLogin'
      data = "accountType=#{@config['client_login_account_type']}&Email=#{@config['client_login_email']}&Passwd=#{@config['client_login_pwd']}&service=#{@config['client_login_service_name']}&source=#{config['source']}"
      headers = {"Content-Type"=>"application/x-www-form-urlencoded"}

      # Post the request and print out the response to retrieve our authentication token
      resp = @http.post(path, data, headers)
      if resp.code == '200' then
        @token = resp.body[/Auth=(.*)/, 1]
        @headers={}
        # Build our headers hash and add the authorization token
        @headers["Authorization"] = "GoogleLogin auth=#{@token}"

        # Returning the code
        '200'
      else
        nil
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

    def post_data(post_data, headers=nil)
      if headers.nil?
        h = @headers
      else
        h = @headers.merge headers
      end

      @http.post(@endpoint, post_data, h)
    end
  end

  def self.create(config)
    return GoogleApiClient.new(config)
  end
    
end
