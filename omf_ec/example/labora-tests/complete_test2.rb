require 'omf_common'
require 'yaml'
$stdout.sync = true


OmfCommon.comm.subscribe('vm-testbed') do |vm|
  if vm.error?
    error app.inspect
  else

    vm.configure(vm_name: 'vm-openflow') do |msg|
      puts "CONFIG NAME = #{msg}"
    end

    OmfCommon.eventloop.after 2 do
      vm.configure(
          vm_opts: {
              ram: 1024,
              cpu: 1,
              bridges: ['xenbr0', 'br1'],
              disk: {
                  image: "vm-openflow-template.img"
              }
          },
          ssh_params: {
              ip_address: "192.168.1.2",
              port: 22,
              user: "root",
              key_file: "/root/.ssh/id_rsa"
          }, action: :build)
    end

    vm.on_message do |msg|
      if (msg.itype == "STATUS" and msg.has_properties? and msg.properties[:vm_topic])
        on_vm_created(vm)
      end
    end

  end
end


def on_vm_created(vm_topic)
  OmfCommon.comm.subscribe(vm_topic) do |vm|
    if vm.error?
      error app.inspect
    else
      vm.request([:vm_ip, :vm_mac]) do |reply_msg|
        info "> Slice requested name: #{reply_msg}"
      end
      vm.configure(hostname: "vm-openflow") do |reply_message|
        info "HOSTNAME = #{reply_message}"
      end
      vm.configure(user: [{username: "vinicius", password: "123"}]) do |reply_message|
        info "USER = #{reply_message}"
      end
    end
    after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
  end
end