# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

#
# Copyright (c) 2012 National ICT Australia (NICTA), Australia
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#
# This module defines a Resource Proxy (RP) for a Virtual Machine Factory
#
# Utility dependencies: common_tools, libvirt, vmbuilder
#
# This VM Proxy has the following properties:
# - :use_sudo, use 'sudo' when running VM-related commands (default => true)
# - :hypervisor, the hypervisor to use (default => HYPERVISOR_DEFAULT)
# - :hypervisor_uri, the URI of the hypervisor to use (default => HYPERVISOR_URI_DEFAULT)
# - :virt_mngt, the virtualisation management tool to use (default => VIRTUAL_MNGT_DEFAULT)
# - :img_builder, the tool to use to build VM image (default => IMAGE_BUILDER_DEFAULT)
# - :state, the current state of this VM Proxy (default => :stopped)
# - :ready, is the VM for this Proxy ready to be run? (default => false)
# - :action, the next action to perform on this VM Proxy (build, define, stop, run, delete, attach, or clone_from)
# - :vm_name, the name of this VM (default => VM_NAME_DEFAULT_PREFIX + "_" + current time)
# - :image_directory, the directory holding this VM's disk image (default => VM_DIR_DEFAULT)
# - :image_path, the full path to this VM's disk image (default => image_directory + vm_name)
# - :vm_os, the OS to use on this VM (default => VM_OS_DEFAULT)
# - :vm_definition, the path to an definition file for this VM
# - :vm_original_clone, the name of an existing VM that may be used as a template for this one
# - :enable_omf, is an OMF Resource Proxy (to be) installed on this VM? (default => true)
# - :omf_opts, the options to set for the OMF v6 RC on this VM (default => OMF_DEFAULT)
#
# USAGE NOTES:
#
# A VirtualMachine Proxy is an interface to an underlying VM resource on a
# physical resource. When a VM Proxy is created, it is not necessarily yet
# associated with such a VM resource (unless the original 'create' command
# for this VM Proxy had some optional property configuration as described
# below). 
# 
# Thus you must associate this VM Proxy with an underlying VM resource. This
# could be done in the following manner:
# - A) build a brand new VM resource, including building a new disk image for it
# - B) build a new VM resource from an existing VM definition file
# - C) build a new VM resource by cloning an existing VM resource
# - D) attach a VM resource (existing already on the system) to this VM Proxy
# 
# Once the VM Proxy is associated to an underlying VM resource, it can 
# start/stop it or de-associated ('delete' action) from it, according to the
# following state diagram:
#      
#                     build,
#                  clone,define,
#    +---------+      attach     +---------+     run     +---------+
#    |         |--------|------->| stopped |------|----->|         |
#    | stopped |                 | + ready |             | running |
#    |         |<-------|--------|         |<-----|------|         |
#    +---------+     delete      +---------+     stop    +---------+
# 
#
# Some examples of message sequences to send to a freshly created VM proxy
# 'new_VMP' to realise each of the above association cases are given in the 
# 'Examples' section below.
#
# @example Case A: create and then run a new VM with a new disk image using all the default settings:
#
#    # Communication setup
#    comm = Comm.new(:xmpp)
#    vm_topic = comm.get_topic('new_VMP')
#
#    # Define the messages to publish
#    conf_vm_name = comm.configure_message([vm_name: 'my_VM_123'])
#    conf_vm_options = comm.configure_message([
#                           ubuntu_opts: { bridge: 'br0' }, 
#                           vmbuilder_opts: {ip: '10.0.0.240', 
#                                            net: '10.0.0.0',
#                                            bcast: '10.255.255.255',
#                                            mask: '255.0.0.0',
#                                            gw: '10.0.0.200',
#                                            dns: '10.0.0.200'} ])
#    conf_vm_build = comm.configure_message([action: :build])
#    conf_vm_run = comm.configure_message([action: :run])
#
#    # Define a new event to run the VM resource once it is 'ready'
#    vm_topic.on_message do |m|
#      if (m.operation == :inform) && (m.read_content("itype") == 'STATUS') && m.read_property('ready')
#        conf_vm_run.publish vm_topic.id    
#      end
#    end
#
#    # Publish the defined messages
#    conf_vm_name.publish vm_topic.id    
#    conf_vm_options.publish vm_topic.id    
#    conf_vm_build.publish vm_topic.id    
#
# @example Case B: create and run a new VM using an existing definition file:
# 
#    # Do the communication setup as in the above example...
#
#    # Define the messages to publish
#    conf_vm_name = comm.configure_message([vm_name: 'my_VM_123'])
#    conf_vm_definition = comm.configure_message([vm_definition: '/home/me/my_vm_definition.xml'])
#    conf_vm_define = comm.configure_message([action: :define])
#    conf_vm_run = comm.configure_message([action: :run])
#
#    # Define a new event to run the VM resource as in the above example...
#
#    # Publish the defined messages
#    conf_vm_name.publish vm_topic.id    
#    conf_vm_definition.publish vm_topic.id    
#    conf_vm_define.publish vm_topic.id 
#
# @example Case C: create and run a new VM by cloning an existing VM:
# 
#    # Do the communication setup as in the above example...
#
#    # Define the messages to publish
#    # Note that the existing VM to clone from must be defined and known
#    # by the virtualisation management tool set in the :virt_mngt property
#    conf_vm_name = comm.configure_message([vm_name: 'my_VM_123'])
#    conf_vm_original_name: comm.configure_message([vm_original_clone: 'existing_VM_456']),
#    conf_vm_clone = comm.configure_message([action: :clone_from])
#    conf_vm_run = comm.configure_message([action: :run])
#
#    # Define a new event to run the VM resource as in the above example...
#
#    # Publish the defined messages
#    conf_vm_name.publish vm_topic.id    
#    conf_vm_original_name.publish vm_topic.id    
#    conf_vm_clone.publish vm_topic.id 
#
# @example Case D: associate an existing VM to this VM Proxy and run it:
# 
#    # Do the communication setup as in the above example...
#
#    # Define the messages to publish
#    # Note that the existing VM to associate to this VM Proxy must be defined 
#    # and known by the virtualisation management tool set in the :virt_mngt property
#    conf_vm_name = comm.configure_message([vm_name: 'my_VM_123'])
#    conf_vm_attach: comm.configure_message([action: :attach]),
#    conf_vm_run = comm.configure_message([action: :run])
#
#    # Define a new event to run the VM resource as in the above example...
#
#    # Publish the defined messages
#    conf_vm_name.publish vm_topic.id    
#    conf_vm_attach.publish vm_topic.id    
#
# EXTENSION NOTES:
#
# By default this VM Proxy interacts with a KVM hypervisor using the libvirt 
# virtualisation tools (i.e. virsh, virt-clone) to manipulate Ubuntu-based VMs,
# which may be built using ubuntu's vmbuilder tool. However, one can extend this 
# to support other hypervisors and tools. 
#
# - to extend:
#   - create one/many utility file(s) to hold the code of your extension,
#     e.g. "myext.rb"
#   - assuming you will use the "foo" virtualisation management tools, and 
#     the "bar" image building tool, then you must define within your utility 
#     file(s) the following work methods, which should perform the obvious
#     tasks mention by their names. In addition they must return 'true' if 
#     their tasks were successfully performed, or 'false' otherwise. See the
#     provided libvirt and vmbuilder utility files for some examples.
#     - define_vm_with_foo 
#     - stop_vm_with_foo 
#     - run_vm_with_foo 
#     - attach_vm_with_foo 
#     - clone_vm_with_foo 
#     - delete_vm_with_foo
#     - build_img_with_bar
#
# - to use that extension:
#   - require that/these utility files
#   - set the virt_mngt, virt_mngt properties to "foo", "bar" respectively
#
# @see OmfRc::Util::Libvirt
# @see OmfRc::Util::Vmbuilder
module OmfRc::ResourceProxy::VirtualMachine
  include OmfRc::ResourceProxyDSL

  register_proxy :virtual_machine, :create_by => :hypervisor
  utility :common_tools
  utility :libvirt
  utility :vmbuilder
  utility :virt_install
  utility :fibre

  # Default VirtualMachine to use
  HYPERVISOR_DEFAULT = :kvm
  # Default URI for the default VirtualMachine
  HYPERVISOR_URI_DEFAULT = 'qemu:///system'
  # Default virtualisation management tool to use
  VIRTUAL_MNGT_DEFAULT = :libvirt
  # Default VM image building tool to use
  IMAGE_BUILDER_DEFAULT = :virt_install
  # Default prefix to use for the VM's name
  VM_NAME_DEFAULT_PREFIX = "vm"
  # Default directory to store the VM's disk image
  VM_DIR_DEFAULT = "/home/thierry/experiments/omf6-dev/images"
  # Default OS used on this VM
  VM_OS_DEFAULT = 'ubuntu'
  # Default OMF v6 parameters for the Resource Controller on the VM
  OMF_DEFAULT = Hashie::Mash.new({
                                     server: 'srv.mytestbed.net',
                                     user: nil, password: nil,
                                     topic: nil
                                 })

  # VM States
  STATE_NOT_CREATED = 'NOT_CREATED'
  STATE_DOWN = 'DOWN'
  STATE_RUNNING = 'RUNNING'

  # Broker status
  BROKER_STATUS_BOOTING = 'BOOTING'
  BROKER_STATUS_SHOOTING_DOWN = 'SHOOTING_DOWN'
  BROKER_STATUS_DOWN = 'DOWN'
  BROKER_STATUS_CREATING = 'CREATING'
  BROKER_STATUS_CREATION_ERROR = 'CREATION_ERROR'

  property :action, :default => :stop
  property :state, :default => 'DOWN'
  property :ready, :default => false
  property :enable_omf, :default => true
  property :vm_name, :default => "#{VM_NAME_DEFAULT_PREFIX}_#{Time.now.to_i}"
  property :vm_definition, :default => ''
  property :vm_original_clone, :default => ''
  property :vm_os, :default => VM_OS_DEFAULT
  property :omf_opts, :default => OMF_DEFAULT
  property :label
  property :broker_topic_name
  property :vm_opts, :default => {}
  property :federate, :default => false
  property :domain, :default => ''
  property :mac_address, :default => ''
  property :image_path
  property :imOk, :default => false
  property :force_new, :default => false
  property :monitoring_vm_state, :default => false
  property :threads, :default => []

  hook :before_ready do |resource|
    parent = resource.opts.parent

    # merging properties with parent properties
    resource.property = resource.property.merge(parent.property)

    resource.property.broker_topic = nil
    resource.property.broker_vm_topic = nil
    resource.property.started = false
    resource.property.imOk = false
    resource.property.configure_list_opts = []

    # broker config...
    debug "Subscribing to broker topic: #{resource.property.broker_topic_name}"
    resource.inform(:info, Hashie::Mash.new({:info => "Getting VM resource in broker, this can take a while..."}))
    #    OmfCommon.comm.subscribe(resource.property.broker_topic_name, :parent_address => resource.uid) do |topic|
    OmfCommon.comm.subscribe(resource.property.broker_topic_name) do |topic|
      if topic.error?
        error = "Could not subscribe to broker topic"
        resource.log_inform_error(error)
      else
        resource.property.broker_topic = topic

        debug "Checking if virtual machine '#{resource.property.label}' is available"
        resource.property.broker_topic.create(:vm_inventory, {:label => resource.property.label}) do |msg|
          if msg.error?
            error = "The virtual machine '#{resource.property.label}' is not available on broker"
            resource.log_inform_error(error)
          else
            debug "Virtual machine '#{resource.property.label}' AVAILABLE!"
            resource.inform(:info, Hashie::Mash.new({:info => "Broker VM successfully got!"}))
            resource.property.broker_vm_topic = msg.resource
            Thread.new {
              debug "Waiting 5 seconds before get vm '#{resource.property.label}' opts..."
              sleep 5
              resource.get_vm_opts
            }
          end
        end
      end
    end

    # Send inform message to tell EC that the VM RC are ok and he can send the configure messages
    thread = resource.send_vm_im_ok
    resource.property.threads << thread
  end

  work :send_vm_im_ok do |resource|
    thread = Thread.new {
      debug "Starting VM_IMOK inform send to OMF_EC until a configure message is not received..."
      sending_count = 0
      while resource.property.imOk === false && sending_count < 25
        debug "Sending VM_IMOK message..."
        resource.inform(:VM_IMOK, {:info => "I am Ok"})
        sending_count = sending_count + 1
        sleep 1
      end

      if resource.property.imOk
        debug "Configure received and VM is OK, stopping VM_IMOK messages sending..."
      elsif sending_count >= 25
        error "VM is not ok after 25 seconds, stopping and releasing VM resource"
        resource.release_actions
      end
    }
    thread
  end

  hook :before_release do |res|
    debug "RELEASING RESOURCE: #{res.uid}"
    unless res.property.released
      res.stop_vm
      res.release_actions(from_before_release=true)
    end
  end

  work :release_actions do |res, from_before_release|
    res.property.monitoring_vm_state = false
    res.property.released = true
    released_actions_done = false
    set_broker_info(res, {:status => res.property.state}) do |vm_topic|
      res.property.broker_topic.release(vm_topic, {:delete => true}) do |msg|

        res.release(res.property.vm_topic)
        res.parent.remove_vm_by_uid(res.uid)
        #res.parent.release(res.uid, {:delete => true, :release_childs => true}) unless from_before_release
        res.parent.release(res.uid, {:delete => true}) unless from_before_release

        topics = OmfCommon::Comm::Topic.name2inst
        for name, topic in topics
          mac_regex = Regexp.new(Regexp.quote(res.property.mac_address))
          am_controller_topic_regex = Regexp.new(Regexp.quote(vm_topic.id))
          debug "REGEX: #{mac_regex}, #{am_controller_topic_regex}"
          if topic.id =~ mac_regex or topic.id =~ am_controller_topic_regex
            topic.unsubscribe(topic.id, {:delete => true})
            OmfCommon::Comm::Topic.name2inst.delete(name)
          end
        end
        res.property.threads.each {|thr| thr.exit}
      end
      released_actions_done = true
    end
    until released_actions_done
      debug "Waiting for released_actions_done..."
      sleep 2
    end
  end

  request :state do |res|
    res.send("check_vm_state")
  end

  # Checks if resource is ready to receive configure commands
  configure_all do |res, conf_props, conf_result|
    res.property.imOk = true
    debug "configure_all successfully received!"
    if res.property.started && res.property.broker_vm_topic.nil?
      error "This virtual machine '#{res.property.label}' is not avaiable, so nothing can be configured"
      raise "This virtual machine '#{res.property.label}' is not avaiable, so nothing can be configured"
    end

    if res.property.started
      conf_props.each do |k, v|
        debug "Sending configure_#{k} with value #{v.to_s}"
        conf_result[k] = res.__send__("configure_#{k}", v)
        debug "Result of configure_#{k}: #{conf_result[k].to_s}"
      end
    else
      configure_call = {
          :conf_props => conf_props,
          :conf_result => conf_result
      }
      debug "Resource not started yet, saving configure call: #{configure_call}..."
      res.property.configure_list_opts << configure_call
    end
  end

  # Configure the OMF property of this VM Proxy.
  # These are the parameters to pass to an OMF v6 Resource Controller
  # installed (or to be installed) on the VM associated to this VM Proxy.
  #
  # @yieldparam [Hash] opts a hash with the OMF RC parameters
  #             - server (String) the PubSub sever for this OMF RC to connect to
  #             - user (String) the username to use for that server
  #             - password (String) the password to use for that server
  #             - topic (String) the PubSub topic to subscribe to
  #
  configure :omf_opts do |res, opts|
    if opts.kind_of? Hash
      if res.property.omf_opts.empty?
        res.property.omf_opts = OMF_DEFAULT.merge(opts)
      else
        res.property.omf_opts = res.property.omf_opts.merge(opts)
      end
    else
      res.log_inform_error "OMF option configuration failed! "+
                               "Options not passed as Hash (#{opts.inspect})"
    end
    res.property.omf_opts
  end

  configure :vm_opts do |res, opts|
    if opts.kind_of? Hash
      res.property.vm_opts = {} unless res.property.vm_opts.kind_of? Hash
      # Actually, the user only can set bridges, other params are set by getting broker data
      opts.each do |k, v|
        if k == "bridges"
          res.property.vm_opts[:bridges] = v
        end
      end
    else
      res.log_inform_error "OMF option configuration failed! "+
                               "Options not passed as Hash (#{opts.inspect})"
    end
    res.property.vm_opts
  end

  # Configure the next action to execute for this VM Proxy.
  # Available actions are: build, define, stop, run, delete, attach, clone_from.
  # For details about these actions, refer to the overview description at the
  # start of this file.
  #
  # @yieldparam [String] value the name of the action
  #
  configure :action do |res, value|
    act = value.to_s.downcase
    thread = Thread.new {
      res.send("#{act}_vm")
    }
    res.property.action = value
    res.property.threads << thread
  end

  work :build_vm do |res|
    res.log_inform_warn "Trying to build an already built VM, make sure to "+
                            "have the 'overwrite' property set to true!" if res.property.ready

    vm_state = res.check_vm_state(res)
    vm_is_running = false

    if vm_state != STATE_NOT_CREATED and res.property.force_new
      res.inform(:ALREADY_CREATED, {:message => "VM #{res.property.vm_name} already exist. Forcing its deletion to create a new one."})
      res.send("delete_vm_with_#{res.property.virt_mngt}", res.property.vm_name, res.property.image_path)
      vm_state = STATE_NOT_CREATED
    end

    if vm_state == STATE_NOT_CREATED
      set_broker_info(res, {:status => BROKER_STATUS_CREATING})
      res.property.state = BROKER_STATUS_CREATING
      res.send("build_img_with_#{res.property.img_builder}")
    elsif vm_state == STATE_RUNNING
      res.inform(:ALREADY_CREATED, {:message => "VM #{res.property.vm_name} already exist and it is running"})
      vm_is_running = true
    else
      res.inform(:ALREADY_CREATED, {:message => "VM #{res.property.vm_name} already exist, but it is stopped. Starting it now..."})
      res.run_vm(res)
      vm_is_running = true
    end

    res.property.vm_topic = res.get_vm_node_topic

    # ----Setting up broker vm info ----
    is_created = !(res.property.vm_topic.include? "error:")
    status = is_created ? BROKER_STATUS_BOOTING : BROKER_STATUS_CREATION_ERROR
    res.property.state = STATE_RUNNING
    broker_info = {
        :status => status
    }
    if is_created
      mac_address = res.get_mac_addr(res.property.vm_name)
      broker_info[:mac_address] = mac_address
    end
    set_broker_info(res, broker_info) unless vm_is_running
    # ---- end broker integration ----

    if is_created
      res.start_booting_monitor(res.property.vm_topic) unless vm_is_running
      res.update_vm_state(res) unless res.property.monitoring_vm_state
      res.inform(:VM_TOPIC, Hashie::Mash.new({:vm_topic => "#{res.property.vm_topic}"}))
    else
      res.log_inform_error "Could not build VM: #{mac_address}"
    end
  end

  work :define_vm do |res|
    unless File.exist?(res.property.vm_definition)
      res.log_inform_error "Cannot define VM (name: "+
                               "'#{res.property.vm_name}'): definition path not set "+
                               "or file does not exist (path: '#{res.property.vm_definition}')"
    else
      vm_state = res.check_vm_state(res)

      if vm_state == STATE_DOWN
        res.property.ready = res.send("define_vm_with_#{res.property.virt_mngt}")
        res.inform(:status, Hashie::Mash.new({:status => {:ready => res.property.ready}}))
      else
        res.log_inform_warn "Cannot define VM: it is not stopped"+
                                "(name: '#{res.property.vm_name}' - state: #{res.property.state})"
      end
    end
  end

  work :attach_vm do |res|
    unless !res.property.vm_name.nil? || !res.property.vm_name == ""
      res.log_inform_error "Cannot attach VM, name not set"+
                               "(name: '#{res.property.vm_name})'"
    else
      vm_state = res.check_vm_state(res)

      if vm_state == STATE_DOWN
        res.property.ready = res.send("attach_vm_with_#{res.property.virt_mngt}")
        res.inform(:status, Hashie::Mash.new({:status => {:ready => res.property.ready}}))
      else
        res.log_inform_warn "Cannot attach VM: it is not stopped"+
                                "(name: '#{res.property.vm_name}' - state: #{res.property.state})"
      end
    end
  end

  work :clone_from_vm do |res|
    unless !res.property.vm_name.nil? || !res.property.vm_name == "" ||
        !res.image_directory.nil? || !res.image_directory == ""
      res.log_inform_error "Cannot clone VM: name or directory not set "+
                               "(name: '#{res.property.vm_name}' - dir: '#{res.property.image_directory}')"
    else
      vm_state = res.check_vm_state(res)

      if vm_state == STATE_DOWN
        res.property.ready = res.send("clone_vm_with_#{res.property.virt_mngt}")
        res.inform(:status, Hashie::Mash.new({:status => {:ready => res.property.ready}}))
      else
        res.log_inform_warn "Cannot clone VM: it is not stopped"+
                                "(name: '#{res.property.vm_name}' - state: #{res.property.state})"
      end
    end
  end

  work :stop_vm do |res|
    vm_state = res.check_vm_state(res)
    res.property.monitoring_vm_state = false
    res.property.state = BROKER_STATUS_DOWN

    if vm_state == STATE_RUNNING
      set_broker_info(res, {:status => BROKER_STATUS_SHOOTING_DOWN})
      res.property.state = BROKER_STATUS_SHOOTING_DOWN
      res.send("stop_vm_with_#{res.property.virt_mngt}")
      res.release_actions
    else
      res.inform(:status, Hashie::Mash.new({:vm_return => "VM stopped successfully"}))
      res.log_inform_warn "Cannot stop VM: it is not running "+
                              "(name: '#{res.property.vm_name}' - state: #{res.property.state})"

      res.property.released = true
      set_broker_info(res, {:status => res.property.state}) do |vm_topic|
        res.property.broker_topic.release(vm_topic, {:delete => true}) do |msg|

          res.release(res.property.vm_topic)
          res.parent.remove_vm_by_uid(res.uid)
          #res.parent.release(res.uid, {:delete => true, :release_childs => true}) unless from_before_release
          res.parent.release(res.uid, {:delete => true})

          topics = OmfCommon::Comm::Topic.name2inst
          for name, topic in topics
            am_controller_topic_regex = Regexp.new(Regexp.quote(vm_topic.id))
            debug "REGEX: #{am_controller_topic_regex}"
            if topic.id =~ am_controller_topic_regex
              topic.unsubscribe(topic.id, {:delete => true})
              OmfCommon::Comm::Topic.name2inst.delete(name)
            end
          end
          res.property.threads.each {|thr| thr.exit}
        end
      end
    end
  end


  work :run_vm do |res|
    vm_state = res.check_vm_state(res)

    if vm_state == STATE_DOWN
      set_broker_info(res, {:status => BROKER_STATUS_BOOTING})
      res.property.state = STATE_RUNNING
      res.send("run_vm_with_#{res.property.virt_mngt}")

      # Start boot monitoring
      res.property.vm_topic = res.get_vm_node_topic
      res.start_booting_monitor(res.property.vm_topic)
      res.update_vm_state(res) unless res.property.monitoring_vm_state
    else
      res.log_inform_warn "Cannot run VM: it is not stopped or ready yet "+
                              "(name: '#{res.property.vm_name}' - state: #{res.property.state})"
    end
  end

  work :delete_vm do |res|
    vm_state = res.check_vm_state(res)

    if vm_state == STATE_DOWN
      res.send("delete_vm_with_#{res.property.virt_mngt}", res.property.vm_name, res.property.image_path)
    else
      res.log_inform_warn "Cannot delete VM: it is not stopped or ready yet "+
                              "(name: '#{res.property.vm_name}' - state: #{res.property.state} "+
                              "- ready: #{res.property.ready}"
    end
  end

  work :check_vm_state do |res|
    vm_state = res.send("check_vm_state_with_#{res.property.virt_mngt}")
    if vm_state.include? "Domain not found"
      vm_state = STATE_NOT_CREATED
    elsif vm_state.include? "shut off"
      vm_state = STATE_DOWN
    elsif vm_state.include? "running" or vm_state.include? "idle"
      vm_state = STATE_RUNNING
    end
    res.property.state = vm_state.upcase
    vm_state
  end

  work :get_vm_opts do |resource|
    info "Getting vm (#{resource.property.label}) options from broker..."
    resource.property.broker_vm_topic.request([:ram, :cpu, :disk_image]) do |msg|
      if msg.error?
        resource.inform_error("Could not finish vm setup with broker: #{msg}")
      else
        resource.property.vm_opts = {} unless resource.property.vm_opts.kind_of? Hash
        resource.property.vm_opts[:ram] = msg[:ram]
        resource.property.vm_opts[:cpu] = msg[:cpu]
        resource.property.vm_opts[:disk] = {
            :image => msg[:disk_image]
        }

        debug "VM (#{resource.property.label}) options got: #{resource.property.vm_opts}"
        resource.property.started = true

        # Call each configure called before started
        resource.call_prev_configures
      end
    end
  end

  configure :update_status do |res, opts|
    set_broker_info(res, {:status => res.property.state})
  end

  def self.set_broker_info(resource, broker_info, &block)
    unless resource.property.broker_vm_topic.nil?
      debug "Sending broker VM info: '#{broker_info}'"
      resource.property.broker_vm_topic.configure(broker_info) do |msg|
        if msg.error?
          resource.log_inform_error("Could not set broker info: #{msg}")
        end
        block.call(resource.property.broker_vm_topic) if block
      end
    end
  end

  work :call_prev_configures do |resource|
    prev_configure_len = resource.property.configure_list_opts.size
    if prev_configure_len > 0
      info_msg = "Executing previous '#{prev_configure_len}' configures called..."
      resource.inform(:info, Hashie::Mash.new({:info => info_msg}))
      resource.property.configure_list_opts.each do |obj|
        debug "Calling previous called configure: #{obj}"
        resource.configure_all(obj[:conf_props], obj[:conf_result])
      end
      resource.property.configure_list_opts = []
    end
  end

  work :start_booting_monitor do |resource, vm_topic|
    if resource.property.started
      thread = Thread.new {
        debug "Starting booting monitoring to VM '#{vm_topic}'. Timeout set to #{resource.property.boot_timeout} " +
                  "seconds."

        started = false
#        OmfCommon.comm.subscribe(vm_topic, :parent_address => resource.uid) do |topic|
        OmfCommon.comm.subscribe(vm_topic) do |topic|
          if topic.error?
            error = "Could not subscribe to broker topic"
            resource.log_inform_error(error)
          else
            topic.request([:status]) do |msg|
              started = msg[:status] == "UP_AND_READY"
            end
            topic.on_message do |msg|
              if msg.itype == 'BOOT.INITIALIZED' || msg.itype == 'BOOT.DONE'
                started = true
              end
            end
          end
        end

        sleep resource.property.boot_timeout
        unless started
          resource.inform(:BOOT_TIMEOUT, Hashie::Mash.new({:timeout => resource.property.boot_timeout}))
          begin
            resource.stop_vm
          rescue => e
            error "Could not stop vm"
          end
        end
      }
      resource.property.threads << thread
    end
  end

  work :update_vm_state do |res|
    res.property.monitoring_vm_state = true
    thread = Thread.new {
      while(res.property.monitoring_vm_state) do
        debug "#{res.uid} - update_vm_state: Updating VM state. Thread id: #{Thread.current.object_id}"
        old_state = res.property.state
        state = res.check_vm_state(res)
        debug "OLD state: #{old_state}, NEW STATE: #{state}"
        if state == STATE_DOWN or state == STATE_NOT_CREATED and (old_state != STATE_DOWN and old_state != STATE_NOT_CREATED)
          res.release_actions
        end
        sleep 5
      end
    }
    res.property.threads << thread
  end

  work :get_vm_node_topic do |res|
    res.property.mac_address = res.get_mac_addr(res.property.vm_name)
    vm_topic = res.property.mac_address
    if res.property.federate
      vm_topic = "fed-#{res.property.domain}-#{vm_topic}"
    end
    vm_topic
  end
end

