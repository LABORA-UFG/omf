VM_TOPIC_UFG = 'fed-fibre-ufg-br-urn:publicid:IDN+fibre.ufg.br+node+xen'
VM_GROUP_UFG = 'urn:publicid:IDN+fibre.ufg.br+node+xen_group'
VM1_NAME_UFG = 'urn:publicid:IDN+ch.fibre.org.br:f4813cf7+slice+736e165f:vm1'

VM_TOPIC_UFRGS = 'fed-fibre-ufrgs-br-urn:publicid:IDN+fibre.ufrgs.br+node+xen'
VM_GROUP_UFRGS = 'urn:publicid:IDN+fibre.ufrgs.br+node+xen_group'
VM1_NAME_UFRGS = 'urn:publicid:IDN+ch.fibre.org.br:f4813cf7+slice+736e165f:vm2'

defVmGroup(VM_GROUP_UFG, VM_TOPIC_UFG) do |vmg|
  vmg.addVm(VM1_NAME_UFG) do |vm|
    vm.bridges = ['br_control', 'br_exp2', 'br_internet']
    vm.hostname = 'vm-ufg'
    vm.addVlan(101,'eth1')
  end
end

defVmGroup(VM_GROUP_UFRGS, VM_TOPIC_UFRGS) do |vmg|
  vmg.addVm(VM1_NAME_UFRGS) do |vm|
    vm.bridges = ['br_control', 'br_exp4', 'br_internet']
    vm.hostname = 'vm-ufrgs'
    vm.addVlan(101,'eth1')
  end
end

onEvent(:ALL_VM_GROUPS_UP) do |ev|
  info 'OEDL - ALL_VM_GROUPS_UP'
  vm_ufg = vm_group(VM_GROUP_UFG).vm(VM1_NAME_UFG)
  vm_ufg.create do
    info 'vm_ufg created'
  end
  vm_ufrgs = vm_group(VM_GROUP_UFRGS).vm(VM1_NAME_UFRGS)
  vm_ufrgs.create do
    info 'vm_ufrgs created'
  end
  onEvent(:ALL_VMS_CREATED) do |ev_created|
    vm_ufg_ip = ""
    vm_ufrgs_ip = ""
    defEvent :IPS_GOT do
      !vm_ufg_ip.empty? and !vm_ufrgs_ip.empty?
    end
    every(20) {
      vm_ufg.ip do |ip|
        info "UFG IP = #{ip}"
        vm_ufg_ip = "#{ip}"
      end
      vm_ufrgs.ip do |ip|
        info "UFRGS IP = #{ip}"
        vm_ufrgs_ip = "#{ip}"
      end
      puts "vm_ufrgs_ip = #{vm_ufrgs_ip}, vm_ufg_ip = #{vm_ufg_ip}"
    }
    onEvent(:IPS_GOT) do |event|
      puts "IPS GOT = #{vm_ufg_ip}"
      define_flowvisor_slices(vm_ufg_ip)
    end
  end
end

def define_flowvisor_slices(controller_ip)
  flowvisor_topic_noc = 'fed-noc-fibre-org-br-flowvisor3-fw'
  flowvisor_topic_ufrgs = 'fed-fibre-ufrgs-br-flowvisor-fw'
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
      slice1.addFlow('noc1-noc2') do |flow1|
        flow1.operation = 'add'
        flow1.device = '00:00:00:04:df:61:5e:4d'
        flow1.match = 'in_port=40,dl_vlan=101'
      end
      slice1.addFlow('noc2-noc1') do |flow1|
        flow1.operation = 'add'
        flow1.device = '00:00:00:04:df:61:4c:59'
        flow1.match = 'in_port=41,dl_vlan=101'
      end
      slice1.addFlow('noc2-ufrgs') do |flow1|
        flow1.operation = 'add'
        flow1.device = '00:00:00:04:df:61:4c:59'
        flow1.match = 'in_port=3,dl_vlan=101'
      end
    end
  end

  defFlowVisor('fv_ufrgs', flowvisor_topic_ufrgs) do |flowvisor|
    flowvisor.addSlice('slice1') do |slice1|
      slice1.controller = "tcp:#{controller_ip}:6633"
      slice1.addFlow('ufrgs-noc2') do |flow1|
        flow1.operation = 'add'
        flow1.device = '67:8c:08:9e:01:a7:de:59'
        flow1.match = 'in_port=12,dl_vlan=101'
      end
      slice1.addFlow('xen-pronto') do |flow1|
        flow1.operation = 'add'
        flow1.device = '67:8c:08:9e:01:a7:de:59'
        flow1.match = 'in_port=9,dl_vlan=101'
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

onEvent(:ALL_FLOWVISOR_UP) do |event|
  info "Successfully subscribed on ALL Flowvisors RCs"

  info "Creating slices"

  flowvisor('fv_noc').createAllSlices
  flowvisor('fv_ufrgs').createAllSlices
  flowvisor('fv_ufg').createAllSlices

  onEvent(:ALL_SLICES_CREATED) do |ev_created|
    info 'All slices created'

    info 'Installing Flows'
    flowvisor('fv_noc').slice('slice1').installFlows do
      info "Flows NOC installed"
    end

    flowvisor('fv_ufrgs').slice('slice1').installFlows do
      info "Flows UFRGS installed"
    end

    flowvisor('fv_ufg').slice('slice1').installFlows do
      info "Flows UFG installed"
    end


    after(600) {
      info "Removing openflow flows..."
      flowvisor('fv_noc').releaseAllSlices
      flowvisor('fv_ufrgs').releaseAllSlices
      flowvisor('fv_ufg').releaseAllSlices
    }

    after(610) {
      Experiment.done
    }

  end

end
