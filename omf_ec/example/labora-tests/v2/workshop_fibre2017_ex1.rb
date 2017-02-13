HOST_TOPIC_NAME = 'vm-fibre-host'
HOST_IF_NAME = "eth1"

def configure_host(host)
  info "Configuring the interface name of host to #{HOST_IF_NAME}"
  host.configure(if_name: HOST_IF_NAME) do |msg|
    unless msg.success?
      error "Could not change the if_name property to: '#{msg[:if_name]}'"
      return
    end

    info "Host if_name property successfully changed to: '#{msg[:if_name]}'"
    info "Requesting host hostname and the #{msg[:if_name]} ip_address..."
    host.request([:ip_address, :hostname]) do |msg2|
      unless msg2.success?
        error "Could not get host hostname/#{msg[:if_name]} ip_address"
        return
      end

      info "hostname: #{msg2[:hostname]}"
      info "#{msg[:if_name]} ip_address: #{msg2[:ip_address]}"
      info "Configuring hostname and #{msg[:if_name]} ip_address"
      host.configure(ip_address: "10.137.0.1/16", hostname: "my_hostname") do |msg3|
        if msg3.success?
          info "hostname and #{msg[:if_name]} ip_address successfully configured"
        else
          error "Could not configure hostname and #{msg[:if_name]} ip_address"
        end
      end

    end
  end

end

OmfCommon.comm.subscribe(HOST_TOPIC_NAME) do |host|
  unless host.error?
    info "Successfully subscribed on '#{HOST_TOPIC_NAME}' topic"
    configure_host(host)
  end

  after(30) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end