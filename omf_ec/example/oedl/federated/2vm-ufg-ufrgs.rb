VM_TOPIC_UFG = 'fed-fibre-ufg-br-urn:publicid:IDN+fibre.ufg.br+node+xen'
VM_GROUP_UFG = 'urn:publicid:IDN+fibre.ufg.br+node+xen_group'
VM1_NAME_UFG = 'urn:publicid:IDN+ch.fibre.org.br:f4813cf7+slice+736e165f:vm1'

VM_TOPIC_UFRGS = 'fed-fibre-ufrgs-br-urn:publicid:IDN+fibre.ufrgs.br+node+xen'
VM_GROUP_UFRGS = 'urn:publicid:IDN+fibre.ufrgs.br+node+xen_group'
VM1_NAME_UFRGS = 'urn:publicid:IDN+ch.fibre.org.br:f4813cf7+slice+736e165f:vm1'

defVmGroup(VM_GROUP_UFG, VM_TOPIC_UFG) do |vmg|
  vmg.addVm(VM1_NAME_UFG) do |vm|
    vm.bridges = ['br_control', 'br_exp2', 'br_internet']
    #vm.bridges = ['br_control', 'br_internet']
    vm.hostname = 'vm-ufg'
    vm.addVlan(101,'eth1')
    #vm.addVlan(200,'eth1')
  end
end

defVmGroup(VM_GROUP_UFRGS, VM_TOPIC_UFRGS) do |vmg|
  vmg.addVm(VM1_NAME_UFRGS) do |vm|
    #vm.bridges = ['omf6-br-test', 'br_control', 'br_internet']
    vm.bridges = ['br_control', 'br_exp4', 'br_internet']
    vm.hostname = 'vm-ufrgs'
    vm.addVlan(101,'eth1')
    #vm.addVlan(200,'eth1')
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
    every(20) {
      vm_ufg.ip do |ip|
        info "IP vm_ufg #{ip}"
      end
      vm_ufg.mac do |mac|
        info "MAC vm_ufg #{mac}"
      end
      vm_ufrgs.ip do |ip|
        info "IP vm_ufrgs #{ip}"
      end
      vm_ufrgs.mac do |mac|
        info "MAC vm_ufrgs #{mac}"
      end
    }
    after(360000) {
      Experiment.done
    }
  end
end