# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
# Encoding: utf-8
# Cookbook Name:: cpe_munki
# Resource:: cpe_munki
#
# Copyright (c) 2016-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree. An additional grant
# of patent rights can be found in the PATENTS file in the same directory.
#

require 'plist'
require 'json'

resource_name :cpe_munki_local
default_action :run

action :run do
  locals_exist = node['cpe_munki']['local']['managed_installs'].any? ||
                node['cpe_munki']['local']['managed_uninstalls'].any?

  return unless locals_exist

  # If local only manifest preference is not set,
  # set it to the default 'extra_packages'
  unless node['cpe_munki']['preferences'].key?('LocalOnlyManifest')
    node.default['cpe_munki']['preferences']['LocalOnlyManifest'] =
      'extra_packages'
  end

  @catalog_items = parse_items_in_catalogs

  local_manifest = node['cpe_munki']['preferences']['LocalOnlyManifest']
  file "/Library/Managed Installs/manifests/#{local_manifest}" do
    content gen_plist
  end

  # This file is for context for users to know whats avalible for their machine
  pretty_json = JSON.pretty_generate(@catalog_items)
  file '/opt/facebook/munki_catalog_items.json' do
    content pretty_json.to_s
  end
end

def vaildate_install_array(install_array)
  return install_array if @catalog_items.nil?
  ret = []
  install_array.uniq.each do |item|
    ret << item if @catalog_items.include?(item)
  end
  ret
end

def gen_plist
  installs = vaildate_install_array(
    node['cpe_munki']['local']['managed_installs'],
  )
  uninstalls = vaildate_install_array(
    node['cpe_munki']['local']['managed_uninstalls'],
  )
  plist_hash = {
    'managed_installs' => installs,
    'managed_uninstalls' => uninstalls,
  }
  Plist::Emit.dump(plist_hash) unless plist_hash.nil?
end

def read_plist(xml_file)
  Plist.parse_xml(xml_file)
end

def parse_items_in_catalogs
  catalogs = []
  catlogs_dir = '/Library/Managed Installs/catalogs/'
  Dir.foreach(catlogs_dir) do |catalog|
    next if catalog == '.' || catalog == '..'
    begin
      p = read_plist(catlogs_dir + catalog)
      p.each do |d|
        catalogs << d['name']
      end
    rescue
      next
    end
  end
  catalogs.uniq
end
