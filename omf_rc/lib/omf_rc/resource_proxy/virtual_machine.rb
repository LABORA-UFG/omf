
module OmfRc::ResourceProxy::VirtualMachine
  include OmfRc::ResourceProxyDSL

  register_proxy :virtual_machine
  utility :common_tools

  request :vm_ip do |res, interface|
    output = `ip -f inet -o addr show #{interface}|cut -d\\  -f 7 | cut -d/ -f 1`
    output
  end

  work :change_hostname do |res, new_hostname|
    current_hostname = File.read('/etc/hostname')
    File.write('/etc/hostname', new_hostname)

    hosts_content = File.read('/etc/hosts')
    hosts_content = hosts_content.gsub(current_hostname, new_hostname)

    File.write('/etc/hosts', hosts_content)
  end

  work :create_user do |res, user, password|
    pwd = password.crypt("$5$a1")
    `useradd #{user} -p #{pwd} -m -s /bin/bash`
  end

end
