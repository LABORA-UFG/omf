require 'omf_common'
require 'yaml'
#$stdout.sync = true

VM_TEMPLATE = "vm-template.img"

def createVM(vm_name, vm_template)
  OmfCommon.comm.subscribe('vm-testbed') do |hypervisor|
    hypervisor.create(:virtual_machine) do |vm_topic|
      vm = vm_topic.resource
      puts "VM = #{vm}"
      if vm.error?
        error app.inspect
      else

        vm.on_subscribed do
          info ">>> Connected to newly created slice #{vm_topic[:res_id]} with name #{vm_topic[:name]}"

          vm.configure(vm_name: vm_name) do |msg|
            puts "CONFIG NAME = #{msg}"
          end

          OmfCommon.eventloop.after 2 do
            vm.configure(
                vm_opts: {
                    ram: 1024,
                    cpu: 1,
                    bridges: ['xenbr0', 'br1'],
                    disk: {
                        image: vm_template
                    }
                }, action: :build)
          end

          vm.on_message do |msg|
            if (msg.itype == "STATUS" and msg.has_properties? and msg.properties[:vm_topic])
              after(48) { on_vm_created(msg.properties[:vm_topic]) }
            elsif (msg.itype == "STATUS" and msg.has_properties? and msg.properties[:progress])
              info "#{vm_name} progress: #{msg.properties[:progress]}"
            elsif (msg.itype == "ERROR" and msg.has_properties? and msg.properties[:reason])
              info "ERROR = #{msg.properties[:reason]}"
            end
          end
        end
      end
    end
  end
end


def on_vm_created(vm_topic)
  OmfCommon.comm.subscribe(vm_topic) do |vm|
    info "Configuring VM on topic: #{vm_topic}"
    if vm.error?
      error app.inspect
    else
      vm.request([:vm_ip, :vm_mac]) do |reply_msg|
        info "> IP and MAC: #{reply_msg}"
      end
      vm.configure(hostname: "vm-openflow") do |reply_message|
        info "HOSTNAME = #{reply_message}"
      end
      vm.configure(user: [{username: "vinicius", password: "123"}]) do |reply_message|
        info "USER = #{reply_message}"
      end
    end
    #after(60) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
  end
end


#createVM("vm-7", VM_TEMPLATE)

createVM("vm-8", VM_TEMPLATE)

#createVM("vm-3", VM_TEMPLATE)

#after(180) { createVM("vm-2", VM_TEMPLATE) }