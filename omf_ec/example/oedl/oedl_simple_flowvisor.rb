# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

FLOWVISOR_TOPIC = 'vinicius-fw'

defFlowVisor('fv1', FLOWVISOR_TOPIC ) do |flowvisor|
  flowvisor.addSlice('slice1') do |slice1|
    slice1.controller = 'tcp:10.16.0.21:6633'
    slice1.addFlow('ovs-1') do |flow1|
      flow1.operation = 'add'
      flow1.device = '00:00:00:16:3e:7a:ff:5a'
      flow1.match = 'in_port=0'
    end
    slice1.addFlow('ovs-2') do |flow2|
      flow2.operation = 'add'
      flow2.device = '00:00:00:16:3e:88:28:a1'
      flow2.match = 'in_port=0'
    end
  end
end

onEvent(:ALL_FLOWVISOR_UP) do |event|
  info "Successfully subscribed on '#{FLOWVISOR_TOPIC}' topic"

  info "Creating slice 'slice1'"

  flowvisor('fv1').createAllSlices

  # Or

  # info "Creating slice 'slice1'"

  # flowvisor('fv1').create('slice1') do
  #   slice1 = flowvisor('fv1').slice('slice1')
  #   info "Slice #{slice1.name} created"
  # end

  onEvent(:ALL_SLICES_CREATED) do |ev_created|
    info 'All slices created'

    flowvisor('fv1').slice('slice1').installFlows do
      info "Flows installed"
    end

    after(120) {
      info "Removing openflow flows..."
      flowvisor('fv1').releaseAllSlices
      # flowvisor('fv1').release('slice1')
    }

    after(125) {
      Experiment.done
    }

  end

end