# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc::Switch

  class SwitchDescription
    include MonitorMixin

    attr_accessor :id, :name, :params, :topic_name
    attr_reader :topic

    # @param [String] name name of the group
    # @param [Hash] opts
    def initialize(name, topic_name, &block)
      super()
      self.name = name
      self.topic_name = topic_name
      self.id = "#{OmfEc.experiment.id}.#{self.name}"
      self.params = {}

      OmfEc.subscribe(topic_name, self, &block)
    end

    def associate_topic(topic)
      self.synchronize do
        @topic = topic
      end
    end

    def has_topic
      !@topic.nil?
    end

    def configure
      self.params.each do |key, value|
        send_message(key, value, :configure)
      end
    end

    #add_flows: ["in_port=1,action=output:2", "in_port=2,action=output:1"]
    def addFlows(flows)
      raise("This functions need to be executed after ALL_UP event") unless self.has_topic
      @topic.configure(add_flows: flows) do | msg |
        if msg.success?
          info msg[:add_flows]
        else
          info "Could not add flows: #{msg[:add_flows]}"
        end
      end
    end

    def delFlows(flows)
      raise("This functions need to be executed after ALL_UP event") unless self.has_topic
      @topic.configure(del_flows: flows) do | msg |
        if msg.success?
          info msg[:del_flows]
        else
          info "Could not remove flows: #{msg[:del_flows]}"
        end
      end
    end

    def dumpFlows(flows)
      raise("This functions need to be executed after ALL_UP event") unless self.has_topic
      @topic.request([:dump_flows]) do |msg|
        unless msg.success?
          error "Could not get openflow flows at this time"
        end

        msg[:dump_flows].each do |flow|
          info "- Openflow Flow: #{flow}"
        end
      end
    end

    # Calling standard methods or assignments will simply trigger sending a FRCP message
    #
    # @example OEDL
    #   # Will send FRCP CONFIGURE message
    #   s.configure = 0
    #
    #   # Will send FRCP REQUEST message
    #   s.configure
    #
    def method_missing(name, *args, &block)
      # info name
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
        return nil
      end
    end

    # Send FRCP message
    #
    # @param [String] name of the property
    # @param [Object] value of the property, for configuring
    # @param [Object] operation
    def send_message(name, value = nil, operation = :request, &block)
      case operation
      when :configure
        info name
        info value
        @topic.configure({ name => value }, {assert: OmfEc.experiment.assertion })
        when :request
          @topic.request([name], { assert: OmfEc.experiment.assertion })
        else
          # type code here
      end
    end

  end
end
