maintainer       "Myles Carrick"
maintainer_email "myles@mylescarrick.com"
license          "All rights reserved"
description      "Installs/Configures aaibs"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"

%w{apache2 passenger_apache2 git database postgresql memcached}.each do |cb|
  depends cb
end

%w{ubuntu debian}.each do |os|
  supports os
end
