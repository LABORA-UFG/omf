# Copyright (c) 2016 Computer Networks and Distributed Systems LABORAtory (LABORA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'hashie'
require 'cocaine'

# Utility for executing 'ssh' commands
module OmfRc::Util::Ssh
  include OmfRc::ResourceProxyDSL

  include Cocaine
  include Hashie


  # Executes some remote command using ssh
  #
  # @return [String] ssh command output
  # @!macro work
  work :ssh_command do |res, user, ip_addr, port, key_file, command|
    c=CommandLine.new("ssh", "-l :user :ip_addr -p :port -i :key_file :command")
    c.run( {
                    :user => user,
                    :ip_addr => ip_addr,
                    :port => port,
                    :key_file => key_file,
                    :command => command})
  end
  # @!endgroup
end
