#
# Cookbook Name:: aaibs
# Recipe:: default
#
# Copyright 2012, Myles Carrick
#
# MIT
#

include_recipe "apache2"
include_recipe "apache2::mod_rewrite" # is this needed?
include_recipe "apache2::mod_ssl"
include_recipe "passenger_apache2"
include_recipe "passenger_apache2::mod_rails"
include_recipe "memcached"

app = data_bag_item('webapps', 'aaibs')

# # Take care of the web root
docroot = "/srv/http/#{app['name']}"

# mount our other drives

filespath = "/webfiles/#{app['name']}"

directory filespath do
  owner app['deploy_user']
  group node['apache']['group']
  mode "0755"
  action :create
  recursive true
end

mount filespath do
  device "/dev/xvdc"
  fstype "ext3"
  options "rw"
  action [:mount, :enable]
end

link docroot + "/shared/public/system" do
  to filespath
end


["config", "tmp/pids", "tmp/cache", "log", "cached-copy", "public"].each do |d|
  dir = docroot + "/shared/" + d
  directory dir do
    owner app['deploy_user']
    group node['apache']['group']
    mode "0775"
    action :create
    recursive true
  end
end

file "/home/#{app['deploy_user']}/.ssh/id_rsa" do
  owner app['deploy_user']
  mode "0600"
  action :create
  content app['deploy_private_key']
end


postgresql_connection_info = {:host => "127.0.0.1", :port => 5432, :username => 'postgres', :password => node['postgresql']['password']['postgres']}

postgresql_database_user app['db_username'] do
  connection postgresql_connection_info
  password app['db_password']
  action :create
end

postgresql_database app['db_name'] do
  connection postgresql_connection_info
  action :create
end

postgresql_database_user app['db_username'] do
  connection postgresql_connection_info
  database_name app['db_name']
  action :grant
end

postgresql_database "hstore the database" do
  connection postgresql_connection_info
  database_name app['db_name']
  sql "CREATE EXTENSION IF NOT EXISTS hstore"
  action :query
end

memcached_instance app['name']

# Configure database.yml before symlinking
template "#{docroot}/shared/config/database.yml" do
  source "database.yml.erb"
  owner app['deploy_user']
  group app['deploy_user']
  mode "644"
  variables(
    :adapter => 'postgresql',
    :host => app['db_host'],
    :database => app['db_name'],
    :username => app['db_username'],
    :password => app['db_password'],
    :rails_env => app['rails_env']
  )
end

environment = {"RAILS_ENV" => app['rails_env']}

# Capistrano-style deploy
deploy docroot do
  repo app['git_repo']
  revision app['git_branch']
  user app['deploy_user']
  migrate true
  migration_command "rake db:migrate --trace"
  environment environment
  restart_command "touch tmp/restart.txt"
  shallow_clone true
  enable_submodules false
  action :force_deploy
  restart_command "touch tmp/restart.txt"
  scm_provider Chef::Provider::Git

  before_migrate do
    execute "bundle install --deployment --without development test" do
      cwd release_path
      user app['user']
      environment environment
    end
  end
  before_symlink do
    execute "rake assets:precompile" do
      cwd release_path
      user app['deploy_user']
      environment environment
    end
  end
end

web_app app['id'] do
  template "rails_app.conf.erb"
  docroot "#{docroot}/current/public"
  server_name server_fqdn
  server_aliases app['aliases']
  rails_env app['rails_env']
  enable true
end

apache_site "000-default" do
  enable false
end
