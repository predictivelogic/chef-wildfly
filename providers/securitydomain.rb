# encoding: UTF-8
# rubocop:disable LineLength, Metrics/AbcSize
#
# Copyright (C) 2014 Brian Dwyer - Intelligent Digital Services
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'etc'
include Chef::Mixin::ShellOut

use_inline_resources

# Support whyrun
def whyrun_supported?
  true
end

action :create do
  if @current_resource.exists
    Chef::Log.info "#{@new_resource} already exists - nothing to do."
  else
    converge_by("Create #{@new_resource}") do
      create_securitydomain
    end
  end
end

action :delete do
  if @current_resource.exists
    converge_by("Delete #{@new_resource}") do
      delete_securitydomain
    end
  else
    Chef::Log.info "#{@current_resource} doesn't exist - can't delete."
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WildflySecuritydomain.new(@new_resource.name)
  @current_resource.cache_type(@new_resource.cache_type)
  @current_resource.exists = true if securitydomain_exists?(@current_resource.name)
end

def securitydomain_exists?(name)
  result = shell_out("su #{node['wildfly']['user']} -s /bin/bash -c \"#{node['wildfly']['base']}/bin/jboss-cli.sh -c ' /subsystem=security/security-domain=#{name.gsub('/', '\/')}:read-resource'\"")
  result.exitstatus == 0
end

private

def create_securitydomain
  # params = %W(--name=#{new_resource.name} --jndi-name=#{new_resource.jndiname} --driver-name=#{new_resource.drivername} --connection-url=#{new_resource.connectionurl})
  # params << "--user-name=#{new_resource.username}" if new_resource.username
  # params << "--password=#{new_resource.password}" if new_resource.password

  bash "install_securitydomain #{new_resource.name} (add domain)" do
    user node['wildfly']['user']
    cwd node['wildfly']['base']
    code "bin/jboss-cli.sh -c command=\"/subsystem=security/security-domain=#{new_resource.name}/:add(cache-type=#{new_resource.cache_type})\""
    not_if { securitydomain_exists?(new_resource.name) }
  end
end

def delete_securitydomain
  bash "remove_securitydomain #{new_resource.name}" do
    user node['wildfly']['user']
    cwd node['wildfly']['base']
    code <<-EOH
      bin/jboss-cli.sh -c command="security-domain remove --name=#{new_resource.name}"
    EOH
    only_if { securitydomain_exists?(new_resource.name) }
  end
end
