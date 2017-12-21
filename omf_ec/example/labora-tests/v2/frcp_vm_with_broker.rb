require 'omf_common'
require 'yaml'
#$stdout.sync = true

VM_TEMPLATE = "vm-template.img"

def createVM(vm_name, vm_template)
  OmfCommon.comm.subscribe('vm-testbed') do |hypervisor|
    puts "HYPERVISOR = #{hypervisor}"
    hypervisor.create(:virtual_machine, {:label => "bruno_lease:vm5"}) do |vm_topic|
      vm = vm_topic.resource
      puts "VM = #{vm}"
      if vm.error?
        error app.inspect
      else

        vm.on_subscribed do
          info ">>> Connected to newly created slice #{vm_topic[:res_id]} with name #{vm_topic[:name]}"

          OmfCommon.eventloop.after 2 do
            vm.configure(
                vm_opts: {
                    bridges: ['xenbr0', 'br1'],
                }, action: :build)
          end

          vm.on_message do |msg|
            info msg
            if msg.itype == 'VM.STATE' and msg.has_properties? and msg.properties[:vm_topic]
              info "VM Successfully created, waiting until boot finish"
              OmfCommon.comm.subscribe(msg.properties[:vm_topic]) do |vm_instance|
                if vm_instance.error?
                  error "Could not subscribe to vm instance topic"
                else
                  vm_instance.on_message do |vm_instance_msg|
                    info "VM INSTANCE MSG: #{vm_instance_msg}"
                  end
                end
              end
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
      puts [{username: "vinicius", password: "123"}]
      vm.configure(user: [{username: "vinicius", password: "123"}]) do |reply_message|
        puts [{username: "vinicius", password: "123"}]
        info "USER = #{reply_message}"
      end
      puts [{username: "phelipe", password: "123"}]
      vm.configure(user: [{username: "phelipe", password: "123"}]) do |reply_message|
        puts [{username: "phelipe", password: "123"}]
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