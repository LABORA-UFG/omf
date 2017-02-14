# Copyright (c) 2016 Computer Networks and Distributed Systems LABORAtory (LABORA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'hashie'
require 'cocaine'

# Utility for executing 'ovs' commands
module OmfRc::Util::Ovs
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
  # @example return value
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
  # Gets ovs flows
  #
  # @return [Array] containing all dumped ovs flows
  #
  # @!method handle_dump_flows_ovs_request
  # @!macro work
  work :handle_dump_flows_ovs_request do |res|
    ovs_out = res.ssh_command(res.property.user, res.property.ip_address, res.property.port, res.property.key_file,
                              "#{res.property.ovs_bin_dir}/ovs-ofctl dump-flows #{res.property.bridge}")
    flows = ovs_out.chomp.split("\n")
    flows.delete_at(0)
    flows
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
  # @return [String] configure status
  #
  # @!method handle_add_flows_ovs_configuration(value)
  # @!macro work
  work :handle_add_flows_ovs_configuration do |res, flows|
    flows_count = 1
    flows_added = 0
    if flows.kind_of?(::Array)
      flows_count = flows.length
      flows.each do |flow|
        if res.add_flow_ovs(flow)
          flows_added += 1
        end
      end
    else
      if res.add_flow_ovs(flows)
        flows_added = 1
      end
    end

    message = if flows_added == flows_count then "Flows successfully added" else "#{flows_added} of #{flows_count} " +
        'added' end
    message
  end

  #
  # Perform addition of a single flow into OVS
  #
  work :add_flow_ovs do |res, flow|
    ovs_out = res.ssh_command(res.property.user, res.property.ip_address, res.property.port, res.property.key_file,
                              "#{res.property.ovs_bin_dir}/ovs-ofctl add-flow #{res.property.bridge} #{flow}")
    added = if ovs_out.empty? then true else false end
    added
  end

  #
  # Delete a flow on ovs
  #
  # @return [String] configure status
  #
  # @!method handle_del_flows_ovs_configuration(value)
  # @!macro work
  work :handle_del_flows_ovs_configuration do |res, flows|
    flows_count = 1
    flows_removed = 0
    if flows.kind_of?(::Array)
      flows_count = flows.length
      flows.each do |flow|
        if res.del_flow_ovs(flow)
          flows_removed += 1
        end
      end
    else
      if res.del_flow_ovs(flows)
        flows_removed = 1
      end
    end

    message = if flows_removed == flows_count then "Flows successfully removed" else "#{flows_removed} of " +
        "#{flows_count} removed" end
    message
  end

  #
  # Perform removal of a single flow from OVS
  #
  work :del_flow_ovs do |res, flow|
    ovs_out = res.ssh_command(res.property.user, res.property.ip_address, res.property.port, res.property.key_file,
                              "#{res.property.ovs_bin_dir}/ovs-ofctl del-flows #{res.property.bridge} #{flow}")
    removed = if ovs_out.empty? then true else false end
    removed
  end

  # @!endgroup
end
