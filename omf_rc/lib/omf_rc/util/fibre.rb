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
require 'erb'

#
# This module defines the command specifics to build a VM image using
# the vmbuilder tool
#
# Utility dependencies: common_tools
#
# @see OmfRc::ResourceProxy::VirtualMachine
#
module OmfRc::Util::Fibre
  include OmfRc::ResourceProxyDSL

  utility :ssh
  utility :libvirt

  VIRSH = "/usr/bin/virsh"
  VIRT_INSTALL_PATH = "/usr/bin/virt-install"

  VM_OPTS_DEFAULT = Hashie::Mash.new(
      {
          mem: 512,
          rootsize: 20000, overwrite: true,
          ip: nil, mask: nil, net: nil, bcast: nil,
          gw: nil, dns: nil
      }
  )

  property :virt_install_path, :default => VIRT_INSTALL_PATH
  property :vm_opts, :default => VM_OPTS_DEFAULT
  property :image_template_path, :default => "/root/images_templates"
  property :image_final_path, :default => "/var/lib/libvirt/images"

  work :build_img_with_fibre do |res|
    params = {}
    params[:vm_name]= res.property.vm_name

    # Add virt-install options
    res.property.vm_opts.each do |k, v|
      if k == "bridges"
        params[:bridges] = v
        # v.each do |bridge_name|
        #   params[:bridges].push(bridge_name)
        # end
      elsif k == "disk"
        image_name = "#{res.property.image_final_path}/#{v.image}_#{res.property.vm_name}_#{Time.now.to_i}.img"
        res.property.image_name = image_name
        params[:disk] = image_name
        res.create_template_copy(v.image, image_name)
      else
        params[k.to_sym] = v
      end
    end
    template_path = File.join(File.dirname(File.expand_path(__FILE__)), "vm_template.erb")
    template = File.read(template_path)

    renderer = ERB.new(template, 0, "%<>")
    domain_xml = renderer.result(binding)

    logger.info domain_xml

    domain_file = File.join(File.dirname(File.expand_path(__FILE__)), "domain_#{res.property.vm_name}_#{Time.now.to_i}.erb")
    File.write(domain_file, domain_xml)

    res.property.vm_definition = domain_file

    logger.info "Building VM with: libvirt"

    res.define_vm_with_libvirt
    start_result = res.run_vm_with_libvirt

    File.delete(domain_file)
    result = start_result

    if start_result.include? "error:"
      res.log_inform_error "Error in VM #{params[:vm_name]} creation"
    else
      logger.info "VM image built successfully!"
      vm_topic = res.get_mac_addr(res.property.vm_name)
      logger.info "The topic to access the VM is: #{vm_topic}"
      result = vm_topic
    end

    result
  end

  work :delete_vm_with_fibre do |res|
    result = res.delete_vm_with_libvirt
    res.remove_image(res.property.image_name)
  end

  work :create_template_copy do |res, template_image, image_name|
    template_img_fullname = "#{res.property.image_template_path}/#{template_image}"
    user = res.property.ssh_params.user
    ip_address = res.property.ssh_params.ip_address
    port = res.property.ssh_params.port
    key_file = res.property.ssh_params.key_file

    logger.info "Creating VM image..."

    logger.info "Checking if image exists..."
    cmd = "ssh -l #{user} #{ip_address} -p #{port} -i #{key_file} [ -f #{template_img_fullname} ] && echo 'found' || echo 'not found'"
    file_exists = `#{cmd}`
    if file_exists.include? "not found"
      res.inform_error("The template image '#{template_img_fullname}' does not exists.")
    else
      #Start image copying
      Thread.new {
        cmd = "cp #{template_img_fullname} #{image_name}"
        res.ssh_command(user, ip_address, port, key_file, cmd)
      }

      #Get the size of the template image to calc the copy progress
      cmd = "ssh -l #{user} #{ip_address} -p #{port} -i #{key_file} du #{template_img_fullname}"

      template_size = `#{cmd}`
      template_size = template_size.split(" ")[0].to_i

      progress = 0

      #Calculate and inform the copy progress
      while progress != 100.0 do
        sleep 5
        cmd = "ssh -l #{user} #{ip_address} -p #{port} -i #{key_file} du #{image_name}"
        copy_size = `#{cmd}`
        copy_size = copy_size.split(" ")[0].to_i
        progress = (copy_size.to_f/template_size).round(2) * 100
        res.inform(:CREATION_PROGRESS, {progress: "#{"%.0f" % progress}%"})
      end

      progress.to_s
    end
  end

  work :remove_image do |res, image_name|
    user = res.property.ssh_params.user
    ip_address = res.property.ssh_params.ip_address
    port = res.property.ssh_params.port
    key_file = res.property.ssh_params.key_file

    logger.info "Removing VM image..."

    cmd = "rm -f #{image_name}"
    result = res.ssh_command(user, ip_address, port, key_file, cmd)
    result
  end

  work :get_mac_addr do |res, vm_name|
    cmd = "virsh -c #{res.property.hypervisor_uri} dumpxml #{vm_name} | grep 'mac address' | cut -d\\' -f2"

    output = res.execute_cmd(cmd, "Getting mac address...",
                             "Cannot get the mac address!", "Mac address was successfully got!")
    output = output.split("\n")
    output[0]
  end

end
