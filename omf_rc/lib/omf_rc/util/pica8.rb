# Copyright (c) 2016 Computer Networks and Distributed Systems LABORAtory (LABORA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'hashie'
require 'cocaine'

# Utility for executing 'pica8' commands
module OmfRc::Util::Pica8
  include OmfRc::ResourceProxyDSL

  include Cocaine
  include Hashie

  # @!macro extend_dsl
  #
  # @!parse include OmfRc::Util::Ssh
  utility :ssh

  # @!macro group_work
  #
  # Gets pica8 controller
  #
  # @example return value
  #
  #   tcp:127.0.0.1:3000
  #
  # @return [String]
  #
  # @!method handle_controller_pica8_request
  # @!macro work
  work :handle_controller_pica8_request do |res|
    ovs_out = res.ssh_command(res.property.user, res.property.ip_address, res.property.port, res.property.key_file,
                              "/ovs/bin/ovs-vsctl get-controller br0")
    ovs_out = ovs_out.delete("\n")
    ovs_out
  end

  #
  # Configure pica8 controller
  #
  # @return [String] pica8 controller
  #
  # @!method handle_controller_pica8_configuration(value)
  # @!macro work
  work :handle_controller_pica8_configuration do |res, value|
    ovs_out = res.ssh_command(res.property.user, res.property.ip_address, res.property.port, res.property.key_file,
                              "/ovs/bin/ovs-vsctl set-controller br0 #{value}")
    value
  end
  # @!endgroup
end
