#!/usr/bin/env ruby

require 'omf_common'
require 'yaml'
$stdout.sync = true


OmfCommon.comm.subscribe('maq1-openflow') do |vm|
  if vm.error?
    error app.inspect
  else
    vm.configure(vm_name: "vm-openflow-test-1", action: :attach)
  end

  after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end


#OmfCommon.init(:development,
#                communication: { url: 'amqp://guest:lab251@10.16.88.5' }) do

#   OmfCommon.comm.on_connected do |comm|
#      info "Engine test script >> Connected to AMQP"
#	proxy_topic = "maq1-openflow"
#
#	 comm.subscribe(proxy_topic) do |vm|
#           if vm.error?
#              error app.inspect
#           else
#           
#	   vm.configure(vm_name: "vm-openflow-test-1", action: :attach)
#	  end
#	end
#  end
#end


