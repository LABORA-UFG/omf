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
      @params = {}
      @flows = {}

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
      info "Configuring params"
      @params.each do |key, value|
        info "#{key}, #{value}"
        __send_message(key, value, :configure)
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
        @params[name] = *args
      else
        operation = :request
      end

      if self.has_topic
        __send_message(name, *args, operation, &block)
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
    def __send_message(name, value = nil, operation = :request, &block)
      topic = self.topic
      case operation
        when :configure
          topic.configure({ name => value }, {assert: OmfEc.experiment.assertion }) do |msg|
            error "Could not configure '#{name}' at this time." unless msg.success?
            info msg[name]
            block.call(msg[name]) if block
          end
        when :request
          topic.request([name], {assert: OmfEc.experiment.assertion }) do |msg|
            error "Could not get '#{name}' at this time." unless msg.success?
            block.call(msg[name]) if block
          end
        else
          info "Operation not informed."
          # type code here
        end
    end

    # To be create a flow in switch, first we need create it and after add the match and actions of flow.
    # @param [String] name to identify the flow on the switch
    # @param [Object] block
    def addFlow(name, flow)
      if __switch_flow(name)
        raise("Already exists a flow with name '#{name}'")
      else
        @flows[name] = flow
      end
    end

    # Install all flows in switch
    def installFlows(&block)
      if @flows.values.empty?
        error 'There are no flows to be installed, add at least one flow before using this function.'
      else
        self.__add_flows(@flows.values, &block)
      end
    end

    # Install a flow in switch
    def installFlow(name, &block)
      info "Install flow #{name}"
      flow = __switch_flow(name)
      if flow
        self.__add_flows([flow], &block)
      else
        error "The flow with name '#{name}' not exist."
      end
    end

    # Removes all flows from switch
    def delFlows(&block)
      if @flows.values.empty?
        error 'There are no flows to be removed, add at least one flow before using this function.'
      else
        self.__del_flows(@flows.values.map{|f| __get_only_flow_match(f)}) do
          @flows = {}
          block.call if block
        end
      end
    end

    # Removes a flow from switch
    # @param [String] name of flow to be removed
    def delFlow(name, &block)
      flow = __switch_flow_match(name)
      if flow
        self.__del_flows([flow]) do
          @flows.delete(name)
          block.call if block
        end
      else
        error "The flow with name '#{name}' not exist."
      end
    end

    # Get all flows installed in switch.
    #
    # @return [Array] with all flows installed in switch
    #
    # @example
    #   # Get all flows installed in ovs switch
    #   switch('ovs').getFlows do |flows|
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

    # Adding flows in switch
    #
    # @param [Array] flows to be added
    #
    # @example
    #   # Adding flows in a ovs switch
    #   switch('ovs').addFlows(["in_port=1,action=output:2", "in_port=2,action=output:1"])
    #
    def __add_flows(flows, &block)
      raise('This function need to be executed after ALL_SWITCHES_UP event') unless self.has_topic
      @topic.configure(add_flows: flows) do |msg|
        if msg.success?
          block.call if block
        else
          info "Could not add flows: #{msg[:add_flows]}"
        end
      end
    end

    # Removing the flows installed in switch. It is only necessary the "match" part of a flow to identify it.
    #
    # @param [Array] flows to be removed
    #
    # @example
    #   # Removing flows of a ovs switch
    #   switch('ovs').delFlows(["in_port=1", "in_port=2"])
    #
    def __del_flows(flows, &block)
      raise('This function need to be executed after ALL_SWITCHES_UP event') unless self.has_topic
      @topic.configure(del_flows: flows) do |msg|
        if msg.success?
          info "Flows removed with success: #{msg[:del_flows]}"
          block.call if block
        else
          info "Could not remove flows: #{msg[:del_flows]}"
        end
      end
    end

    # Select the specific flow by name
    def __switch_flow(name)
      @flows[name]
    end

    def __switch_flow_match(name)
      flow = __switch_flow(name)
      __get_only_flow_match(flow)
    end

    def __get_only_flow_match(flow)
      flow.split(',action')[0] if flow.include? ',action'
    end

  end
end
