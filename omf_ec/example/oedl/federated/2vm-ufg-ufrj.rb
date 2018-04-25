VM_TOPIC_UFG = 'fed-fibre-ufg-br-urn:publicid:IDN+fibre.ufg.br+node+xen'
VM_GROUP_UFG = 'urn:publicid:IDN+fibre.ufg.br+node+xen_group'
VM1_NAME_UFG = 'urn:publicid:IDN+ch.fibre.org.br:f4813cf7+slice+736e165f:vm1'

VM_TOPIC_UFRJ = 'fed-ufrj-br-urn:publicid:IDN+ufrj.br+node+xen'
VM_GROUP_UFRJ = 'urn:publicid:IDN+ufrj.br+node+xen_group'
VM1_NAME_UFRJ = 'urn:publicid:IDN+ch.fibre.org.br:f4813cf7+slice+736e165f:vm3'

defVmGroup(VM_GROUP_UFG, VM_TOPIC_UFG) do |vmg|
  vmg.addVm(VM1_NAME_UFG) do |vm|
    vm.bridges = ['br_control', 'br_exp2', 'br_internet']
    #vm.bridges = ['br_control', 'br_internet']
    vm.hostname = 'vm-ufg'
    vm.addVlan(101,'eth1')
    #vm.addVlan(200,'eth1')
  end
end

defVmGroup(VM_GROUP_UFRJ, VM_TOPIC_UFRJ) do |vmg|
  vmg.addVm(VM1_NAME_UFRJ) do |vm|
    #vm.bridges = ['omf6-br-test', 'br_control', 'br_internet']
    vm.bridges = ['br_control', 'br_exp3', 'br_internet']
    vm.hostname = 'vm-ufrj'
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
  vm_ufrj = vm_group(VM_GROUP_UFRJ).vm(VM1_NAME_UFRJ)
  vm_ufrj.create do
    info 'vm_ufrj created'
  end
  onEvent(:ALL_VMS_CREATED) do |ev_created|
    every(20) {
      vm_ufg.ip do |ip|
        info "IP vm_ufg #{ip}"
      end
      vm_ufg.mac do |mac|
        info "MAC vm_ufg #{mac}"
      end
      vm_ufrj.ip do |ip|
        info "IP vm_ufrj #{ip}"
      end
      vm_ufrj.mac do |mac|
        info "MAC vm_ufrj #{mac}"
      end
    }
    after(360000) {
      Experiment.done
    }
  end
end