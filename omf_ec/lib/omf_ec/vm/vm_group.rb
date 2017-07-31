# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc::Vm

  class VmGroup
    include MonitorMixin

    attr_accessor :id, :name, :topic_name
    attr_reader :topic, :vms

    # @param [String] name of the group.
    def initialize(name, topic_name, &block)
      super()
      self.id = "#{OmfEc.experiment.id}.#{self.name}"
      self.name = name
      self.topic_name = topic_name
      @vms ||= []

      OmfEc.subscribe_topic(topic_name, self, &block)
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

    # Add a virtual machine in hypervisor.
    # @param [String] name of virtual machine.
    def addVm(name, &block)
      self.synchronize do
        vm = OmfEc::Vm::VirtualMachine.new(name, self)
        if self.vms.find {|v| v.name == name}
          error "The Vm (#{name}) already added."
        else
          self.vms << vm
          OmfEc.experiment.add_vm(vm)
          block.call(vm) if block
        end
      end
    end

    # Create a new virtual machine in the hypervisor and receive the topic to manage it.
    # @return [vm_topic] topic to manage the virtual machine.
    def create_vm(&block)
      raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
      # self.synchronize do
      topic.create(:virtual_machine) do |vm|
        vm_topic = vm.resource
        if vm_topic.error?
          error app.inspect
        else
          vm_topic.on_subscribed do
            block.call(vm_topic) if block
          end
        end
      end
      # end
    end

    def vm(name)
      self.vms.find {|v| v.name == name}
    end

  end
end
