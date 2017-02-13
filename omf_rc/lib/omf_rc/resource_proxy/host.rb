# Copyright (c) 2016 Computer Networks and Distributed Systems LABORAtory (LABORA).
# This proxy represents physical host machine.
#
module OmfRc::ResourceProxy::Host
  include OmfRc::ResourceProxyDSL

  register_proxy :host

  utility :common_tools
  utility :ip

  property :if_name, :default => "eth0"

  #
  # Gets the :if_name property
  #
  request :if_name do |host|
    info 'Request(if_name) called'
    host.property.if_name
  end

  #
  # Gets the :ip_address of :if_name interface
  #
  request :ip_address do |host|
    info 'Request(ip_address) called'
    host.__send__("request_ip_addr")
  end

  #
  # Gets the :hostname
  #
  request :hostname do |host|
    info 'Request(hostname) called'
    hostname = host.execute_cmd("cat /etc/hostname").delete("\n")
    hostname
  end

  #
  # Configures the :if_name property
  #
  configure :if_name do |host, value|
    info 'Configure(if_name) called'
    host.property.if_name = value
    value
  end

  #
  # Configures the :ip_address of :if_name interface
  #
  configure :ip_address do |host, ip_address|
    info 'Configure(ip_address) called'
    host.__send__("configure_ip_addr", ip_address)
    ip_address
  end

  #
  # Configures the :hostname
  #
  configure :hostname do |host, hostname|
    info 'Configure(hostname) called'
    host.execute_cmd("echo #{hostname} > /etc/hostname")
    hostname
  end
end
