# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc::Switch

  class SwitchDescription
    include MonitorMixin

    attr_accessor :id, :name, :params, :topic_name, :flows
    attr_reader :topic

    # @param [String] name name of the group
    # @param [String] topic_name name of the topic
    def initialize(name, topic_name, &block)
      super()
      self.name = name
      self.topic_name = topic_name
      self.id = "#{OmfEc.experiment.id}.#{self.name}"
      self.params = {}
      self.flows = {}

      OmfEc.subscribe_topic(topic_name, self, &block)
    end

    # Associate the topic reference when the subscription is received from OmfEc::subscribe_topic
    # @param [Object] topic
    def associate_topic(topic)
      self.synchronize do
        @topic = topic
      end
    end

    # Verify if has a topic associated with this class.
    def has_topic
      !@topic.nil?
    end

    # Configure the parameters defined in defSwitch.
    #
    # @example
    #   # Creating a switch with controller.
    #   defSwitch('ovs', 'vm-fibre-ovs') do |ovs|
    #     ovs.controller = ["tcp:192.168.0.100:6633"]
    #   end
    def configure_params
      self.params.each do |key, value|
        send_message(key, value, :configure)
      end
    end

    # Adding flows in switch
    #
    # @param [Array] flows to be added
    #
    # @example
    #   # Adding flows in a ovs switch
    #   switch('ovs').addFlows(["in_port=1,action=output:2", "in_port=2,action=output:1"])
    #
    def add_flows(flows)
      raise('This function need to be executed after ALL_SWITCHES_UP event') unless self.has_topic
      @topic.configure(add_flows: flows) do |msg|
        if msg.success?
          info "Flows added with success: #{msg[:add_flows]}"
        else
          info "Could not add flows: #{msg[:add_flows]}"
        end
      end
    end

    # Get all flows installed in switch.
    #
    # @return [Object] all flows installed in switch
    #
    # @example
    #   # Get all flows installed in ovs switch
    #   switch('ovs').dumpFlows.each do |flow|
    #     info "Openflow Flow: #{flow}"
    #   end
    #
    def getFlows(&block)
      raise('This function need to be executed after ALL_SWITCHES_UP event.') unless self.has_topic
      @topic.request([:dump_flows]) do |msg|
        error 'Could not get openflow flows at this time.' unless msg.success?
        block.call(msg[:dump_flows]) if block
        raise('To get the OpenFlow flows insert the block in code to receive the data.') unless block
      end
    end

    # Calling standard methods or assignments will simply trigger sending a FRCP message
    #
    # @example OEDL
    #   # Will send FRCP CONFIGURE message
    #   ovs.controller = ["tcp:192.168.0.100:6633"]
    #
    #   # Will send FRCP REQUEST message
    #   ovs.controller
    #
    def method_missing(name, *args, &block)
      if name =~ /(.+)=/
        operation = :configure
        name = $1
        self.params[name] = *args
      else
        operation = :request
      end

      if self.has_topic
        send_message(name, *args, operation, &block)
      elsif operation == :request
        error "Operation :request of #{name} is not allowed in this moment."
        return nil
      end
    end

    # Send FRCP message
    #
    # @param [String] name of the property
    # @param [Object] value of the property, for configuring
    # @param [Object] operation to be send, :configure or :request
    def send_message(name, value = nil, operation = :request, &block)
      topic = self.topic
      case operation
        when :configure
          topic.configure({ name => value }, {assert: OmfEc.experiment.assertion })
        when :request
          topic.request([name], {assert: OmfEc.experiment.assertion }) do |msg|
            error "Could not get #{name} at this time." unless msg.success?
            block.call(msg[name]) if block
          end
        else
          info "Operation not informed."
          # type code here
        end
    end

    def addFlow(name)
      flow = Omf::Switch::Flow.new(name)
      self.flows << flow
      flow
    end

    def installFlows
      flows_s = self.flows.map {|flow| flow.flow_s}
      self.addFlows(flows_s)
    end

    def delFlows()
      flows_s = self.flows.map {|flow| flow.match_s}
      self.del_flows(flows_s)
    end

    def delFlow(name)
      flow = get_flow_by_name(name)
      # error ""
      self.del_flows(Array.new(flow.match_s)) if flow
    end

    # Removing the flows installed in switch. It is only necessary the "match" part of a flow to identify it.
    #
    # @param [Array] flows to be removed
    #
    # @example
    #   # Removing flows of a ovs switch
    #   switch('ovs').delFlows(["in_port=1", "in_port=2"])
    #
    def del_flows(flows)
      raise('This function need to be executed after ALL_SWITCHES_UP event') unless self.has_topic
      @topic.configure(del_flows: flows) do |msg|
        if msg.success?
          info "Flows removed with success: #{msg[:del_flows]}"
        else
          info "Could not remove flows: #{msg[:del_flows]}"
        end
      end
    end

    def get_flow_by_name(name)
      self.flows.each do |flow|
        return flow if flow.name == name
      end
    end

  end
end
