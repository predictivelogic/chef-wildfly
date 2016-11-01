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
  @current_resource.login_modules(@new_resource.login_modules)
  @current_resource.cache_type(@new_resource.cache_type)
  @current_resource.exists = true if securitydomain_exists?(@current_resource.name)
end

def securitydomain_exists?(name)
  result = shell_out("su #{node['wildfly']['user']} -s /bin/bash -c \"#{node['wildfly']['base']}/bin/jboss-cli.sh -c ' /subsystem=security/security-domain=#{name.gsub('/', '\/')}:read-resource'\"")
  result.exitstatus == 0
end

private

def create_securitydomain
  # It's a two step process to add a security domain and its login modules
  bash "install_securitydomain #{new_resource.name} (add domain)" do
    user node['wildfly']['user']
    cwd node['wildfly']['base']
    code "bin/jboss-cli.sh -c command=\"/subsystem=security/security-domain=#{new_resource.name}/:add(cache-type=#{new_resource.cache_type})\""
    not_if { securitydomain_exists?(new_resource.name) }
  end

  bash "install_securitydomain #{new_resource.name} (add login modules)" do
    login_modules_text = "login-modules=["
    new_resource.login_modules.each do |login_module|
      login_modules_text << "{"
      login_modules_text << "\"code\" => \"#{login_module['code']}\","
      login_modules_text << "\"flag\" => \"#{login_module['flag']}\","
      login_modules_text << '"module-options" => ['
      login_modules_text << login_module['module-options'].each.map { |module_option|
        "\"#{module_option[0]}\" => \"#{module_option[1]}\""
      }.join(',')
      login_modules_text << ']}]'
    end

    user node['wildfly']['user']
    cwd node['wildfly']['base']
    code "bin/jboss-cli.sh -c command=\"/subsystem=security/security-domain=#{new_resource.name}/authentication=classic:add(#{login_modules_text})\""
    only_if { securitydomain_exists?(new_resource.name) }
  end
end

def delete_securitydomain
  bash "remove_securitydomain #{new_resource.name}" do
    user node['wildfly']['user']
    cwd node['wildfly']['base']
    code <<-EOH
      bin/jboss-cli.sh -c command="/subsystem=security/security-domain=#{new_resource.name}:remove"
    EOH
    only_if { securitydomain_exists?(new_resource.name) }
  end
end
