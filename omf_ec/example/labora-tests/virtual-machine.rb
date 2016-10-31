#!/usr/bin/env ruby

require 'omf_common'
require 'yaml'
$stdout.sync = true


OmfCommon.comm.subscribe('vm-openflow-template-vm') do |vm|
  if vm.error?
    error app.inspect
  else
    vm.configure(if_name: "eth0")
    vm.request([:vm_ip]) do |reply_msg|
        info "> Slice requested name: #{reply_msg[:name]}"
    end
    vm.configure(hostname: "teste")
  end

  after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end