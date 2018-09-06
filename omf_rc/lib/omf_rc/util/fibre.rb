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
require 'nokogiri'

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
  property :image_directory, :default => "/var/lib/libvirt/images"

  work :build_img_with_fibre do |res|
    params = {}
    params[:vm_name]= res.property.vm_name

    res.list_vms_using_ssh()

    # Add virt-install options
    res.property.vm_opts.each do |k, v|
      if k == "bridges"
        params[:bridges] = v
      elsif k == "disk"
        image_name = "#{res.property.image_directory}/#{res.property.vm_name}.img"
        res.property.image_name = image_name
        params[:disk] = image_name
        res.create_template_copy(v.image, image_name)
      else
        params[k.to_sym] = v
      end
    end

    vm_template_name = res.list_vms_using_ssh
    xml_template = res.get_template_example(vm_template_name)
    domain_xml = res.create_xml_template(xml_template, params)

    logger.info domain_xml

    domain_file = File.join(File.dirname(File.expand_path(__FILE__)), "domain_#{res.property.vm_name}.xml")
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

  work :list_vms_using_ssh do |res|
    user = res.property.ssh_params.user
    ip_address = res.property.ssh_params.ip_address
    port = res.property.ssh_params.port
    key_file = res.property.ssh_params.key_file

    cmd = "virsh list --all"

    vms_list = res.ssh_command(user, ip_address, port, key_file, cmd)
    vm_info = vms_list.split("\n")[3]
    vm_name = vm_info.split(" ")[0]
    debug "Selected VM = #{vm_name}"
    vm_name
  end

  work :get_template_example do |res, vm_name|
    cmd = "virsh -c #{res.property.hypervisor_uri} dumpxml #{vm_name}"
    output = res.execute_cmd(cmd, "Getting a VM template example",
                             "Cannot find a VM temlate example!", "VM temlate example was successfully got!")
    start_reading = false
    xml_text = ""
    output.each_line do |li|
      # Idenfity the XML part of the virsh dumpxml return
      start_reading = true if (li[/^<domain/]) and not start_reading
      xml_text += li if start_reading
    end
    doc = Nokogiri::XML(xml_text)
    doc
  end

  work :create_xml_template do |res, doc, params|
    doc.root.remove_attribute('id')

    xml_os = doc.at('os')
    xml_os.remove
    xml_os = Nokogiri::XML::Node.new("os", doc)
    xml_type = Nokogiri::XML::Node.new("type", doc)
    xml_type.content = 'linux'

    xml_os << xml_type
    doc.root << xml_os

    xml_name = doc.at("name")
    xml_name.content = params[:vm_name]

    xml_uuid = doc.at("uuid")
    xml_uuid.remove

    xml_memory = doc.at('memory')
    xml_memory['unit'] = "MiB"
    xml_memory.content = params[:ram]

    xml_current_memory = doc.at('currentMemory')
    xml_current_memory['unit'] = "MiB"
    xml_current_memory.content = params[:ram]

    xml_vcpu = doc.at('vcpu')

    xml_vcpu.remove
    xml_vcpu = Nokogiri::XML::Node.new("vcpu", doc)
    xml_vcpu.content = params[:cpu]

    doc.root << xml_vcpu

    num_disks = 0
    doc.search('//disk').each_with_index do |disk, index|
      device_type = disk['device']
      if device_type == 'disk'
        source = disk.at('source')
        source['file'] = params[:disk]
        target = disk.at('target')
        target['dev'] = "hda"
        target['bus'] = "ide"
        disk.remove if num_disks != 0
        num_disks += 1
      else
        disk.remove
      end
    end

    doc.search('//interface').each do |disk|
      disk.remove
    end

    doc.search('//input').each do |disk|
      disk.remove
    end

    xml_devices = doc.at('devices')

    console = xml_devices.at('console')
    console.remove

    params[:bridges].each {|bridge|
      xml_interface = Nokogiri::XML::Node.new("interface", doc)
      xml_interface['type'] = 'bridge'
      xml_source = Nokogiri::XML::Node.new("source", doc)
      xml_source['bridge'] = bridge

      xml_interface << xml_source
      xml_devices << xml_interface
    }

    doc
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
