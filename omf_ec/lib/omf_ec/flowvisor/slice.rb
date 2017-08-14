# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc::FlowVisor

  class Slice

    attr_accessor :id, :controller
    attr_reader :name, :topic, :flows

    # @param [String] name of slice
    def initialize(name)
      super()
      @name = name
      @flows = []
      self.id = "#{OmfEc.experiment.id}.#{@name}"
    end

    # Verify if has a virtual machine topic associated with this class.
    def has_topic
      !@topic.nil?
    end

    # Associate the topic reference when the subscription is received from OmfEc::FlowVisor::FlowVisor::create
    # @param [Topic] topic
    def associate_topic(topic)
      self.synchronize do
        @topic = topic
        self.__log_messages
      end
    end

    def __log_messages
      raise('This function need to be executed after the slice creation') unless has_topic

      @topic.on_message do |msg|
        info("Messages::Slice::'#{@name}': #{msg[:reason]}")
      end
    end

    def has_flows
      @flows.length > 0
    end

    def addFlow(name, &block)
      flow = OmfEc.FlowVisor.Flow.new(name)
      if flow(name)
        error("The flow '#{name}' already added.")
      else
        @flows << flow
        block ? block.call(flow) : flow
      end
    end

    def installFlows(&block)
      raise('This function need to be executed after the slice creation') unless has_topic

      if has_flows
        list_flows = []
        @flows.each do |flow|
          list_flows << {operation: flow.operation, device: flow.device, match: flow.match, name: flow.name}
        end
        self.__create_flows(list_flows, &block)
      else
        warn("The are no flows added in slice '#{@name}'")
      end
    end

    def create(name, &block)
      raise('This function need to be executed after the slice creation') unless has_topic

      flow = flow(name)
      flow ? self.__create_flows(Array.new(flow), &block) : error("The flow '#{name}' not exists.")
    end

    def __create_flows(list_flows, &block)
      raise('This function need to be executed after the slice creation') unless has_topic

      @topic.configure(flows: list_flows) do |reply_msg|
        info("Flow of slice #{@name} configured:")
        reply_msg[:flows].each do |flow|
          info("Added flow: #{flow}")
        end
        block.call if block
      end
    end

    def flow(name)
      self.flows.find {|f| f.name == name}
    end

  end

end
