# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

SWITCH_TOPIC = 'vm-fibre-ovs'

defVmGroup('hyp1', SWITCH_TOPIC) do |vmg|
  vmg.addVm('vm1') do |vm1|
    # configure - build
    vm1.ram = 1024
    vm1.cpu = 1
    vm1.bridges = ['xenbr0', 'br1']
    vm1.image = "vm-ubuntu-padrao.img"

    # configure - host
    vm1.hostname = "labora-host"
    vm1.ifname = "eth0"

    # USER
    # vm1.addUser("username", "password")
    vm1.addUser("phelipe", "123456")
    vm1.addUser("bruno", "54321")

    # VLAN
    # vm1.addVlan(vlan_id, "interface")
    vm1.addVlan(193, "eth1")
    vm1.addVlan(195, "eth2")
  end
end

onEvent(:ALL_VM_GROUPS_UP) do |event|

  vm_group('hyp1').vm('vm1').create do
    # vm('vm1').run
  end

  onEvent(:ALL_VMS_CREATED) do |ev_created|
    vm_group('hyp1').vm('vm1').ip do |vm1_ip|
      info "Ip da vm1 = #{vm1_ip}"
    end
    vm_group('hyp1').vm('vm1').mac do |vm1_mac|
      info "Mac da vm1 = #{vm1_mac}"
    end

    after(70) {
      Experiment.done
    }

  end

end