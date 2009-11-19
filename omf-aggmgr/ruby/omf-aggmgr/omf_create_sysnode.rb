#!/usr/bin/ruby
#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 - WINLAB, Rutgers University, USA
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

require "omf-common/omfPubSubService"

if ARGV.length != 2
  puts "Usage: #{$0} <IP address of XMPP server> <IP address of node to add>"
  exit 0
end

begin
  @@service = OmfPubSubService.new("aggmgr", "123", ARGV[0])
rescue Exception => ex
  puts "ERROR Creating ServiceHelper - '#{ex}'"
end

puts "Connected to PubSub Server: '#{ARGV[0]}'"
    
@@service.create_pubsub_node("/Domain")
@@service.create_pubsub_node("/Domain/System")
@@service.create_pubsub_node("/Domain/System/#{ARGV[1]}")