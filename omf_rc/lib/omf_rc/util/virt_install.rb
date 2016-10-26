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
# This module defines the command specifics to build a VM image using
# the vmbuilder tool
#
# Utility dependencies: common_tools
#
# @see OmfRc::ResourceProxy::VirtualMachine
#
module OmfRc::Util::VirtInstall
  include OmfRc::ResourceProxyDSL

  VIRT_INSTALL_PATH = "/usr/bin/virt-install"

  VM_OPTS_DEFAULT = Hashie::Mash.new({
                                           mem: 512,
                                           rootsize: 20000, overwrite: true,
                                           ip: nil, mask: nil, net: nil, bcast: nil,
                                           gw: nil, dns: nil
                                       })


  property :virt_install_path, :default => VIRT_INSTALL_PATH
  property :vm_opts, :default => VM_OPTS_DEFAULT

  %w(vm_opts ubuntu).each do |prefix|
    prop = "#{prefix}_opts"
    configure(prop) do |res, opts|
      if opts.kind_of? Hash
        if res.property[prop].empty?
          res.property[prop] = res.send("#{prefix}_DEFAULT").merge(opts)
        else
          res.property[prop] = res.property[prop].merge(opts)
        end
      else
        res.log_inform_error "#{prefix} option configuration failed! "+
                                 "Options not passed as Hash (#{opts.inspect})"
      end
      res.property[prop]
    end
  end

  %w(vm_opts ubuntu).each do |prefix|
    prop = "#{prefix}_opts"
    request(prop) do |res, opts|
      if res.property[prop].empty?
        res.property[prop] = res.send("#{prefix}_DEFAULT")
      else
        res.property[prop]
      end
    end
  end

  work :build_img_with_virt_install do |res|
    # Construct the virt-install command
    cmd += res.property.use_sudo ? "sudo " : ""

    cmd += "#{VIRT_INSTALL_PATH} --connect #{res.property.hypervisor}" +
        "-n #{res.property.vm_name} "
        "--graphics none"
        "-v" #for full virtualization
    # Add virt-install options
    res.property.virt_install_opts.each do |k,v|
      if k.to_sym == :overwrite
        cmd += "-o " if v
      else
        cmd += "--#{k.to_s} #{v} " unless v.nil?
      end
    end

    # find the ips
    # for mac in macs.split("\\n") do
    #   puts `arp -e | grep #{mac}`
    # end
    #sudo nmap -sn 10.16.88.0/24


    logger.info "Building VM with: '#{cmd}'"
    result = `#{cmd} 2>&1`
    if $?.exitstatus != 0
      res.log_inform_error "Cannot build VM image: '#{result}'"
      false
    else
      logger.info "VM image built successfully!"
      true
    end
  end

end
