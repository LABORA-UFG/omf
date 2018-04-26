VM_TOPIC_UFG = 'fed-fibre-ufg-br-urn:publicid:IDN+fibre.ufg.br+node+xen'
VM_GROUP_UFG = 'urn:publicid:IDN+fibre.ufg.br+node+xen_group'
VM1_NAME_UFG = 'urn:publicid:IDN+ch.fibre.org.br:f4813cf7+slice+736e165f:vm1'

VM_TOPIC_UFRJ = 'fed-ufrj-br-urn:publicid:IDN+ufrj.br+node+xen'
VM_GROUP_UFRJ = 'urn:publicid:IDN+ufrj.br+node+xen_group'
VM1_NAME_UFRJ = 'urn:publicid:IDN+ch.fibre.org.br:f4813cf7+slice+736e165f:vm3'

defVmGroup(VM_GROUP_UFG, VM_TOPIC_UFG) do |vmg|
  vmg.addVm(VM1_NAME_UFG) do |vm|
    vm.bridges = ['br_control', 'br_exp2', 'br_internet']
    vm.hostname = 'vm-ufg'
    vm.addVlan(101,'eth1')
  end
end

defVmGroup(VM_GROUP_UFRJ, VM_TOPIC_UFRJ) do |vmg|
  vmg.addVm(VM1_NAME_UFRJ) do |vm|
    vm.bridges = ['br_control', 'br_exp3', 'br_internet']
    vm.hostname = 'vm-ufrj'
    vm.addVlan(101,'eth1')
  end
end

onEvent(:ALL_VM_GROUPS_UP) do |ev|
  info 'OEDL - ALL_VM_GROUPS_UP'
  vm_ufg = vm_group(VM_GROUP_UFG).vm(VM1_NAME_UFG)
  vm_ufg.create do
    info 'vm_ufg created'
  end
  vm_ufrj = vm_group(VM_GROUP_UFRJ).vm(VM1_NAME_UFRJ)
  vm_ufrj.create do
    info 'vm_ufrj created'
  end
  onEvent(:ALL_VMS_CREATED) do |ev_created|
    vm_ufg_ip = ""
    vm_ufrj_ip = ""
    while vm_ufg_ip.empty? or vm_ufrj_ip.empty?
      vm_ufg.ip do |ip|
        vm_ufg_ip = ip
      end
      vm_ufrj.ip do |ip|
        vm_ufrj_ip = ip
      end
      puts "vm_ufrj_ip = #{vm_ufrj_ip}, vm_ufg_ip = #{vm_ufg_ip}"
      sleep(20)
    end
    puts "CONFIGURING FLOWVISOR SLICES"
    define_flowvisor_slices(vm_ufg_ip)
    create_flowvisor_slices()
  end
end

def define_flowvisor_slices(controller_ip)
  flowvisor_topic_noc = 'fed-noc-fibre-org-br-flowvisor3-fw'
  flowvisor_topic_ufrj = 'fed-ufrj-br-flowvisor-fw'
  flowvisor_topic_ufg = 'fed-fibre-ufg-br-flowvisor-fw'

  puts "CONTROLLER_IP: #{controller_ip}"

  defFlowVisor('fv_noc', flowvisor_topic_noc) do |flowvisor|
    flowvisor.addSlice('slice1') do |slice1|
      slice1.controller = "tcp:#{controller_ip}:6633"
      slice1.addFlow('noc1-ufg') do |flow1|
        flow1.operation = 'add'
        flow1.device = '00:00:00:04:df:61:5e:4d'
        flow1.match = 'in_port=28,dl_vlan=101'
      end
      slice1.addFlow('noc1-noc3') do |flow1|
        flow1.operation = 'add'
        flow1.device = '00:00:00:04:df:61:5e:4d'
        flow1.match = 'in_port=44,dl_vlan=101'
      end
      slice1.addFlow('noc3-noc1') do |flow1|
        flow1.operation = 'add'
        flow1.device = '00:00:00:04:df:61:5d:3a'
        flow1.match = 'in_port=40,dl_vlan=101'
      end
      slice1.addFlow('noc3-noc2') do |flow1|
        flow1.operation = 'add'
        flow1.device = '00:00:00:04:df:61:5d:3a'
        flow1.match = 'in_port=2,dl_vlan=101'
      end
      slice1.addFlow('noc2-noc3') do |flow1|
        flow1.operation = 'add'
        flow1.device = '00:00:00:01:0a:00:00:46'
        flow1.match = 'in_port=136,dl_vlan=101'
      end
      slice1.addFlow('noc2-ufrj') do |flow1|
        flow1.operation = 'add'
        flow1.device = '00:00:00:01:0a:00:00:46'
        flow1.match = 'in_port=9,dl_vlan=101'
      end
    end
  end

  defFlowVisor('fv_ufrj', flowvisor_topic_ufrj) do |flowvisor|
    flowvisor.addSlice('slice1') do |slice1|
      slice1.controller = "tcp:#{controller_ip}:6633"
      slice1.addFlow('ufrj-noc2') do |flow1|
        flow1.operation = 'add'
        flow1.device = '67:8c:08:9e:01:62:d6:63'
        flow1.match = 'in_port=48,dl_vlan=101'
      end
      slice1.addFlow('xen-pronto') do |flow1|
        flow1.operation = 'add'
        flow1.device = '67:8c:08:9e:01:62:d6:63'
        flow1.match = 'in_port=1,dl_vlan=101'
      end
    end
  end

  defFlowVisor('fv_ufg', flowvisor_topic_ufg) do |flowvisor|
    flowvisor.addSlice('slice1') do |slice1|
      slice1.controller = "tcp:#{controller_ip}:6633"
      slice1.addFlow('ufg-noc1') do |flow1|
        flow1.operation = 'add'
        flow1.device = '67:8c:08:9e:01:62:d6:42'
        flow1.match = 'in_port=48,dl_vlan=101'
      end
      slice1.addFlow('xen-pronto') do |flow1|
        flow1.operation = 'add'
        flow1.device = '67:8c:08:9e:01:62:d6:42'
        flow1.match = 'in_port=47,dl_vlan=101'
      end
    end
  end

end

def create_flowvisor_slices()
  onEvent(:ALL_FLOWVISOR_UP) do |event|
    info "Successfully subscribed on ALL Flowvisors RCs"

    info "Creating slices"

    flowvisor('fv_noc').createAllSlices
    flowvisor('fv_ufrj').createAllSlices
    flowvisor('fv_ufg').createAllSlices

    onEvent(:ALL_SLICES_CREATED) do |ev_created|
      info 'All slices created'

      info 'Installing Flows'
      flowvisor('fv_noc').slice('slice1').installFlows do
        info "Flows NOC installed"
      end

      flowvisor('fv_ufrj').slice('slice1').installFlows do
        info "Flows UFRJ installed"
      end

      flowvisor('fv_ufg').slice('slice1').installFlows do
        info "Flows UFG installed"
      end


      after(60) {
        info "Removing openflow flows..."
        flowvisor('fv_noc').releaseAllSlices
        flowvisor('fv_ufrj').releaseAllSlices
        flowvisor('fv_ufg').releaseAllSlices
      }

      after(70) {
        Experiment.done
      }

    end

  end
end
