
module OmfRc::ResourceProxy::VirtualMachine
  include OmfRc::ResourceProxyDSL

  register_proxy :virtual_machine
  utility :common_tools

  request :vm_ip do |res, interface|
    output = `ip -f inet -o addr show #{interface}|cut -d\\  -f 7 | cut -d/ -f 1`
    output
  end

  work :change_hostname do |res, hostname|
    `echo #{hostname} > /etc/hostname`
    #TODO change hostname at /etc/hosts
  end

  work :create_user do |res, user, password|
    `useradd #{user} -p $(openssl passwd -1 #{password}) -m -s /bin/bash`
  end

end
