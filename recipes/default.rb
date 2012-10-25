#
# Cookbook Name:: aaibs
# Recipe:: default
#
# Copyright 2012, Myles Carrick
#
# All rights reserved - Do Not Redistribute
#
app = data_bag_item('webapps', 'aaibs')

file "/home/#{app['deploy_user']}/.ssh/id_rsa" do
  owner app['deploy_user']
  mode "0600"
  action :create
  content app['deploy_private_key']
end

application "aaibs" do
  path "/var/webapps/aaibs"
  owner "deploy"
  group "deploy"

  repository "git@github.com:mylescarrick/aaibs3.git"
  revision "master"

  rails do
    # Rails-specific configuration
  end

  passenger_apache2 do
    server_aliases ["beta.aaibs.org"]
  end
end