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
    def initialize(name, &block)
      super()
      @name = name
      @flows = []
      self.id = "#{OmfEc.experiment.id}.#{@name}"
    end

    # Verify if has a virtual machine topic associated with this class.
    def has_topic
      !@topic.nil?
    end

    # Associate the topic reference when the subscription is received from OmfEc::subscribe_topic
    # @param [Object] topic
    def associate_topic(topic)
      self.synchronize do
        @topic = topic
        self._log_messages
      end
    end

    def _log_messages
      raise('This function need to be executed after the slice creation') unless has_topic
      @topic.on_message do |msg|
        error "Messages::Slice::'#{@name}': #{msg[:reason]}"
      end
    end

    def has_flows
      @flows.length > 0
    end

    def addFlow(name, &block)
      flow = OmfEc.FlowVisor.Flow.new(name)
      @flows << flow
      block.call(flow) if block
    end

    def installFlows(&block)
      raise('This function need to be executed after the slice creation') unless has_topic
      unless has_flows
        error("The are no flows added in slice '#{@name}'")
        return
      end

      list_flows = []
      @flows.each do |flow|
        list_flows << {operation: flow.operation, device: flow.device, match: flow.match, name: flow.name}
      end

      @topic.configure(flows: list_flows) do |reply_msg|
        info "Flow of slice #{@name} configured:"
        reply_msg[:flows].each do |flow|
          info " Added flow: #{flow}"
        end
        block.call if block
      end
    end

  end

end
