# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc::Vm

  class VmNode
    include MonitorMixin

    attr_accessor :id, :topic_name
    attr_reader :topic, :vm

    # @param [String] name of the vm node.
    def initialize(name, vm)
      super()
      unless vm.kind_of? OmfEc::Vm::VirtualMachine
        raise ArgumentError, "Expect VirtualMachine object, got #{vm?.inspect}"
      end
      self.id = "#{OmfEc.experiment.id}.#{name}"
      @vm = vm
    end

    def subscribe(topic_name, &block)
      @topic_name = topic_name
      OmfEc.subscribe_topic(@topic_name, self, &block)
    end

    # Verify if has a topic associated with this class, used to trigger the event :ALL_VM_GROUPS_UP.
    def has_topic
      !@topic.nil?
    end

    # Associate the topic reference when the subscription is received from OmfEc::subscribe_topic.
    # @param [Object] topic
    def associate_topic(topic)
      self.synchronize do
        @topic = topic
      end
    end

  end
end
