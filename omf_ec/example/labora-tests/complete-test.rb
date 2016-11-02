#!/usr/bin/env ruby

require 'omf_common'
require 'yaml'
$stdout.sync = true

vms_up = false

OmfCommon.comm.subscribe('maq1-openflow') do |vm|
  if vm.error?
    error app.inspect
  else
    vm.configure(vm_name: "vm-openflow-test-1", state: :stopped, ready: true)
    vm.configure(vm_name: "vm-openflow-test-1", action: :run)
    vm.configure(vm_name: "vm-openflow-test-2", state: :stopped, ready: true)
    vm.configure(vm_name: "vm-openflow-test-2", action: :run)
    vm.configure(vm_name: "controller-pox", state: :stopped, ready: true)
    vm.configure(vm_name: "controller-pox", action: :run)

    after(20) {
       vms_up = true
    }
  end

  #after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end

defEvent(:VMS_UP) do 
   vms_up
end

defApplication('iperf') do |app|
  app.description = 'Simple Definition for the iperf-client application'

  app.binary_path = '/usr/bin/iperf'

  app.defProperty('client', 'Client', '-c', {:type => :string})
  app.defProperty('interval', 'Intervalo', '-i', {:type => :integer})
  app.defProperty('port', 'Porta', '-p', {:type => :integer})
  app.defProperty('time', 'Tempo', '-t', {:type => :integer})
end

defApplication('iperf-server') do |app|
  app.description = 'Simple Definition for the iperf-server application'

  app.binary_path = '/usr/bin/iperf'

  app.defProperty('server', 'Server', '-s', {:type => :string})
  app.defProperty('interval', 'Intervalo', '-i', {:type => :integer})
  app.defProperty('port', 'Porta', '-p', {:type => :integer})
end

#~/pox/pox.py forwarding.l2_learning openflow.of_01 --port=6633 --address=172.168.1.2 info.packet_dump samples.pretty_log log.level --DEBUG

defApplication('pox') do |app|
  app.description = 'Simple Definition for the pox controller application'

  app.binary_path = '/home/testbed/pox/pox.py'

  app.defProperty('controller-type', 'Switch Compoments', '', {:type => :string})
  app.defProperty('port', 'Porta', '', {:type => :string})
  app.defProperty('address', 'Address', '', {:type => :string})
  app.defProperty('log', 'Log Components', '', {:type => :string})
end

#sudo -u flowvisor /usr/local/sbin/flowvisor /etc/flowvisor/config.json 

defApplication('flowvisor') do |app|
  app.description = 'Simple Definition for the flowvisor application'

  app.binary_path = 'sudo -u flowvisor /usr/local/sbin/flowvisor /etc/flowvisor/config.json'

end

defGroup('OpenFlow Controller', 'controller-pox') do |g|

  g.addApplication("pox") do |app|
    
    app.setProperty('controller-type', 'forwarding.l2_learning openflow.of_01')
    app.setProperty('port', '--port=6633')
    app.setProperty('address', "--address=172.168.1.2")
    app.setProperty('log', 'info.packet_dump samples.pretty_log')

  end

end

defGroup('Flowvisor', 'maq3-switch') do |g|

  g.addApplication("flowvisor")
end

defGroup('Server', 'test-2') do |g|

  g.addApplication("iperf-server") do |app|
    
    app.setProperty('server', '')
    app.setProperty('interval', 1)
    app.setProperty('port', 2000)
  end
end

defGroup('Client', 'test-1') do |g|

  g.addApplication("iperf") do |app|
    
    app.setProperty('client', '172.169.1.2')
    app.setProperty('interval', 1)
    app.setProperty('port', 2000)
    app.setProperty('time', 300)

  end
end

onEvent(:VMS_UP) do |event|

  #list_of_resources = getResources()
  #puts "LIST OF RESOURCES: #{list_of_resources}"
  group('Flowvisor').startApplications
  group('OpenFlow Controller').startApplications

  after 10.seconds do
    group('Server').startApplications
  end

  after 12.seconds do
    group('Client').startApplications
  end

  after 80 do
    # Stop all the Applications associated to all the Groups
    allGroups.stopApplications
    # Tell the Experiment Controller to terminate the experiment now
    Experiment.done
  end
end

def create_slice(flowvisor)
  flowvisor.create(:openflow_slice, {name: "testbed"}) do |reply_msg|
    if reply_msg.success?
      slice = reply_msg.resource

      slice.on_subscribed do
        info ">>> Connected to newly created slice #{reply_msg[:res_id]} with name #{reply_msg[:name]}"
        on_slice_created(slice)
      end

      #after(10) do
      #  flowvisor.release(slice) do |reply_msg|
      #    info ">>> Released slice #{reply_msg[:res_id]}"
      #  end
      #end
    else
      error ">>> Slice creation failed - #{reply_msg[:reason]}"
    end
  end
end

def on_slice_created(slice)

  slice.request([:name]) do |reply_msg|
    info "> Slice requested name: #{reply_msg[:name]}"
  end

  slice.configure(flows: [{operation: 'add', device: '00:00:00:13:3b:0c:31:34', name: 'test'}]) do |reply_msg|
    info "> Slice configured flows:"
    reply_msg[:flows].each do |flow|
      logger.info "   #{flow}"
    end
  end

  slice.on_error do |msg|
    error msg[:reason]
  end
  slice.on_warn do |msg|
    warn msg[:reason]
  end
end

OmfCommon.comm.subscribe('maq3-switch-flowvisor') do |flowvisor|
  unless flowvisor.error?
    after 30 do
      create_slice(flowvisor)
    end
  else
    error flowvisor.inspect
  end

  #after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end

def create_switch(ovs)
  ovs.create(:virtual_openflow_switch, {name: "ovs-br"}) do |reply_msg|
    if reply_msg.success?
      switch = reply_msg.resource

      switch.on_subscribed do
        info ">>> Connected to newly created switch #{reply_msg[:res_id]} with name #{reply_msg[:name]}"
        on_switch_created(switch)
      end

      #after(10) do
      #  ovs.release(switch) do |reply_msg|
      #    info ">>> Released switch #{reply_msg[:res_id]}"
      #  end
      #end
    else
      error ">>> Switch creation failed - #{reply_msg[:reason]}"
    end
  end
end

def on_switch_created(switch)

  switch.configure(ports: {operation: 'add', name: 'eth1'}) do |reply_msg|
    info "> Switch configured ports: #{reply_msg[:ports]}"
  end

  switch.configure(ports: {operation: 'add', name: 'eth2'}) do |reply_msg|
    info "> Switch configured ports: #{reply_msg[:ports]}"
  end

end

OmfCommon.comm.subscribe('maq3-switch-ovs') do |ovs|
  unless ovs.error?
    create_switch(ovs)
  else
    error ovs.inspect
  end

  after(70) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end
