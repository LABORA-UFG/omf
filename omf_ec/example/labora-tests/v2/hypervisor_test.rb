require 'omf_common'
require 'yaml'
$stdout.sync = true

OmfCommon.comm.subscribe('vm-testbed') do |hypervisor|
  if hypervisor.error?
    error app.inspect
  else

    hypervisor.create(:virtual_machine) do |reply_msg|
      puts reply_msg
      vm = reply_msg.resource

      vm.on_subscribed do
        info ">>> Connected to newly created VM #{reply_msg[:res_id]} with name #{reply_msg[:name]}"
        on_vm_created(vm)
      end
    end
  end
  #after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end

def on_vm_created(vm)
  vm.configure(vm_name: 'vm-openflow') do |msg|
    puts msg
  end

  vm.configure(
      vm_opts: {
          ram: 1024,
          cpu: 1,
          bridges: ['xenbr0', 'br1'],
          disk: {
              image: "vm-openflow-template.img"
          }
      },
      ssh_params: {
          ip_address: "192.168.1.2",
          port: 22,
          user: "root",
          key_file: "/root/.ssh/id_rsa"
      }, action: :build) do |msg|
    puts "PASSEI AQUI = #{msg}"
  end

  vm.on_message do |msg|
    puts "MESSAGE = #{msg}"
  end

  vm.on_inform do |msg|
    puts "INFORM = #{msg}"
  end

end

#OmfCommon.comm.subscribe('teste-30-vm') do |vm|
#  if vm.error?
#    error app.inspect
#  else
#    vm.configure(if_name: "eth0")
#    vm.request([:vm_ip, :vm_mac]) do |reply_msg|
#        info "> Slice requested name: #{reply_msg}"
#    end
#    vm.configure(hostname: "teste-30") do |reply_message|
#        info "HOSTNAME = #{reply_message}"
#    end
#    vm.configure(user: [{username: "vinicius", password: "123"}]) do |reply_message|
#        info "USER = #{reply_message}"
#    end
#  end

#  after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
#end
