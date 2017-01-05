require 'omf_common'
# OMF_VERSIONS = 6.0

def create_slice(flowvisor)
  flowvisor.create(:flowvisor_proxy, {name: "test", controller_url: "tcp:172.168.1.2:6633"}) do |reply_msg|
    if reply_msg.success?
      slice = reply_msg.resource

      slice.on_subscribed do
        info ">>> Connected to newly created slice #{reply_msg[:res_id]} with name #{reply_msg[:name]}"
        on_slice_created(slice)
      end

      after(10) do
        flowvisor.release(slice) do |reply_msg|
          info ">>> Released slice #{reply_msg[:res_id]}"
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

  slice.configure(flows: [{operation: 'add', device: '00:00:00:13:3b:0c:31:34', name: 'test'},
                          {operation: 'add', device: '00:00:00:13:3b:0c:31:34', name: 'test-2'}]) do |reply_msg|
    info "> Slice configured flows:"
    reply_msg[:flows].each do |flow|
      logger.info "   #{flow}"
    end
  end

  slice.on_error do |msg|
    error msg[:reason]
  end
  slice.on_warn do |msg|
    warn msg[:reason]
  end
end

OmfCommon.comm.subscribe('maq3-switch-fw') do |flowvisor|
  unless flowvisor.error?
    create_slice(flowvisor)
  else
    error flowvisor.inspect
  end

  after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end