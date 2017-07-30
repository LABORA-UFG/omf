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
    attr_reader :conf_params, :vlans, :users, :req_params, :params

    TIME_TO_VM_RUN = 40

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
      @vm_node = OmfEc::Vm::VmNode.new(name, self)

      # configure the parameters when there is a topic and the state of vm is running
      @params = {}
      @conf_params = %w(hostname if_name)
      @req_params = %w(ip mac state)
      @vlans = []
      @users = []
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
        @vlans << {vlan_id: vlan_id, interface: interface}
      end
    end

    #
    def recv_vm_topic(&block)
      raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.vm_group.has_topic
      if self.has_topic
        if block
          block.call
        else
          return nil
        end
      end
      @vm_group.create_vm do |vm_topic|
        @vm_topic = vm_topic
        @vm_topic.configure(vm_name: self.name) do |vm_name|
          info "recv_vm_topic::configure::vm_name: #{vm_name}" # TODO
          block.call if block
        end
      end
    end

    #
    def create(&block)
      raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.vm_group.has_topic
      # create the vm in hypervisor
      info "create" # TODO
      self.recv_vm_topic do
        opts = {ram: self.ram, cpu: self.cpu, bridges: self.bridges, disk: {image: self.image}}
        # build the VM
        info "recv_vm_topic -> create" # TODO
        @vm_topic.configure(vm_opts: opts, action: :build) do |build_msg|
          info "topic -> create" # TODO
          if build_msg.success?
            info "VM #{self.name} created with success" # TODO
            # wait receive the message of creation of the VM
            @vm_topic.on_message do |msg|
              if msg.itype == "STATUS" and msg.has_properties? and msg.properties[:vm_topic]
                info "Virtual Node topic received" # TODO
                @vm_node.subscribe(msg.properties[:vm_topic]) do
                  # after created configure the host parameters
                  sleep(TIME_TO_VM_RUN)
                  self.configure_params
                  info "Configuring parameters of VM: '#{self.name}'" # TODO
                  block.call if block
                end
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

    #
    def run(&block)
      info "run" # TODO
      self.recv_vm_topic do
        info "recv_vm_topic -> run" # TODO
        @vm_topic.configure(vm_name: self.name, action: :run) do
          info "topic -> run" # TODO
          block.call if block
        end
      end
    end

    #
    def stop(&block)
      info "stop" # TODO
      self.recv_vm_topic do
        info "recv_vm_topic -> stop" # TODO
        @vm_topic.configure(vm_name: self.name, action: :stop) do
          info "topic -> stop" # TODO
          block.call if block
        end
      end
    end

    #
    def delete(&block)
      info "delete" # TODO
      self.recv_vm_topic do
        info "recv_vm_topic -> delete" # TODO
        @vm_topic.configure(vm_name: self.name, action: :delete) do
          info "topic -> delete" # TODO
          block.call if block
        end
      end
    end

    #
    def clone(old, new)
      raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
    end

    #
    def state
      raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
    end

    # Calling standard methods or assignments will simply trigger sending a FRCP message
    #
    def listen_messages
      raise('This function can only be executed when there is a topic') unless self.vm_topic
      @vm_topic.on_message do |msg|
        if msg.itype == "STATUS" and msg.has_properties? and msg.properties[:vm_topic]
          info 'listen_messages::receive_vm_topic'
        end
        if msg.itype == "STATUS" and msg.has_properties? and msg.properties[:progress]
          info "#{@name} progress: #{msg.properties[:progress]}"
        elsif msg.itype == "ERROR" and msg.has_properties? and msg.properties[:reason]
          info "#{@name} ERROR = #{msg.properties[:reason]}"
        end
      end
    end

    # Configure the parameters.
    #
    # @example
    #   # Creating a vm with hostname and a new user.
    #   vm1.addVm('vm1', 'vm1.hyp.br') do |vm1|
    #     vm1.hostname= 'vm1-host'
    #     vm1.if_name= 'eth1'
    #     vm1.setUser("labora", 12345)
    #     vm1.setVlan("193", "eth1")
    #   end
    def configure_params
      raise('This function can only be executed when there is a topic') unless self.has_vm_node_topic
      topic = @vm_node.topic
      info "configure_params::params -> #{@params}" # TODO:: problema que os parâmetros de string estão sendo enviados como array ex: ["labora-host"]
      @params.each do |key, value|
        info "configure_params::param::::#{key}, #{value}" # TODO
        topic.configure({:"#{key}" => "#{value}"}) do |vm_param|
          info "configure_params::param: #{vm_param}" # TODO
        end
      end
      info "configure_params::users -> #{@users}" # TODO
      @users.each do |user|
        info "configure_params::user::::#{user}" # TODO
        topic.configure(user: [{username: user[:username], password: user[:password]}]) do |vm_user|
          info "configure_params::user: #{vm_user}" # TODO
        end
      end
      info "configure_params::vlans -> #{@vlans}" # TODO
      @vlans.each do |vlan|
        info "configure_params::vlan::::#{value}" # TODO
        topic.configure(vlan: [{interface: vlan[:interface], vlan_id: vlan[:vlan_id]}]) do |vm_vlan|
          info "configure_params::vlan: #{vm_vlan}" # TODO
        end
      end
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
        arg = *args
        info "method_missing::configure -> #{name}, #{arg}" # TODO
        puts "method_missing::configure -> #{name}, #{arg}" # TODO
        if @conf_params.include?("#{name}")
          info "method_missing::configure-2 -> #{name}, #{arg}" # TODO
          puts "method_missing::configure-2-> #{name}, #{arg}" # TODO
          @params[name] = *args
        else
          error "method_missing::configure to #{name} is not available."
          return nil
        end
      else
        operation = :request
        if @req_params.include?("#{name}")
          info 'method_missing::request ----'
          name = "vm_#{name}".to_sym
          info "method_missing::request -> #{name}" # TODO
        else
          error "method_missing::request to #{name} is not available."
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
          info "send_message::configure -> #{name}" # TODO
          topic.configure({ name => value }, { assert: OmfEc.experiment.assertion }) do |msg|
            info "send_message::configure::received -> #{msg}" # TODO
            block.call(msg) if block
          end
        when :request
          info "send_message::request -> #{name}" # TODO
          topic.request([name], { assert: OmfEc.experiment.assertion }) do |msg|
            unless msg.success?
              error "Could not get #{name} at this time."
            end
            info "send_message::request::receive -> #{name}" # TODO
            block.call(msg[name]) if block
          end
        else
          info "Operation not informed."
        # type code here
      end
    end

  end
end
