# Copyright (c) 2016 Computer Networks and Distributed Systems LABORAtory (LABORA).
# This proxy represents physical/virtual switch openflow, and it is the proxy which standard RC start up script
# initialised.
#
# Switch proxy is more like a monitor/configurator proxy which monitors resource information on the switch itself,
# it is usually created during the bootstrap process and provides an entry point for incoming FRCP messages.
#
# @example Setting up controller on existing switch openflow using communicator
#   comm.subscribe('switch01') do |switch|
#     switch.configure(controller: 'tcp:127.0.0.1:6633')
#   end
#
module OmfRc::ResourceProxy::Switch
  include OmfRc::ResourceProxyDSL
  # @!macro extend_dsl

  register_proxy :switch

  utility :ovs

  property :stype, :default => "ovs"
  property :ip_address, :default => "127.0.0.1"
  property :port, :default => 22
  property :user, :default => "root"
  property :key_file, :default => "/root/.ssh/id_rsa"
  property :ovs_bin_dir, :default => "/usr/bin"
  property :bridge, :default => "ovs-br"

  hook :before_ready do |switch|
    available_switches = ["ovs"]
    raise StandardError, "Switch type '#{switch.property.stype}' not available" unless
        available_switches.include?(switch.property.stype)
  end

  # Repass configuration to utilities works
  %w(controller add_flows del_flows).each do |p|
    configure p do |switch, value|
      info "Configure :#{p} to switch of type #{switch.property.stype} received"
      switch.__send__("handle_#{p}_#{switch.property.stype}_configuration", value)
    end
  end

  # Repass requests to utilities works
  %w(controller dump_flows).each do |p|
    request p do |switch|
      info "Request :#{p} to switch of type #{switch.property.stype} received"
      switch.__send__("handle_#{p}_#{switch.property.stype}_request")
    end
  end
end
