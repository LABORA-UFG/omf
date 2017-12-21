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
module OmfRc::ResourceProxy::Hipervisor
  include OmfRc::ResourceProxyDSL 

  register_proxy :hypervisor
  utility :common_tools

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
  property :image_path, :default => VM_DIR_DEFAULT
  property :broker_topic_name, :default => "am_controller"
  property :boot_timeout, :default => 150

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
      opts[:image_directory] = res.property.image_directory
      opts[:image_path] = "#{opts[:image_directory]}/#{opts[:label]}"
      opts[:boot_timeout] = res.property.boot_timeout
    else
      raise "This resource only creates VM! (Cannot create a resource: #{type})"
    end
  end

  hook :after_create do |res, child_res|
    logger.info "Created new child VM: #{child_res.uid}"
    res.property.vm_list << child_res.uid
  end
end
