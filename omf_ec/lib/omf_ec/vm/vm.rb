# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc::Vm

  class VirtualMachine
    include MonitorMixin

    attr_accessor :id, :name, :vm_group, :ram, :cpu, :bridges, :image, :hostname, :user, :ifname
    attr_reader :vm_topic, :vnode_topic
    attr_reader :conf_params, :vlans, :users

    # @param [String] name name of virtual machine
    def initialize(name, vm_group, &block)
      super()
      unless vm_group.kind_of? OmfEc::Vm::VmGroup
        raise ArgumentError, "Expect VmGroup object, got #{vm_group.inspect}"
      end
      #
      @id = "#{OmfEc.experiment.id}.#{self.name}"
      @name = name
      @vm_group = vm_group

      # configure the parameters when there is a topic and the state of vm is running
      self.params = {}
      @conf_params = [:hostname, :ifname]
      @reqt_params = [:ip, :mac]
      @vlans = {}
      @users = {}
    end

    public

      # Verify if has a virtual machine topic associated with this class.
      def has_topic
        !@vm_topic.nil?
      end

      # Verify if has a virtual node topic associated with this class.
      def has_vnode_topic
        !@vnode_topic.nil?
      end

      def addUser(username, password)
        @users << [{username: username, password: password}]
      end

      def addVlan(vlan_id, interface)
        @vlans << [{vlan_id: vlan_id, interface: interface}]
      end

      def create(&block)
        raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.vm_group.has_topic
        # create the vm in hypervisor
        self.vm_group.create_vm do |vm_topic|
          # topic receive to manage the VM
          @vm_topic = vm_topic
          # configure the name of VM
          @vm_topic.configure(vm_name: self.name) do
            # define the option to build the VM
            opts = {ram: self.ram, cpu: self.cpu, bridges: self.bridges, disk: {image: self.image}}
            # build the VM
            @vm_topic.configure(vm_opts: opts, action: :build) do |build_msg|
              if build_msg.success?
                info "VM '#{self.name}'created with success"
                # wait receive the message of creation of the VM
                @vm_topic.on_message do |msg|
                  if msg.itype == "STATUS" and msg.has_properties? and msg.properties[:vm_topic]
                    @vnode_topic = msg.properties[:vm_topic]
                    # after created configure the host parameters
                    after(2) {
                      info "Configuring parameters of VM: '#{self.name}'"
                      self.configure_params
                      block.call if block
                    }
                  end
                end
                # start listen messages of VM
                listen_messages
              else
                info "Could not create the VM: #{self.name}"
              end
            end
          end
        end
        # OmfEc.subscribe_topic(topic_name, self, &block)
      end

      def run
        raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
      end

      def stop
        raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
      end

      def delete
        raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
      end

      def clone(old, new)
        raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
      end

      def state
        raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
      end

    private

      # Calling standard methods or assignments will simply trigger sending a FRCP message
      #
      def listen_messages
        raise('This function can only be executed when there is a topic') unless self.vm_topic
        @vm_topic.on_message do |msg|
          if msg.itype == "STATUS" and msg.has_properties? and msg.properties[:progress]
            info "#{@name}::PROGRESS: #{msg.properties[:progress]}"
          elsif msg.itype == "ERROR" and msg.has_properties? and msg.properties[:reason]
            info "#{@name}::ERROR = #{msg.properties[:reason]}"
          end
        end
      end

      # Configure the parameters.
      #
      # @example
      #   # Creating a vm with hostname and a new user.
      #   vm1.addVm('vm1', 'vm1.hyp.br') do |vm1|
      #     vm1.hostname= 'vm1-host'
      #     vm1.ifname= 'eth1'
      #     vm1.setUser("labora", 12345)
      #     vm1.setVlan("193", "eth1")
      #   end
      def configure_params
        raise('This function can only be executed when there is a topic') unless self.vnode_topic
        self.params.each {|key, value| send_message(key, value, :configure)}
        @users.each {|value| send_message('user', value, :configure)}
        @vlans.each {|value| send_message('vlan', value, :configure)}
      end

      # Calling standard methods or assignments will simply trigger sending a FRCP message
      #
      # @example OEDL
      #   # Will send FRCP CONFIGURE message
      #   vm("vm1").hostname = "labora-vm1"
      #
      #   # Will send FRCP REQUEST message
      #   ovs.ip
      #
      def method_missing(name, *args, &block)
        if name =~ /(.+)=/
          operation = :configure
          name = $1
          self.params[:"#{name}"] = *args if @conf_params.include? :"#{name}"
        else
          operation = :request
          name = :"vm_#{name}" if @reqt_params.include? :"#{name}"
        end

        if self.has_vnode_topic
          send_message(name, *args, operation, &block)
        elsif operation == :request
          error "Operation :request of #{name} is not allowed in this moment."
          return nil
        end
      end

      # Send FRCP message
      #
      # @param [String] name of the property
      # @param [Object] value of the property, for configuring
      # @param [Object] operation to be send, :configure or :request
      def send_message(name, value = nil, operation = :request, &block)
        raise('This function need to be executed after receive the topic of virtual machine.') unless self.has_vnode_topic
        topic = @vnode_topic
        case operation
          when :configure
            topic.configure({ name => value }, { assert: OmfEc.experiment.assertion })
          when :request
            topic.request([name], { assert: OmfEc.experiment.assertion }) do |msg|
              error "Could not get #{name} at this time." unless msg.success?
              block.call(msg[name]) if block
            end
          else
            info "Operation not informed."
          # type code here
        end
      end

  end
end
