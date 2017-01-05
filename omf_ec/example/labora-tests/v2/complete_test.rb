require 'omf_common'
require 'yaml'
$stdout.sync = true

############################## XEN TEST #####################################################

VM_TEMPLATE = "vm-template-2.img"

def createVM(vm_name, vm_template, vm_bridge, callback)
  OmfCommon.comm.subscribe('omf6-ufrj-xen') do |vm|
    if vm.error?
      error app.inspect
    else

      vm.configure(vm_name: vm_name) do |msg|
        puts "CONFIG NAME = #{msg[:vm_name]}"
      end

      OmfCommon.eventloop.after 2 do
        vm.configure(
            vm_opts: {
                ram: 1024,
                cpu: 1,
                bridges: ['omf6-br-test', vm_bridge],
                disk: {
                    image: vm_template
                }
            },
            ssh_params: {
                ip_address: "ibm",
                port: 22,
                user: "root",
                key_file: "/root/.ssh/id_rsa"
            }, action: :build)
      end

      vm.on_message do |msg|
        if (msg.itype == "STATUS" and msg.has_properties? and msg.properties[:vm_topic])
          after(50) { on_vm_created(msg.properties[:vm_topic], callback) }
        end
      end

    end
  end
end


def on_vm_created(vm_topic, callback)
  OmfCommon.comm.subscribe(vm_topic) do |vm|
    info "Configuring VM on topic: #{vm_topic}"
    if vm.error?
      error app.inspect
    else
      vm.request([:vm_ip, :vm_mac]) do |reply_msg|
        info "> IP: #{reply_msg[:vm_ip]}"
        info "> MAC: #{reply_msg[:vm_mac]}"
      end
      vm.configure(hostname: "vm-openflow") do |reply_message|
        info "HOSTNAME = #{reply_message[:hostname]}"
      end
      vm.configure(user: [{username: "vinicius", password: "123"}]) do |reply_message|
        info "USER = #{reply_message[:user]}"
      end
      vm.configure(vlan: [{interface: "eth1", vlan_id: "193"}]) do |msg|
        info msg[:vlan]
      end
    end

    if callback
      callback()
    end
  end
end


createVM("vm-1", VM_TEMPLATE, "br_exp2", nil)

after(600) { createVM("vm-2", VM_TEMPLATE, "br_exp2", test_flowvisor_rc) }

############################## FLOWVISOR TEST #####################################################

def create_slice(flowvisor)
  flowvisor.create(:flowvisor_proxy, {name: "test", controller_url: "tcp:10.129.12.103:6633"}) do |reply_msg|
    if reply_msg.success?
      slice = reply_msg.resource

      slice.on_subscribed do
        info ">>> Connected to newly created slice #{reply_msg[:res_id]} with name #{reply_msg[:name]}"
        on_slice_created(slice)
      end

      after(300) do
        flowvisor.release(slice) do |reply_msg|
          info ">>> Released slice #{reply_msg[:res_id]}"
          exit(0)
        end
      end
    else
      error ">>> Slice creation failed - #{reply_msg[:reason]}"
    end
  end
end

def on_slice_created(slice)

  slice.request([:name]) do |reply_msg|
    info "> Slice requested name: #{reply_msg[:name]}"
  end

  slice.configure(flows: [{operation: 'add', device: '67:8c:08:9e:01:62:d6:63', match: "in_port=1,dl_vlan=193", name: "pronto-porta-1"},
                          {operation: 'add', device: '00:00:00:00:00:00:81:02', match: "in_port=2,dl_vlan=193", name: "netfpga-porta-2"},
                          {operation: 'add', device: '67:8c:08:9e:01:62:d6:63', match: "in_port=2,dl_vlan=193", name: "pronto-porta-2"},
                          {operation: 'add', device: '00:00:00:00:00:00:81:02', match: "in_port=1,dl_vlan=193", name: "netfpga-porta-1"}]) do |reply_msg|
    info "> Slice configured flows:"
    reply_msg[:flows].each do |flow|
      logger.info "   #{flow}"
    end
  end

  slice.on_message do |msg|
    error msg[:reason]
  end

end


def test_flowvisor_rc()
  OmfCommon.comm.subscribe('flowvisor-fw') do |flowvisor|
    unless flowvisor.error?
      create_slice(flowvisor)
    else
      error flowvisor.inspect
    end

    after(310) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
  end
end