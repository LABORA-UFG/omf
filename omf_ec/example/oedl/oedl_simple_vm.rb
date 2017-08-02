# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

SWITCH_TOPIC = 'vm-testbed'
VM_TEMPLATE = "vm-template.img"

defVmGroup('hyp-name', SWITCH_TOPIC) do |vmg|
  vmg.addVm('vm-8') do |vm1|
    # configure - build
    vm1.ram = 1024
    vm1.cpu = 1
    vm1.bridges = ['xenbr0', 'br1']
    vm1.image = VM_TEMPLATE
    # configure - host
    vm1.hostname = "labora-host"

    # USER
    # vm1.addUser("username", "password")
    # vm1.addUser("bruno", "54321")

    # VLAN
    # vm1.addVlan(vlan_id, "interface")
    # vm1.addVlan(195, "eth1")
  end
end

onEvent(:ALL_VM_GROUPS_UP) do |ev|
  info "OEDL - ALL_VM_GROUPS_UP"

  vm8 = vm_group('hyp-name').vm('vm-8')
  vm8.create do
    info "VM CREATED"
  end

  onEvent(:ALL_VMS_CREATED) do |ev_created|
    every(20) {
      vm8.ip do |vm1_ip|
        info "Ip da vm-8 = #{vm1_ip}"
      end
      vm8.mac do |vm1_mac|
        info "Mac da vm-8 = #{vm1_mac}"
      end
    }
    after(90) {
      info "Deleting #{vm8.name}"
      vm8.delete do
        info "VM Deleted"
      end
    }
  end
end



