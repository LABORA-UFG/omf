# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

SWITCH_TOPIC = 'vm-testbed'
VM_TEMPLATE = "vm-template.img"


defVmGroup('hyp1', SWITCH_TOPIC) do |vmg|
  vmg.addVm('vm-8') do |vm1|
    # configure - build
    vm1.ram = 1024
    vm1.cpu = 1
    vm1.bridges = ['xenbr0', 'br1']
    vm1.image = VM_TEMPLATE

    # missing_methods
    # configure - host
    vm1.hostname = "labora-host"
    # vm1.ifname = "eth0"

    # USER
    # vm1.addUser("username", "password")
    vm1.addUser("vinicius", "123456")
    vm1.addUser("phelipe", "123456")
    # vm1.addUser("bruno", "54321")

    # vm1.cat = 'miau'
    # vm1.dog = %w(auau auuuuu)
    # VLAN
    # vm1.addVlan(vlan_id, "interface")
    # vm1.addVlan(193, "eth1")
    # vm1.addVlan(195, "eth2")
  end
end

onEvent(:ALL_VM_GROUPS_UP) do |event|
  info "OEDL - ALL_VM_GROUPS_UP"

  vm8 = vm_group('hyp1').vm('vm-8')
  vm8.create do
    info "VM CREATED"
    # wait(2)
    # vm8.stop do
    #   info "VM STOPED"
    #   wait(10)
    #   vm8.run do
    #     info "VM RUNNING"
    #     wait(10)
    #   end
    # end
  end

  onEvent(:ALL_VMS_CREATED) do |ev_created|
    info "ALL VMS CREATED"
    every(20) {
      info "VM IP"
      vm8.ip do |vm1_ip|
        info "Ip da vm-8 = #{vm1_ip}"
      end
      info "VM MAC"
      vm8.mac do |vm1_mac|
        info "Mac da vm-8 = #{vm1_mac}"
      end

      # --- test of error ---
      # vm8.test do |vm1_test|
      #   info "VM test #{vm1_test}"
      # end
      # vm8.ifname = 'eth0'
    }
    # after(10) {
    #   vm_group('hyp1').vm('vm-8').ip do |vm1_ip|
    #     info "Ip da vm-8 = #{vm1_ip}"
    #   end
    #   vm_group('hyp1').vm('vm1').mac do |vm1_mac|
    #     info "Mac da vm-8 = #{vm1_mac}"
    #   end
    # }

    # after(70) {
    #   Experiment.done
    # }

  end
end



