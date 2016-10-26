#!/usr/bin/env ruby

require 'omf_common'
require 'yaml'
$stdout.sync = true

# Communication setup
OmfCommon.init(:development,
                communication: { url: 'amqp://guest:lab251@10.16.88.5' }) do

   OmfCommon.comm.on_connected do |comm|
      info "Engine test script >> Connected to AMQP"
	proxy_topic = "maq1-openflow"

	 comm.subscribe(proxy_topic) do |vm|
           if vm.error?
              error app.inspect
           else

	      # Define the messages to publish
	      #vm.configure(vm_name: 'my_vm', 
              #             ubuntu_opts: { bridge: 'br0' }, 
              #             vmbuilder_opts: {ip: '10.16.88.240', 
              #               net: '10.16.0.0',
              #               bcast: '10.16.255.255',
              #               mask: '255.255.0.0',
              #               gw: '10.16.0.1',
              #               dns: '8.8.8.8'},
              #               action: :build )

             #vm.configure(vm_name: 'my_vm', vm_original_clone: 'vm-ubuntu-padrao', action: :clone_from)


  	     OmfCommon.eventloop.after 2 do
	       #vm.configure(ready: true , action: :run)
               vm.configure(action: :delete)
    	     end

	  end
	end
  end
end


