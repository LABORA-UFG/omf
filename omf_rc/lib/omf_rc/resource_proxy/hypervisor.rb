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
# Utility dependencies: common_tools
#
# This VM Factory Proxy is the resource entity that can create VM Proxies.
# @see OmfRc::ResourceProxy::VirtualMachine
#
module OmfRc::ResourceProxy::Hypervisor
  include OmfRc::ResourceProxyDSL

  register_proxy :hypervisor
  utility :common_tools
  utility :libvirt

  # Default VirtualMachine to use
  HYPERVISOR_DEFAULT = :kvm
  # Default URI for the default VirtualMachine
  HYPERVISOR_URI_DEFAULT = 'qemu:///system'
  # Default virtualisation management tool to use
  VIRTUAL_MNGT_DEFAULT = :libvirt
  # Default VM image building tool to use
  IMAGE_BUILDER_DEFAULT = :virt_install
  # Default directory to store the VM's disk image
  VM_DIR_DEFAULT = "/home/thierry/experiments/omf6-dev/images"

  property :use_sudo, :default => true
  property :hypervisor, :default => HYPERVISOR_DEFAULT
  property :hypervisor_uri, :default => HYPERVISOR_URI_DEFAULT
  property :virt_mngt, :default => VIRTUAL_MNGT_DEFAULT
  property :img_builder, :default => IMAGE_BUILDER_DEFAULT
  property :enable_omf, :default => true
  property :image_directory, :default => VM_DIR_DEFAULT
  property :image_template_path, :default => "/root/images_templates"
  property :image_path, :default => VM_DIR_DEFAULT
  property :broker_topic_name, :default => "am_controller"
  property :boot_timeout, :default => 150
  property :federate, :default => false
  property :domain, :default => ''

  # Properties to run ssh command
  property :ssh_params, :default => {
      ip_address: "127.0.0.1",
      port: 22,
      user: "root",
      key_file: "/root/.ssh/id_rsa"
  }

  hook :before_ready do |resource|
    resource.property.vms_path ||= "/var/lib/libvirt/images/"
    resource.property.vm_list ||= []
  end

  hook :before_create do |res, type, opts = nil|
    if type.to_sym == :virtual_machine
      raise 'You need to inform the virtual machine label' if opts[:label].nil?
      opts[:broker_topic_name] = res.property.broker_topic_name
      opts[:vm_name] = opts[:label]
      opts[:uid] =  opts[:label]
      opts[:image_directory] = res.property.image_directory
      opts[:image_template_path] = res.property.image_template_path
      opts[:image_path] = "#{opts[:image_directory]}/#{opts[:label]}.img"
      opts[:boot_timeout] = res.property.boot_timeout
      opts[:federate] = res.property.federate
      opts[:domain] = res.property.domain
      opts[:ssh_params] = res.property.ssh_params
      res.destroy_old_vm(opts[:vm_name], opts[:image_path]) if opts[:force_new]
    else
      raise "This resource only creates VM! (Cannot create a resource: #{type})"
    end
  end

  hook :after_create do |res, child_res|
    existing_vm = res.find_vm_by_uid(child_res.uid)
    if existing_vm
      child_res.property.imOk = false
      Thread.new {
        debug "Starting VM_IMOK inform send to OMF_EC until a configure message is not received..."
        until child_res.property.imOk
          debug "Sending VM_IMOK message..."
          sleep 1
          child_res.inform(:VM_IMOK, {:info => "I am Ok"})
        end
        debug "Configure received, stopping VM_IMOK messages sending..."
      }
    else
      logger.info "Created new child VM: #{child_res.uid}"
      res.property.vm_list << child_res.uid
    end
  end

  work :destroy_old_vm do |res, vm_name, image_path|
    res.send("delete_vm_with_#{res.property.virt_mngt}", vm_name, image_path)
  end

  # Return a hash describing a reference to this object
  #
  # @return [Hash]
  def to_hash
    hash = super.to_hash
    hash[:label] = @property.label if @property.label
    hash
  end

  # Request child resources
  #
  # @return [Hashie::Mash] child resource mash with uid and hrn
  def request_child_resources(*args)
    children.map { |c|
      if c.property.state == OmfRc::ResourceProxy::RESOURCE_PROXY_INITIALIZED
        c.check_vm_state(c) if c.respond_to?(:check_vm_state)
      end
      if c.property.key?(:label)
        {c.property.label => c.check_vm_state(c)} if c.respond_to?(:check_vm_state)
      else
        c.property.state
      end
    }
  end

  work :find_vm_by_uid do |res, uid|
    vm = res.property.vm_list.find { |vm_uid| vm_uid.to_s == uid.to_s }
    vm
  end


end
