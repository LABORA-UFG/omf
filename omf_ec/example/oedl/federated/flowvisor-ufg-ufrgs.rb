# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

FLOWVISOR_TOPIC_NOC = 'fed-noc-fibre-org-br-flowvisor3-fw'
#FLOWVISOR_TOPIC_UFRJ = 'fed-ufrj-br-flowvisor-fw'
FLOWVISOR_TOPIC_UFRGS = 'fed-fibre-ufrgs-br-flowvisor-fw'
FLOWVISOR_TOPIC_UFG = 'fed-fibre-ufg-br-flowvisor-fw'
CONTROLLER_IP = "10.137.11.210"

defFlowVisor('fv_noc', FLOWVISOR_TOPIC_NOC) do |flowvisor|
  flowvisor.addSlice('slice1') do |slice1|
    slice1.controller = "tcp:#{CONTROLLER_IP}:6633"
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

defFlowVisor('fv_ufrgs', FLOWVISOR_TOPIC_UFRGS) do |flowvisor|
  flowvisor.addSlice('slice1') do |slice1|
    slice1.controller = "tcp:#{CONTROLLER_IP}:6633"
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

defFlowVisor('fv_ufg', FLOWVISOR_TOPIC_UFG) do |flowvisor|
  flowvisor.addSlice('slice1') do |slice1|
    slice1.controller = "tcp:#{CONTROLLER_IP}:6633"
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


    after(30) {
      info "Removing openflow flows..."
      flowvisor('fv_noc').releaseAllSlices
      flowvisor('fv_ufrgs').releaseAllSlices
      flowvisor('fv_ufg').releaseAllSlices
    }

    after(40) {
      Experiment.done
    }

  end

end