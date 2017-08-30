# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

VM_GROUP = 'vm-testbed'
VM_TOPIC = 'vm-testbed'
VM_TEMPLATE = 'vm-template.img'
VM_NAME = 'bruno_lease:vm5'

defVmGroup(VM_GROUP, VM_TOPIC) do |vmg|
  vmg.addVm(VM_NAME) do |vm1|
    vm1.bridges = ['xenbr0', 'br1', 'br2']
    vm1.hostname = "labora-host"
    vm1.addVlan(101, "eth0")
    vm1.addVlan(103, "eth1")
  end
end

onEvent(:ALL_VM_GROUPS_UP) do |ev|

  vm = vm_group(VM_GROUP).vm(VM_NAME)
  vm.create do
    info "vm: #{vm.name} - created with success"
  end

  onEvent(:ALL_VMS_CREATED) do |ev_created|
    every(10) {
      vm.ip do |vm1_ip|
        info "vm: #{vm.name} - ip = #{vm1_ip}"
      end
      vm.mac do |vm1_mac|
        info "vm: #{vm.name} - mac = #{vm1_mac}"
      end
    }
    after(120) {
      Experiment.done
    }
  end
end



