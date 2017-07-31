require 'omf_common'
require 'yaml'
$stdout.sync = true

#OmfCommon.comm.subscribe('vm-testbed') do |vm|
#  if vm.error?
#    error app.inspect
#  else
#    vm.configure(vm_name: "vm-8", action: :delete)
#  end

#  after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
#end

def deleteVM(vm_name)
  OmfCommon.comm.subscribe('vm-testbed') do |hypervisor|
    puts "HYPERVISOR = #{hypervisor}"
    hypervisor.create(:virtual_machine) do |vm_topic|
      vm = vm_topic.resource
      puts "VM = #{vm}"
      if vm.error?
        error app.inspect
      else
        vm.on_subscribed do
          info ">>> Connected to newly created VM #{vm_topic[:res_id]} with name #{vm_topic[:name]}"

          vm.configure(vm_name: vm_name) do |msg|
            puts "CONFIG NAME = #{msg}"
          end

          OmfCommon.eventloop.after 2 do
            vm.configure(action: :stop)
          end

        end

        vm.on_message do |msg|
          if (msg.itype == "ERROR" or msg.itype == "WARN" and msg.has_properties? and msg.properties[:reason])
            info "ERROR = #{msg.properties[:reason]}"
          elsif (msg.itype == "STATUS" and msg.has_properties? and !(msg.properties[:vm_return].nil?) and msg.properties[:vm_return].include? "VM stopped successfully")
            info "DELETING: #{vm_name}"
            vm.configure(action: :delete)
          end
        end
      end
    end
  end
end

deleteVM("vm-8")