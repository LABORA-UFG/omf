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
    # @param [String] topic_name to subscribe.
    # @param [Object] block
    def initialize(name, topic_name, &block)
      super()
      @id = "#{OmfEc.experiment.id}.#{name}"
      @name = name
      @topic_name = topic_name
      @vms ||= []

      OmfEc.subscribe_topic(topic_name, self, &block)
    end

    # Verify if has a topic associated with this class, used to trigger the event :ALL_VM_GROUPS_UP.
    def has_topic
      !@topic.nil?
    end

    # Associate the topic reference when the subscription is received from OmfEc::subscribe_topic.
    #
    # @param [Object] topic
    def associate_topic(topic)
      self.synchronize do
        @topic = topic
      end
    end

    # Add a virtual machine in hypervisor.
    #
    # @param [String] name of virtual machine.
    def addVm(name, force_new=false, &block)
      self.synchronize do
        vm = OmfEc::Vm::VirtualMachine.new(name, force_new, self)
        if @vms.find {|v| v.name == name}
          error "vm: #{name} - already added."
        else
          @vms << vm
          OmfEc.experiment.add_vm(vm)
          block.call(vm) if block
        end
      end
    end

    # Create a new virtual machine in the hypervisor and receive the topic to manage it.
    #
    # @param [Object] name of virtual machine.
    # @param [Object] block
    def create_vm(name, force_new, &block)
      raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
      @topic.create(:virtual_machine, {:label => name, :force_new => force_new}) do |vm|
        vm_topic = vm.resource
        if vm_topic.error?
          error app.inspect
        else
          vm_topic.on_subscribed do
            block.call(vm_topic) if block
          end
        end
      end
    end

    # Find a virtual machine by name.
    #
    # @param [String] name of virtual machine
    # @return [VirtualMachine]
    def vm(name)
      @vms.find {|v| v.name == name}
    end

  end
end
