# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

SWITCH_TOPIC = 'vm-fibre-ovs'

defSwitch('ovs', SWITCH_TOPIC) do |ovs|
  ovs.controller = ['tcp:127.0.0.1:6633']
end

onEvent(:ALL_SWITCHES_UP) do |event|
  info "Successfully subscribed on '#{SWITCH_TOPIC}' topic"

  switch('ovs').addFlows(flows: ["in_port=1,action=output:2", "in_port=2,action=output:1"])

  info "Waiting 30 seconds until flows removal..."
  after(30) {
    info "Removing openflow flows..."
    switch('ovs').delFlows(["in_port=1"])
  }

  every(5) {
    info "Requesting openflow flows..."
    switch('ovs').dumpFlows.each do |flow|
      info "- Openflow Flow: #{flow}"
    end
  }

  after(35) {
    Experiment.done
  }

end