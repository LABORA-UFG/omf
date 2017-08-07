# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'monitor'

module OmfEc::FlowVisor

  class Slice

    attr_accessor :id, :name, :topic_name
    attr_reader :topic

    # @param [String] name name of virtual machine
    def initialize(name, &block)
      super()
      self.id = "#{OmfEc.experiment.id}.#{self.name}"
      self.name = name
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

  end

end
