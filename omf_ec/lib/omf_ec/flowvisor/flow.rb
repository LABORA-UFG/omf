# Copyright (c) 2017 Computer Networks and Distributed Systems LABORAtory (Labora) - [https://labora.inf.ufg.br/].
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfEc::FlowVisor

  class Flow

    attr_accessor :id, :name, :operation, :device, :match

    # @param [String] name to identify the flow
    def initialize(name)
      self.name = name
    end

  end

end
