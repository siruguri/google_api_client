require 'parseconfig'
require 'xmlsimple'
require 'uri'
require 'rubygems'
require 'pp'
require_relative "./google_contacts_api"

begin
  config=ParseConfig.new('google_client_config.ini')
rescue Errno::EACCES => e
  $stderr.write("There needs to be a config file called google_client_config.ini (#{e.class}, #{e.message})\n")
  exit -1
end

api_client = GoogleContactsApi.create config
api_client.authenticate
# spreadsheets_uri = 'http://spreadsheets.google.com/feeds/spreadsheets/private/full'
# This is deprecated now - docs_uri = 'http://docs.google.com/feeds/docs/private/full'; uri = docs_uri
resp = api_client.contact_list; pp resp.body

#  doc =  XmlSimple.xml_in(my_list.body)

# api_client.delete_all_contacts resp.body

name_card = {fullname: 'Elizabeth Bentest', familyname: 'Bentest', email: 'elizabethbentest@gmail.com', displayname: 'E. Bentest, Esq.'}

# ret = api_client.new_contact(name_card); pp ret


