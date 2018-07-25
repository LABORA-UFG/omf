# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc::Vm

  class VmGroup
    include MonitorMixin

    attr_accessor :id, :name, :topic_name, :app_contexts, :execs
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

      # Applications
      @app_contexts = []
      @execs = []
      @applications ||= []

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
    def addVm(name, &block)
      self.synchronize do
        vm = OmfEc::Vm::VirtualMachine.new(name, self)
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
    def create_vm(name, &block)
      raise('This function need to be executed after ALL_VM_GROUPS_UP event') unless self.has_topic
      raise("The Virtual machine #{name} is not defined in this group") unless vm(name)
      @topic.create(:virtual_machine, {:label => name}) do |vm|
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

    ## Begin Application methods
    def address(suffix = nil)
      t_id = suffix ? "#{@id}_#{suffix.to_s}" : @id
      OmfCommon.comm.string_to_topic_address(t_id)
    end

    def create_application(name, opts, &block)
      self.synchronize do
        r_type = 'application'
        resource_group_name = self.address(r_type)
        opts = opts.merge({
                              hrn: name,
                              membership: resource_group_name,
                              state: 'created'
                          })

        created_apps = 0
        @vms.each { |vm|
          info "Creating application on #{vm.name}"
          opts.delete(:type)
          vm.vm_node.topic.create(r_type, opts, assert: OmfEc.experiment.assertion) do |app|
            @applications << {:name => name, :topic => app.resource, :vm => vm, :state => :stopped}
            created_apps = created_apps + 1
            block.call if (block and created_apps == @vms.size)
          end
        }
      end
    end

    # Create an application for the group and start it
    #
    def exec(command, show_std=true)
      name = SecureRandom.uuid

      self.synchronize do
        @execs << name
      end

      create_application(name, {binary_path: command}) do
        info "Sending app start for command '#{command}' in group '#{@name}'"
        after(2) {
          run_application(name, show_std)
        }
      end
    end

    def run_application(app_name, show_std)
      @applications.each { |app|
        if app[:name] == app_name and app[:status] != :running
          vm_simple_name = app[:vm].name.split(':')
          vm_simple_name = vm_simple_name[vm_simple_name.size-1]
          app[:topic].on_subscribed do
            app[:topic].configure({ :state => :running }, { assert: OmfEc.experiment.assertion })
            app[:topic].on_inform  do |m|
              case m.itype
                when 'STATUS'
                  if m[:status_type] == 'APP_EVENT'
                    case m[:event]
                      when 'STARTED'
                        app[:state] = :running
                        info "Application '#{app_name}' is running on #{vm_simple_name}"
                      when 'EXIT'
                        info "Application '#{app_name}' finalized in #{vm_simple_name}"
                        app[:state] = :stopped
                      else
                        info "#{m[:event]} (#{vm_simple_name}): #{m[:msg]}" if (m[:msg] and show_std === true)
                    end
                  end
                when 'ERROR'
                  error "(#{vm_simple_name}): #{m[:reason]}"
              end
            end
          end
        end
      }
    end

    # Start ONE application by name
    def startApplication(app_name, show_std=true)
      if @app_contexts.find { |v| v.orig_name == app_name }
        run_application(app_name, show_std)
      else
        warn "No application with name '#{app_name}' defined in group #{@name}. Nothing to start"
      end
    end

    # Start ALL applications in the group
    def startApplications(show_std=true)
      if @app_contexts.empty?
        warn "No applications defined in group #{@name}. Nothing to start"
      else
        @applications.each { |app|
          run_application(app[:name], show_std)
        }
      end
    end

    # Stop ALL applications in the group
    def stopApplications
      if @app_contexts.empty?
        warn "No applications defined in group #{@name}. Nothing to stop"
      else
        @applications.each { |app|
          app[:status] = :stopped
          app[:topic].configure({ :state => :stopped }, { assert: OmfEc.experiment.assertion })
        }
      end
    end

    def addApplication(name, location = nil, &block)
      app_cxt = OmfEc::Context::AppContext.new(name,location,self)
      block.call(app_cxt) if block
      @app_contexts << app_cxt
    end

    def releaseApplications
      if @app_contexts.empty?
        warn "No applications defined in group #{@name}. Nothing to release"
      else
        @applications.each { |app|
          app[:vm].vm_node.topic.release(app[:topic], { assert: OmfEc.experiment.assertion })
        }
      end
    end
  end
end
