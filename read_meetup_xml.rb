require 'pp'
require 'xmlsimple'

file = open(ARGV[0], 'r')
xml=file.readlines

doc =  XmlSimple.xml_in(ARGV[0], 'KeyAttr' => 'name')
doc['items'][0]['item'].each { |h| puts "make_marker(#{h['lat'][0]}, #{h['lon'][0]}, \"#{h['city'][0]}\", map);"}
