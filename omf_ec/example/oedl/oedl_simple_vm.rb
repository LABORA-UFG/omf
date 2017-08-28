# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

VM_TOPIC = 'vm-testbed'
VM_TEMPLATE = 'vm-template.img'
VM_NAME = 'bruno_lease:vm4'

defVmGroup('vm-testbed', VM_TOPIC) do |vmg|
  vmg.addVm(VM_NAME) do |vm1|
    # configure - build
    vm1.bridges = ['xenbr0', 'br1']
    # configure - host
    vm1.hostname = "labora-host"
    # configure - vlan
    # vm1.addVlan(vlan_id, "interface")
    # vm1.addVlan(195, "eth1")
  end
end

onEvent(:ALL_VM_GROUPS_UP) do |ev|
  info "OEDL - ALL_VM_GROUPS_UP"

  vm = vm_group('vm-testbed').vm(VM_NAME)
  info vm.name
  vm.create do
    info "VM CREATED"
  end

  onEvent(:ALL_VMS_CREATED) do |ev_created|
    every(10) {
      vm.ip do |vm1_ip|
        info "Ip da vm-8 = #{vm1_ip}"
      end
      vm.mac do |vm1_mac|
        info "Mac da vm-8 = #{vm1_mac}"
      end
    }
    after(90) {
      info "Deleting #{vm.name}"
      vm.delete do
        info "VM Deleted"
        after(10) {
          Experiment.done
        }
      end
    }
  end
end



