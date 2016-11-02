#!/usr/bin/env ruby

require 'omf_common'
require 'yaml'
$stdout.sync = true


OmfCommon.comm.subscribe('vinicius') do |vm|
  if vm.error?
    error app.inspect
  else

    vm.configure(vm_name: 'my_vm',
                 vm_opts: {
                     ram: 1024,
                     cpu: 1,
                     bridges: ['xenbr0', 'br1'],
                     disk: {
                         image: "vm-ubuntu-padrao.img"
                     }
                 },
                 ssh_params: {
                     ip_address: "192.168.1.2",
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