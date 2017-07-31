# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfEc::Switch

  class AbsFlow
    def attrs
      instance_variables.map{|ivar| ivar}
    end

    def has_flow
      to_s.size > 0
    end

    def to_s
      attrs.map{|ivar| "#{ivar.to_s.delete('@')}=#{instance_variable_get ivar}"}.join(',')
    end
  end

  # Class to create a match of OpenFlow
  #
  # @param in_port	Input switch port (int)	{"in_port": 7}
  # @param dl_src	Ethernet source address (string)	{"dl_src": "aa:bb:cc:11:22:33"}
  # @param dl_dst	Ethernet destination address (string)	{"dl_dst": "aa:bb:cc:11:22:33"}
  # @param dl_vlan	Input VLAN id (int)	{"dl_vlan": 5}
  # @param dl_vlan_pcp	Input VLAN priority (int)	{"dl_vlan_pcp": 3, "dl_vlan": 3}
  # @param dl_type	Ethernet frame type (int)	{"dl_type": 123}
  # @param nw_tos	IP ToS (int)	{"nw_tos": 16, "dl_type": 2048}
  # @param nw_proto	IP protocol or lower 8 bits of ARP opcode (int)	{"nw_proto": 5, "dl_type": 2048}
  # @param nw_src	IPv4 source address (string)	{"nw_src": "192.168.0.1", "dl_type": 2048}
  # @param nw_dst	IPv4 destination address (string)	{"nw_dst": "192.168.0.1/24", "dl_type": 2048}
  # @param tp_src	TCP/UDP source port (int)	{"tp_src": 1, "nw_proto": 6, "dl_type": 2048}
  # @param tp_dst	TCP/UDP destination port (int)	{"tp_dst": 2, "nw_proto": 6, "dl_type": 2048}
  class MatchFlow < AbsFlow
    attr_accessor :dl_dst, :dl_src, :dl_type, :dl_vlan, :dl_vlan_pcp, :in_port, :nw_dst, :nw_proto, :nw_src, :tp_dst, :tp_src, :nw_tos
  end

  class ActionFlow < AbsFlow
    attr_accessor :output, :drop
  end

  class SwitchFlow

    attr_accessor :id, :name, :match, :action

    def initialize(name, &block)
      validate_parameters!(name)

      @name = name
      @match = MatchFlow.new
      @action = ActionFlow.new
    end

    def validate_parameters!(*p)
      name = *p
      raise "Name of flow is required" if name.nil?
    end

    # Get flow contain the match and action
    #
    # @return [String] flow
    def flow_s
      flow = Array.to_s
      flow << @match.to_s if @match.has_flow
      flow << @action.to_s if @action.has_flow
      flow.join(',')
    end

    def match_s
      @match.to_s if @match.has_flow
    end

  end

end