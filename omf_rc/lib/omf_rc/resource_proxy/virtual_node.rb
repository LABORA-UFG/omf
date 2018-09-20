require "base64"

module OmfRc::ResourceProxy::VirtualNode
  include OmfRc::ResourceProxyDSL

  register_proxy :virtual_node

  utility :sysfs
  utility :common_tools
  utility :ip

  property :if_name, :default => "eth0"
  property :broker_topic_name, :default => "am_controller"
  property :status

  @broker_topic = nil
  @vm_topic = nil
  @started = false
  @configure_list_opts = []
  @vm_mac = nil

  hook :before_ready do |resource|
    if resource.uid.include? "fed"
      @vm_mac = resource.uid.split('-').last
    else
      @vm_mac = resource.uid
    end

    resource.inform(:BOOT_INITIALIZED, Hashie::Mash.new({:info => 'Virtual Machine successfully initialized.'}))

    debug "Subscribing to broker topic: #{resource.property.broker_topic_name}"
    OmfCommon.comm.subscribe(resource.property.broker_topic_name) do |topic|
      if topic.error?
        resource.inform_error("Could not subscribe to broker topic")
      else
        @broker_topic = topic
        debug "Creating broker virtual machine resource with mac_address: #{@vm_mac}"
        @broker_topic.create(:virtual_machine, {:mac_address => @vm_mac}) do |msg|
          if msg.error?
            resource.inform_error("Could not create broker virtual machine resource topic #{msg}")
          else
            @vm_topic = msg.resource
            info_msg = "Broker virtual machine resource created successfully! VM_TOPIC: #{@vm_topic}"
            resource.inform(:info, Hashie::Mash.new({:info => info_msg}))
            Thread.new {
              info_msg = 'Waiting 30 seconds to finalize VM setup with broker...'
              resource.inform(:info, Hashie::Mash.new({:info => info_msg}))
              info info_msg

              sleep(30)
              resource.finish_vm_setup_with_broker
              resource.configure_broker_vm
            }
          end
        end
      end
    end
  end

  hook :before_create do |node, type, opts|
    prefix = ""
    if opts[:federate]
      prefix = "fed-#{opts[:domain]}-"
    end

    if type.to_sym == :application
      opts[:uid] = "#{prefix}#{@vm_mac}-application-#{opts[:hrn]}"
    end

    if type.to_sym == :net
      net_dev = node.request_devices.find do |v|
        v[:name] == opts[:if_name]
        opts[:uid] = "#{prefix}#{@vm_mac}-net-#{opts[:if_name]}"
      end
      raise StandardError, "Device '#{opts[:if_name]}' not found" if net_dev.nil?
    end
  end

  request :interfaces do |node|
    node.children.find_all { |v| v.type == :net || v.type == :wlan }.map do |v|
      { name: v.property.if_name, type: v.type, uid: v.uid }
    end.sort { |x, y| x[:name] <=> y[:name] }
  end

  request :applications do |node|
    node.children.find_all { |v| v.type =~ /application/ }.map do |v|
      { name: v.hrn, type: v.type, uid: v.uid }
    end.sort { |x, y| x[:name] <=> y[:name] }
  end

  request :vm_ip do |resource|
    cmd = "/sbin/ifconfig #{resource.property.if_name} | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1"
    ip = resource.execute_cmd(cmd, "Getting the ip of #{resource.property.if_name}",
                    "It was not possible to get the IP!", "IP was successfully got!")
    resource.check_and_return_request(ip)
  end

  request :vm_mac do |resource|
    resource.check_and_return_request(@vm_mac)
  end

  request :status do |resource|
    resource.property.status
  end

  # Checks if resource is ready to receive configure commands
  configure_all do |resource, conf_props, conf_result|
    if @started && @vm_topic.nil?
      raise "This virtual machine '#{resource.property.label}' is not avaiable, so nothing can be configured"
    end

    if @started
      conf_props.each { |k, v| conf_result[k] = resource.__send__("configure_#{k}", v) }
    else
      configure_call = {
          :conf_props => conf_props,
          :conf_result => conf_result
      }
      debug "Resource not started yet, saving configure call: #{configure_call}..."
      @configure_list_opts << configure_call
    end
  end

  configure :hostname do |res, value|
    res.change_hostname(value)
  end

  configure :vlan do |res, opts|
    interface = opts[:interface]
    vlan_id = opts[:vlan_id]

    open('/etc/network/interfaces', 'a') { |f|
      f << "\n"
      f << "##{interface.upcase}.#{vlan_id.upcase}\n"
      f << "auto #{interface}.#{vlan_id}\n"
      f << "iface #{interface}.#{vlan_id} inet manual\n"
      f << "\tvlan-raw-device #{interface}\n"
    }

    cmd = "/sbin/ifup #{interface}.#{vlan_id}"

    res.execute_cmd(cmd, "Configuring vlan #{vlan_id} on #{interface}...",
                    "Cannot configure #{vlan_id} on #{interface}!",
                    "Vlan #{vlan_id} successfully configured on #{interface}!")
  end

  work :change_hostname do |res, new_hostname|
    new_hostname = new_hostname.gsub("_", "-")
    current_hostname = File.read('/etc/hostname').delete("\n")
    File.write('/etc/hostname', new_hostname)

    hosts_content = File.read('/etc/hosts')
    hosts_content = hosts_content.gsub(current_hostname, new_hostname)

    File.write('/etc/hosts', hosts_content)

    `hostname #{new_hostname}`
  end

  work :finish_vm_setup_with_broker do |resource|
    unless @vm_topic.nil?
      info_msg = 'Finishing setup with broker...'
      resource.inform(:info, Hashie::Mash.new({:info => info_msg}))

      cmd = "echo '' > /root/.ssh/authorized_keys"
      resource.execute_cmd(cmd, "Clearing ssh public keys...",
                           "Cannot clear ssh public keys", "SSH public keys cleaned")

      @vm_topic.request([:user_public_keys]) do |msg|
        vm_keys = msg[:user_public_keys]
        if not vm_keys.nil? and vm_keys.kind_of?(::Array)
            vm_keys.each do |key|
              key[:ssh_key] = Base64.decode64(key[:ssh_key]) if key[:is_base64]
              cmd = "echo '#{key[:ssh_key]}' >> /root/.ssh/authorized_keys"
              resource.execute_cmd(cmd, "Adding user public key '#{key[:ssh_key]}' to authorized_keys",
                              "Cannot add public key", "Public key succesfully added")
            end
        else
          resource.inform_error("User public keys in wrong format. They must be Array but is #{vm_keys.class}") unless vm_keys.nil?
          resource.inform_error("User public keys are nil.") if vm_keys.nil?
        end
      end
    end
  end

  work :configure_broker_vm do |resource|
    unless @vm_topic.nil?
      @started = true
      ip_address = resource.request_vm_ip
      resource.property.status = 'UP_AND_READY'

      info_msg = "Setting vm status on broker to '#{resource.property.status}' and ip address to '#{ip_address}'"
      resource.inform(:info, Hashie::Mash.new({:info => info_msg}))

      @vm_topic.configure(status: resource.property.status, ip_address: ip_address) do |msg|
        if msg.error?
          resource.inform_error("Could not finish vm setup with broker: #{msg}")
        else
          resource.inform(:BOOT_DONE, Hashie::Mash.new({:status => resource.property.status, ip_address: ip_address}))
          resource.call_prev_configs
        end
      end
    end
  end

  work :check_and_return_request do |resource, return_data|
    if @started
      return_data
    else
      resource.inform_error("This resource is not ready yet")
      ""
    end
  end

  # Call each configure called before started
  work :call_prev_configs do |resource|
    prev_configure_len = @configure_list_opts.size
    if prev_configure_len > 0
      info_msg = "Executing previous '#{prev_configure_len}' configures called..."
      resource.inform(:info, Hashie::Mash.new({:info => info_msg}))
      @configure_list_opts.each do |obj|
        debug "Calling previous called configure: #{obj}"
        resource.configure_all(obj[:conf_props], obj[:conf_result])
      end
      @configure_list_opts = []
    end
  end
end
