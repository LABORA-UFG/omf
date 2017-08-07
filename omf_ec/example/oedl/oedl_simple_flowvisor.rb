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
  end
end

onEvent(:ALL_FLOWVISOR_UP) do |event|
  info "Successfully subscribed on '#{FLOWVISOR_TOPIC}' topic"

  flowvisor('fv1').createAllSlices

  flowvisor('fv1').create('slice1') do
    slice1 = flowvisor('fv1').slice('slice1')
    info "Slice #{slice1.name} created"

    slice1.name do |name|
      info "Slice #{name}"
    end
  end

  onEvent(:ALL_SLICES_CREATED) do |ev_created|
    info 'All slices created'

    flowvisor('fv1').slice('slice1').addFlow('netfpga-porta-2') do |flow2|
      flow2.operation = 'add'
      flow2.device = '00:00:00:00:00:00:81:02'
      flow2.match = 'in_port=2,dl_vlan=193'
    end

    after(30) {
      info "Removing openflow flows..."
      # flowvisor('fv1').releaseAllSlices
      flowvisor('fv1').release('slice1')
    }

    after(35) {
      Experiment.done
    }

  end

end