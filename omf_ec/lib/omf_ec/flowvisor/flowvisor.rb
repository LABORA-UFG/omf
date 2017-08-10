# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc::FlowVisor

  class FlowVisor
    include MonitorMixin

    attr_accessor :id
    attr_reader :name, :topic_name, :topic, :slices

    # @param [String] name of flowvisor
    def initialize(name, topic_name, &block)
      super()

      @name = name
      @topic_name = topic_name
      @slices = {}
      self.id = "#{OmfEc.experiment.id}.#{@name}"

      OmfEc.subscribe_topic(@topic_name, self, &block)
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

    def addSlice(name, &block)
      raise("The slice '#{name}' already created") unless slice(name)

      slice = OmfEc.FlowVisor.Slice.new(name)
      @slices[slice.name] = slice
      OmfEc.experiment.add_slice(slice)
      block ? block.call(slice) : slice
    end

    def createAllSlices
      raise('This function need to be executed after ALL_FLOWVISOR_UP event') unless has_topic

      @slices.each_value do |slice|
        create(slice.name)
      end
    end

    def create(name, &block)
      raise('This function need to be executed after ALL_FLOWVISOR_UP event') unless has_topic

      slice = slice(name)
      raise("The slice '#{name}' is not defined") unless slice

      if slice.has_topic
        warn("The slice '#{name}' already created")
        block.call if block
        return
      end

      @topic.create(:flowvisor_proxy, {name: slice.name, controller_url: slice.controller}) do |msg|
        if msg.success?
          slice_topic = msg.resource
          slice_topic.on_subscribed do
            info ">>> Connected to newly created slice #{msg[:res_id]} with name #{msg[:name]}"
            slice.associate_topic(slice_topic)
            block.call if block
          end
        else
          error "The creation of slice '#{self.name}' failed - #{msg[:reason]}"
        end
      end
    end

    def releaseAllSlices
      raise('This function need to be executed after ALL_FLOWVISOR_UP event') unless has_topic

      @slices.each_value do |slice|
        release(slice.name)
      end
    end

    def release(name, &block)
      raise('This function need to be executed after ALL_FLOWVISOR_UP event') unless has_topic

      slice = slice(name)
      raise("The slice '#{name}' is not defined") unless slice

      if slice.has_topic
        @topic.release(slice.topic) do |msg|
          info "Released slice #{msg[:res_id]}"
          @slices.delete(slice.name)
          block.call if block
        end
      else
        warn "The slice '#{slice.name}' need to be created first"
      end
    end

    def slice(name)
      @slices[name]
    end

  end
end
