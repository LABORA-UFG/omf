#!/usr/bin/env ruby

require 'omf_common'
require 'yaml'
$stdout.sync = true


OmfCommon.comm.subscribe('maq1-openflow') do |vm|
  if vm.error?
    error app.inspect
  else
    # vm.configure(vm_name: 'my_vm',
    #   ubuntu_opts: { bridge: 'br0' },
    #   vmbuilder_opts: {ip: '10.16.88.240',
    #   net: '10.16.0.0',
    #   bcast: '10.16.255.255',
    #   mask: '255.255.0.0',
    #   gw: '10.16.0.1',
    #   dns: '8.8.8.8'},
    #   action: :build )

    vm.configure(vm_name: 'my_vm',
      vm_opts: {
          mem: 1024,
          cpu: 1,
          bridges: ['xenbr0', 'br1'],
          disk: {
              image: "omf-ec.img"
          }
      },
      ssh_params: {
          ip_address: "10.16.88.2",
          port: 22,
          user: "root",
          key_file: "/root/.ssh/id_rsa"
      },
      action: :build )

      # OmfCommon.eventloop.after 2 do
      #   vm.configure(ready: true , action: :run)
      # end
  end

  after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end

#OmfCommon.init(:development,
#                communication: { url: 'amqp://guest:lab251@10.16.88.5' }) do

#   OmfCommon.comm.on_connected do |comm|
#      info "Engine test script >> Connected to AMQP"
#	proxy_topic = "maq1-openflow"

#	 comm.subscribe(proxy_topic) do |vm|
#           if vm.error?
#              error app.inspect
#           else

#	      vm.configure(vm_name: 'my_vm', 
#                           ubuntu_opts: { bridge: 'br0' }, 
#                           vmbuilder_opts: {ip: '10.16.88.240', 
#                             net: '10.16.0.0',
#                             bcast: '10.16.255.255',
#                             mask: '255.255.0.0',
#                             gw: '10.16.0.1',
#                             dns: '8.8.8.8'},
#                             action: :build )

#  	     OmfCommon.eventloop.after 2 do
#	       vm.configure(ready: true , action: :run)
#    	     end

#	  end
#	end
#  end
#end


