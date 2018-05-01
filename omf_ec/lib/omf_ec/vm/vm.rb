# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc::Vm

  class VirtualMachine
    include MonitorMixin

    attr_accessor :id, :name, :vm_group
    attr_accessor :ram, :cpu, :bridges, :image
    attr_reader :vm_topic, :vm_node
    attr_reader :conf_params, :vlans, :users, :req_params, :params, :vm_state_up

    # @param [String] name name of virtual machine
    # @param [VmGroup] vm_group
    # @param [Object] block
    def initialize(name, vm_group, &block)
      super()
      unless vm_group.kind_of? OmfEc::Vm::VmGroup
        raise ArgumentError, "Expect VmGroup object, got #{vm_group.inspect}"
      end
      #
      @id = "#{OmfEc.experiment.id}.#{name}"
      @name = name
      @vm_group = vm_group
      @vm_node = OmfEc::Vm::VmNode.new(name, self)

      # configure the parameters when there is a topic and the state of vm is running
      @params = {}
      @conf_params = %w(hostname)
      @req_params = %w(ip mac)
      @vm_state_up = false
      @vlans = []
      @users = []
      @waiting_ok_blocks = []
      @is_waiting_ok = false
    end

    # Verify if has a virtual machine topic associated with this class.
    def has_topic
      !@vm_topic.nil?
    end

    # Verify if has a virtual node topic associated with this class.
    def has_vm_node_topic
      @vm_node.has_topic
    end

    #
    # @param [String] username
    # @param [String] password
    def addUser(username, password)
      self.synchronize do
        @users << {username: username, password: password}
      end
    end

    #
    # @param [Integer] vlan_id
    # @param [String] interface
    def addVlan(vlan_id, interface)
      self.synchronize do
        @vlans << {vlan_id: vlan_id.to_s, interface: interface}
      end
    end

    #
    def recv_vm_topic(&block)
      raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.vm_group.has_topic
      if self.has_topic
        block ? block.call : nil
      else
        if @is_waiting_ok
          @waiting_ok_blocks << block if block
          return
        end

        @is_waiting_ok = true
        already_received = false
        @vm_group.create_vm(@name) do |vm_topic|
          # Wait until receive VM.IMOK message...
          vm_topic.on_message do |msg|
            debug "Message received on topic: #{msg.itype}" unless msg.nil? or msg.itype.nil?
            if msg.itype == 'VM.IMOK' and already_received === false
              debug "VM IMOK message successfully received, proceeding..."
              already_received = true
              @vm_topic = vm_topic
              block.call if block
              @waiting_ok_blocks.each do |wblock|
                wblock.call if wblock
              end
            end
          end
        end
      end
    end

    # Create a virtual machine.
    #
    # @example
    #   vm1 = hyp1.vm('vm1')
    #   vm1.create do
    #     info "vm1 created"
    #   end
    def create(&block)
      raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.vm_group.has_topic
      # create the vm in hypervisor
      self.recv_vm_topic do
        opts = {bridges: self.bridges}
        @vm_topic.configure(vm_opts: opts, action: :build) do |build_msg|
          if build_msg.success?
            info "vm: #{@name} - wait receive the message of creation and boot (initialized and done)"
            @vm_topic.on_message do |msg|
              if msg.itype == "CREATION.PROGRESS"
                info "vm: #{@name} progress #{msg.properties[:progress]}"
              elsif msg.itype == 'VM.TOPIC'
                @vm_node.subscribe(msg.properties[:vm_topic]) do
                  @vm_node.topic.on_message do |vm_node_msg|
                    if vm_node_msg.itype == 'BOOT.INITIALIZED'
                      info "vm: #{@name} boot initialized."
                    end
                    if vm_node_msg.itype == 'BOOT.DONE'
                      info "vm: #{@name} boot done."
                      @vm_state_up = true
                      self.configure_params
                      block.call if block
                    end
                  end
                end
              elsif msg.itype == 'BOOT.TIMEOUT'
                info "vm: #{@name} not initialized, timeout of #{msg.properties[:timeout]} seconds."
              elsif msg.itype == "ERROR" and msg.has_properties? and msg.properties[:reason]
                info "#{@name} ERROR = #{msg.properties[:reason]}"
              end
            end
          else
            info "Could not create the vm: #{@name}"
          end
        end
      end
    end

    #
    def run(&block)
      self.recv_vm_topic do
        @vm_topic.configure(action: :run) do
          block.call if block
        end
      end
    end

    #
    def stop(&block)
      self.recv_vm_topic do
        @vm_topic.configure(action: :stop) do
          @vm_topic.on_message do |msg|
            if msg.itype == 'STATUS' and msg.has_properties? and !(msg.properties[:vm_return].nil?) and msg.properties[:vm_return].include? 'VM stopped successfully'
              block.call if block
            end
          end
        end
      end
    end

    #
    def delete(&block)
      self.recv_vm_topic do
        self.stop do
          @vm_topic.configure(action: :delete)
          block.call if block
        end
      end
    end

    #
    def clone(old, new)
      raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
      warn 'This function is not implemented'
    end

    #
    def state
      raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
      warn 'This function is not implemented'
    end

    # Configure the parameters.
    #
    # @example
    #   hyp1.addVm('vm1', 'vm1.hyp.br') do |vm1|
    #     vm1.hostname= 'vm1-host'
    #     vm1.addVlan(193, "eth0")
    #     vm1.addVlan(201, "eth1")
    #   end
    def configure_params
      raise('This function can only be executed when there is a topic') unless self.has_vm_node_topic
      topic = @vm_node.topic
      @params.each do |key, value|
        if @conf_params.include?(key)
          topic.configure({key => value[0]})
        else
          warn "The parameter '#{key}' is not available to be configured."
        end
      end
      @vlans.each do |vlan|
        topic.configure(vlan: {interface: vlan[:interface], vlan_id: vlan[:vlan_id]})
      end
    end

    # Calling standard methods or assignments will simply trigger sending a FRCP message
    #
    # @example OEDL
    #   # Will send FRCP CONFIGURE message
    #   vm("vm1").hostname = "labora-vm1"
    #
    #   # Will send FRCP REQUEST message
    #   vm("vm1").ip
    #   vm("vm1").mac
    #
    def method_missing(name, *args, &block)
      if name =~ /(.+)=/
        operation = :configure
        name = $1
        if @conf_params.include?("#{name}")
          @params[name] = *args
        else
          warn "The parameter '#{name}' is not available to be configured."
          return nil
        end
      else
        operation = :request
        if @req_params.include?("#{name}")
          name = "vm_#{name}".to_sym
        else
          warn "The parameter '#{name}' is not available to be requested."
          return nil
        end
      end

      if self.has_vm_node_topic
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
      raise('This function need to be executed after receive the topic of virtual machine.') unless self.has_vm_node_topic
      topic = @vm_node.topic
      case operation
        when :configure
          topic.configure({ name => value }, { assert: OmfEc.experiment.assertion }) do |msg|
            block.call(msg) if block
          end
        when :request
          topic.request([name], { assert: OmfEc.experiment.assertion }) do |msg|
            unless msg.success?
              error "Could not get #{name} at this time."
            end
            block.call(msg[name]) if block
          end
        else
          info 'Operation not informed.'
      end
    end

  end
end
