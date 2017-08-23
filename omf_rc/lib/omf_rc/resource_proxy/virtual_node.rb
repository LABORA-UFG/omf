require "base64"

module OmfRc::ResourceProxy::VirtualNode
  include OmfRc::ResourceProxyDSL

  register_proxy :virtual_node

  utility :common_tools
  utility :ip

  property :if_name, :default => "eth0"
  property :broker_topic_name, :default => "am_controller"

  @broker_topic = nil
  @vm_topic = nil
  @started = false
  @configure_list_opts = []

  hook :before_ready do |resource|
    resource.inform(:BOOT_INITIALIZED, Hashie::Mash.new({:info => 'Virtual Machine successfully initialized.'}))

    debug "Subscribing to broker topic: #{resource.property.broker_topic_name}"
    OmfCommon.comm.subscribe(resource.property.broker_topic_name) do |topic|
      if topic.error?
        resource.inform_error("Could not subscribe to broker topic")
      else
        @broker_topic = topic
        debug "Creating broker virtual machine resource with mac_address: #{resource.uid}"
        @broker_topic.create(:virtual_machine, {:mac_address => resource.uid}) do |msg|
          if msg.error?
            resource.inform_error("Could not create broker virtual machine resource topic")
          else
            debug "Broker virtual machine resource created successfully!"
            @vm_topic = msg.resource
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

  request :vm_ip do |resource|
    cmd = "/sbin/ifconfig #{resource.property.if_name} | grep 'inet addr' | cut -d ':' -f 2 | cut -d ' ' -f 1"
    ip = resource.execute_cmd(cmd, "Getting the ip of #{resource.property.if_name}",
                    "It was not possible to get the IP!", "IP was successfully got!")
    resource.check_and_return_request(ip)
  end

  request :vm_mac do |resource|
    resource.check_and_return_request(resource.uid)
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
    current_hostname = File.read('/etc/hostname').delete("\n")
    File.write('/etc/hostname', new_hostname)

    hosts_content = File.read('/etc/hosts')
    hosts_content = hosts_content.gsub(current_hostname, new_hostname)

    File.write('/etc/hosts', hosts_content)
  end

  work :finish_vm_setup_with_broker do |resource|
    unless @vm_topic.nil?
      info 'Finishing setup with broker...'

      cmd = "echo '' > /root/.ssh/authorized_keys"
      resource.execute_cmd(cmd, "Clearing ssh public keys...",
                           "Cannot clear ssh public keys", "SSH public keys cleaned")

      @vm_topic.request([:user_public_keys]) do |msg|
        vm_keys = msg[:user_public_keys]
        vm_keys.each do |key|
          key[:ssh_key] = Base64.decode64(key[:ssh_key]) if key[:is_base64]
          cmd = "echo '#{key[:ssh_key]}' >> /root/.ssh/authorized_keys"
          resource.execute_cmd(cmd, "Adding user public key '#{key[:ssh_key]}' to authorized_keys",
                          "Cannot add public key", "Public key succesfully added")
        end
      end
    end
  end

  work :configure_broker_vm do |resource|
    unless @vm_topic.nil?
      @started = true
      ip_address = resource.request_vm_ip
      status = 'UP_AND_READY'

      info "Setting vm status on broker to '#{status}' and ip address to '#{ip_address}'"
      @vm_topic.configure(status: status, ip_address: ip_address) do |msg|
        if msg.error?
          resource.inform_error("Could not finish vm setup with broker: #{msg}")
        else
          resource.inform(:BOOT_DONE, Hashie::Mash.new({:status => status, ip_address: ip_address}))
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
