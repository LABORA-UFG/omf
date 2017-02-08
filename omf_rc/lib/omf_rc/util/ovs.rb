# Copyright (c) 2016 Computer Networks and Distributed Systems LABORAtory (LABORA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'hashie'
require 'cocaine'

# Utility for executing 'ovs' commands
module OmfRc::Util::OVS
  include OmfRc::ResourceProxyDSL

  include Cocaine
  include Hashie

  # @!macro extend_dsl
  #
  # @!parse include OmfRc::Util::Ssh
  utility :ssh

  # @!macro group_work
  #
  # Gets ovs controller
  #
  # @example return value
  #
  #   tcp:127.0.0.1:3000
  #
  # @return [String]
  #
  # @!method handle_controller_ovs_request
  # @!macro work
  work :handle_controller_ovs_request do |res|
    ovs_out = res.ssh_command(res.property.user, res.property.ip_address, res.property.port, res.property.key_file,
                              "#{res.property.ovs_bin_dir}/ovs-vsctl get-controller #{res.property.bridge}")
    ovs_out = ovs_out.delete("\n")
    ovs_out
  end

  #
  # Configure ovs controller
  #
  # @return [String] ovs controller
  #
  # @!method handle_controller_ovs_configuration(value)
  # @!macro work
  work :handle_controller_ovs_configuration do |res, value|
    ovs_out = res.ssh_command(res.property.user, res.property.ip_address, res.property.port, res.property.key_file,
                              "#{res.property.ovs_bin_dir}/ovs-vsctl set-controller #{res.property.bridge} #{value}")
    value
  end

  #
  # Add a flow to ovs
  #
  # @return [String] ovs controller
  #
  # @!method handle_add_flow_ovs_configuration(value)
  # @!macro work
  work :handle_add_flow_ovs_configuration do |res, flow|
    ovs_out = res.ssh_command(res.property.user, res.property.ip_address, res.property.port, res.property.key_file,
                              "#{res.property.ovs_bin_dir}/ovs-ofctl add-flow #{res.property.bridge} #{flow}")
    message = if ovs_out.nil? then "Flow added with success" else ovs_out end
    message
  end

  #
  # Delete a flow on ovs
  #
  # @return [Boolean] true
  #
  # @!method handle_add_flow_ovs_configuration(value)
  # @!macro work
  work :handle_del_flow_ovs_configuration do |res, flow|
    ovs_out = res.ssh_command(res.property.user, res.property.ip_address, res.property.port, res.property.key_file,
                              "#{res.property.ovs_bin_dir}/ovs-ofctl del-flows #{res.property.bridge} #{flow}")
    message = if ovs_out.nil? then "Flow removed with success" else ovs_out end
    message
  end


  # @!endgroup
end
