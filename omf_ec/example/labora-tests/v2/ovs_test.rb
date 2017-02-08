# OMF_VERSIONS = 6.0

def configure_ovs(switch)
  switch.request([:controller]) do |reply_msg|
    if reply_msg.success?
      info "OLD controller: #{reply_msg[:controller]}"
    end
  end

  switch.configure(controller: "tcp:10.129.0.101:6633") do | msg |
    if msg.success?
      info "Configuration done successfully"
    else
      info "Error in the configuration: #{msg.inspect}"
    end
  end

  switch.configure(add_flow: "in_port=1,action=output:2") do | msg |
    if msg.success?
      info msg[:add_flow]
    else
      info "Error in the configuration: #{msg}"
    end
  end

  switch.request([:controller]) do |reply_msg|
    if reply_msg.success?
      info "new controller: #{reply_msg[:controller]}"
    end
  end

  after(10) {del_flow(switch, "in_port=1")}
end

def del_flow(switch, flow)
  switch.configure(del_flow: flow) do | msg |
    if msg.success?
      info msg[:del_flow]
    else
      info "Error in the configuration: #{msg}"
    end
  end
end

OmfCommon.comm.subscribe('vm-fibre-ovs') do |switch|
  unless switch.error?
    configure_ovs(switch)
  else
    error switch.inspect
  end

  after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end
