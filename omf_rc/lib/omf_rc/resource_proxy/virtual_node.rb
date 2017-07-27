module OmfRc::ResourceProxy::VirtualNode
  include OmfRc::ResourceProxyDSL

  register_proxy :virtual_node

  utility :common_tools
  utility :ip

  property :if_name, :default => "eth0"

  configure :if_name do |res, value|
    res.property.if_name = value
  end

  request :vm_ip do |res|
    cmd = "/sbin/ip -f inet -o addr show #{res.property.if_name} | cut -d\\  -f 7 | cut -d/ -f 1"

    res.execute_cmd(cmd, "Getting the ip of #{res.property.if_name}",
                    "It was not possible to get the IP!", "IP was successfully got!")

  end

  configure :hostname do |res, value|
    res.change_hostname(value)
  end

  work :change_hostname do |res, new_hostname|
    current_hostname = File.read('/etc/hostname').delete("\n")
    File.write('/etc/hostname', new_hostname)

    hosts_content = File.read('/etc/hosts')
    hosts_content = hosts_content.gsub(current_hostname, new_hostname)

    File.write('/etc/hosts', hosts_content)
  end

  configure :user do |res, opts|
    user_data = opts[0]
    username = user_data[:username]
    password = user_data[:password]
    res.create_user(username, password)
  end

  work :create_user do |res, username, password|
    pwd = password.crypt("Xn1d9a1")
    cmd = "/usr/sbin/useradd #{username} -p #{pwd} -m -s /bin/bash && adduser #{username} sudo"

    res.execute_cmd(cmd, "Adding a new user...",
                    "Cannot add the user!", "User was successfully added!")

    cmd = "/usr/sbin/deluser testbed && rm -rf /home/testbed"

    res.execute_cmd(cmd, "Removing default user...",
                    "Cannot remove the user!", "User was successfully removed!")
  end

  request :vm_mac do |res|
    require 'macaddr'
    Mac.address
  end

  configure :vlan do |res, opts|
    data = opts[0]
    interface = data[:interface]
    vlan_id = data[:vlan_id]

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

end
