VM_TOPIC = 'urn:publicid:IDN+ufrj.br+node+xen'
VM_GROUP = 'urn:publicid:IDN+ufrj.br+node+xen_group'
VM1_NAME = 'urn:publicid:IDN+ch.fibre.org.br:f4813cf7+slice+736e165f:vm1'
VM2_NAME = 'urn:publicid:IDN+ch.fibre.org.br:f4813cf7+slice+736e165f:vm2'

defVmGroup(VM_GROUP, VM_TOPIC) do |vmg|
  vmg.addVm(VM1_NAME) do |vm|
    #vm.bridges = ['omf6-br-test', 'br_control', 'br_internet']
    vm.bridges = ['br_control', 'br_internet']
    vm.hostname = 'minha_vm'
    vm.addVlan(101,'eth1')
    vm.addVlan(200,'eth1')
  end
  vmg.addVm(VM2_NAME) do |vm|
    #vm.bridges = ['omf6-br-test', 'br_control', 'br_internet']
    vm.bridges = ['br_control', 'br_internet']
    vm.hostname = 'minha_vm'
    vm.addVlan(101,'eth1')
    vm.addVlan(200,'eth1')
  end
end

# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

FLOWVISOR_TOPIC = 'vm-fibre-ovs'

defFlowVisor('fv1', FLOWVISOR_TOPIC ) do |flowvisor|
  flowvisor.addSlice('slice1') do |slice1|
    slice1.controller = 'tcp:127.0.0.1:6633'
    slice1.addFlow('pronto-porta-1') do |flow1|
      flow1.operation = 'add'
      flow1.device = '67:8c:08:9e:01:62:d6:63'
      flow1.match = 'in_port=1,dl_vlan=193'
    end
    slice1.addFlow('netfpga-porta-2') do |flow2|
      flow2.operation = 'add'
      flow2.device = '00:00:00:00:00:00:81:02'
      flow2.match = 'in_port=2,dl_vlan=193'
    end
    slice1.addFlow('pronto-porta-2') do |flow3|
      flow3.operation = 'add'
      flow3.device = '67:8c:08:9e:01:62:d6:63'
      flow3.match = 'in_port=2,dl_vlan=193'
    end
  end
end

def create_flowvisor_slices()
  info "Successfully subscribed on '#{FLOWVISOR_TOPIC}' topic"

  # flowvisor('fv1').createAllSlices

  flowvisor('fv1').create('slice1') do
    slice1 = flowvisor('fv1').slice('slice1')
    info "Slice #{slice1.name} created"
  end

  onEvent(:ALL_SLICES_CREATED) do |ev_created|
    info 'All slices created'

    flowvisor('fv1').slice('slice1').addFlow('netfpga-porta-1') do |flow4|
      flow4.operation = 'add'
      flow4.device = '00:00:00:00:00:00:81:02'
      flow4.match = 'in_port=1,dl_vlan=193'
    end

    flowvisor('fv1').slice('slice1').addFlow('netfpga-porta-2') do |flow4|
      flow4.operation = 'add'
      flow4.device = '00:00:00:00:00:00:81:02'
      flow4.match = 'in_port=1,dl_vlan=193'
    end

    flowvisor('fv1').slice('slice1').create('netfpga-porta-1') do |flow4|
      info "Slice 1 with flow 4 created"
    end

    after(30) {
      info "Removing openflow flows..."
      flowvisor('fv1').release('slice1')
      flowvisor('fv1').releaseAllSlices
    }

    after(35) {
      Experiment.done
    }

  end
end

onEvent([:ALL_VM_GROUPS_UP, :ALL_FLOWVISOR_UP]) do |ev|
  info 'OEDL - ALL_VM_GROUPS_UP'
  vm1 = vm_group(VM_GROUP).vm(VM1_NAME)
  vm2 = vm_group(VM_GROUP).vm(VM2_NAME)
  vm1.create do
    info 'vm_1 created'
  end
  vm2.create do
    info 'vm_2 created'
  end
  onEvent(:ALL_VMS_CREATED) do |ev_created|
    ip_vm1 = nil
    ip_vm2 = nil

    #TODO change the ALL_VMS_CREATED to fire when all VMs are up and configured
    while true
      vm1.ip do |ip|
        ip_vm1 = ip
      end
      vm2.ip do |ip|
        ip_vm2 = ip
      end
      unless ip_vm1 and ip_vm2
        create_flowvisor_slices()
      end
    end
    after(360000) {
      Experiment.done
    }
  end
end