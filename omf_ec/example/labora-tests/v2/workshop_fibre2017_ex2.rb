SWITCH_TOPIC = 'vm-fibre-ovs'
$experiment_running = true

def configure_ovs(switch)
  info "Adding openflow flows..."
  switch.configure(add_flows: ["in_port=1,action=output:2", "in_port=2,action=output:1"]) do | msg |
    if msg.success?
      info msg[:add_flows]
    else
      info "Could not add flows: #{msg[:add_flows]}"
    end
  end

  info "Waiting 30 seconds until flows removal..."
  after(30) {del_flows(switch, ["in_port=1", "in_port=2"])}

  Thread.new do
    while $experiment_running do
      info "Requesting openflow flows..."
      switch.request([:dump_flows]) do |msg|
        unless msg.success?
          error "Could not get openflow flows at this time"
        end

        msg[:dump_flows].each do |flow|
          info "- Openflow Flow: #{flow}"
        end
      end
      sleep(5)
    end
  end
end

def del_flows(switch, flows)
  info "Removing openflow flows..."
  switch.configure(del_flows: flows) do | msg |
    if msg.success?
      info msg[:del_flows]
    else
      info "Could not remove flows: #{msg[:del_flows]}"
    end
    $experiment_running = false
  end
end

OmfCommon.comm.subscribe(SWITCH_TOPIC) do |switch|
  unless switch.error?
    info "Successfully subscribed on '#{SWITCH_TOPIC}' topic"
    configure_ovs(switch)
  end

  after(35){ info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end
