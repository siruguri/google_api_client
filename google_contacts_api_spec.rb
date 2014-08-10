require_relative "google_contacts_api"
require 'parseconfig'

p = ParseConfig.new("/users/sameer/Digital Strategies/clients/cclr/cclr_config.ini")

client = GoogleContactsApi.create p

atom1 = client.new_contact_atom

puts atom1.class == GoogleContactsApi::ContactAtom

atom1.add_name(givenName: "Sameer",
              familyName: "Siruguri",
              fullName: "Sameer Siruguri")
exp = '{"xmlns:atom"=>"http://www.w3.org/2005/Atom", "xmlns:gd"=>"http://schemas.google.com/g/2005", "atom:category"=>[{"scheme"=>"http://schemas.google.com/g/2005#kind", "term"=>"http://schemas.google.com/contact/2008#contact"}], "gd:name"=>[{"gd:givenName"=>["Sameer"], "gd:familyName"=>["Siruguri"], "gd:fullName"=>["Sameer Siruguri"]}]}'

puts atom1.to_s==exp

atom2 = client.new_contact_atom
atom2.add_name(givenName: "Megan",
               familyName: "Williams",
               fullName: "Megan Williams")

exp='{"feed"=>[{"xmlns"=>"http://www.w3.org/2005/Atom", "xmlns:gContact"=>"http://schemas.google.com/contact/2008", "xmlns:gd"=>"http://schemas.google.com/g/2005", "xmlns:batch"=>"http://schemas.google.com/gdata/batch", "category"=>[{"scheme"=>"http://schemas.google.com/g/2005#kind", "term"=>"http://schemas.google.com/g/2008#contact"}]}], "entry"=>[{"batch:id"=>[1], "batch:operation"=>{"type"=>"insert"}, "atom:category"=>[{"scheme"=>"http://schemas.google.com/g/2005#kind", "term"=>"http://schemas.google.com/contact/2008#contact"}], "gd:name"=>[{"gd:givenName"=>["Sameer"], "gd:familyName"=>["Siruguri"], "gd:fullName"=>["Sameer Siruguri"]}]}, {"batch:id"=>[2], "batch:operation"=>{"type"=>"insert"}, "atom:category"=>[{"scheme"=>"http://schemas.google.com/g/2005#kind", "term"=>"http://schemas.google.com/contact/2008#contact"}], "gd:name"=>[{"gd:givenName"=>["Megan"], "gd:familyName"=>["Williams"], "gd:fullName"=>["Megan Williams"]}]}]}'

puts exp == client.send_batch([atom1, atom2])
