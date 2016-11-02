module OmfRc::ResourceProxy::VirtualMachine
  include OmfRc::ResourceProxyDSL

  register_proxy :virtual_machine

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
    current_hostname = File.read('/etc/hostname')
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
    cmd = "/usr/sbin/useradd #{username} -p #{pwd} -m -s /bin/bash"

    res.execute_cmd(cmd, "Adding a new user...",
                    "Cannot add the user!", "User was successfully added!")
  end

  request :vm_mac do |res|
    require 'macaddr'
    Mac.address
  end

end
