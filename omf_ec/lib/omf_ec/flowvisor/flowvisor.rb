# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc::FlowVisor

  class FlowVisor
    include MonitorMixin

    attr_accessor :id, :name, :topic_name
    attr_reader :topic, :slices

    # @param [String] name name of virtual machine
    def initialize(name, topic_name, &block)
      super()
      self.id = "#{OmfEc.experiment.id}.#{self.name}"
      self.name = name
      self.topic_name = topic_name

      OmfEc.subscribe_topic(topic_name, self, &block)
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
      end
    end

    def addSlice(name)

    end

    def createAllSlices

    end

    def create(name, &block)
      raise('This function need to be executed after ALL_FLOWVISOR_UP event') unless @topic

      slice = slice(name)
      raise("Slice '#{name}' object is not defined") unless slice

      raise("Slice '#{name}' already created") unless slice.has_topic

      @topic.create(:flowvisor_proxy, {name: slice.name, controller_url: slice.controller}) do |msg|
        if msg.success?
          slice_topic = msg.resource
          slice_topic.on_subscribed do
            info ">>> Connected to newly created slice #{msg[:res_id]} with name #{msg[:name]}"
            slice.associate_topic(slice_topic)
            block.call if block
          end
        else
          error ">>> Slice creation failed - #{msg[:reason]}"
        end
      end

    end

    def release(name)

    end

    def slice(name)
      self.slices.find {|s| s.name == name}
    end

  end
end
