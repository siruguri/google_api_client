require_relative "google_contacts_api"

client = GoogleContactsApi.create

atom = client.new_contact_atom

puts atom.class == GoogleContactsApi::ContactAtom

atom.add_name(givenName: "Sameer",
              familyName: "Siruguri",
              fullName: "Sameer Siruguri")
exp = '{"xmlns:atom"=>"http://www.w3.org/2005/Atom", "xmlns:gd"=>"http://schemas.google.com/g/2005", "atom:category"=>[{"scheme"=>"http://schemas.google.com/g/2005#kind", "term"=>"http://schemas.google.com/contact/2008#contact"}], "gd:name"=>[{"gd:givenName"=>["Sameer"], "gd:familyName"=>["Siruguri"], "gd:fullName"=>["Sameer Siruguri"]}]}'

puts atom.to_s==exp

atom.add_name(givenName: "Megan",
              familyName: "Williams",
              fullName: "Megan Williams")
