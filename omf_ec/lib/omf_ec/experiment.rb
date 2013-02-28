require 'hashie'
require 'singleton'
require 'monitor'

module OmfEc
  # Experiment class to hold relevant state information
  #
  class Experiment
    include Singleton

    include MonitorMixin

    attr_accessor :name, :oml_uri, :app_definitions, :property, :cmdline_properties
    attr_reader :groups, :sub_groups, :state

    def initialize
      @id = Time.now.utc.iso8601
      @state ||= [] #TODO: we need to keep history of all the events and not ovewrite them
      @groups ||= []
      @events ||= []
      @app_definitions ||= Hash.new
      @sub_groups ||= []
      @cmdline_properties ||= Hash.new
      super
    end

    def property
      return ExperimentProperty
    end

    def add_property(name, value = nil, description = nil)
      override_value = @cmdline_properties[name.to_s.to_sym]
      value = override_value unless override_value.nil?
      ExperimentProperty.create(name, value, description)
    end

    def resource(id)
      @state.find { |v| v[:uid].to_s == id.to_s }
    end

    def resource_by_hrn(hrn)
      @state.find { |v| v[:hrn].to_s == hrn.to_s }
    end

    def add_resource(name, opts = {})
      self.synchronize do
        unless resource(name)
          @state << Hashie::Mash.new({ uid: name }.merge(opts))
        end
      end
    end

    def sub_group(name)
      @sub_groups.find { |v| v == name }
    end

    def add_sub_group(name)
      self.synchronize do
        @sub_groups << name unless @sub_groups.include?(name)
      end
    end

    def group(name)
      groups.find { |v| v.name == name }
    end

    def add_group(group)
      self.synchronize do
        raise ArgumentError, "Expect Group object, got #{group.inspect}" unless group.kind_of? OmfEc::Group
        @groups << group unless group(group.name)
      end
    end

    def each_group(&block)
      if block
        groups.each { |g| block.call(g) }
      else
        groups
      end
    end

    def all_groups?(&block)
      !groups.empty? && groups.all? { |g| block ? block.call(g) : g }
    end

    def event(name)
      @events.find { |v| v[:name] == name }
    end

    def add_event(name, trigger)
      self.synchronize do
        raise RuntimeError, "Event '#{name}' has been defined" if event(name)
        @events << { name: name, trigger: trigger }
      end
    end

    # Unique experiment id
    def id
      @name.nil? ? @id : "#{@name}-#{@id}"
    end

    # Parsing user defined events, checking conditions against internal state, and execute callbacks if triggered
    def process_events
      self.synchronize do
        @events.find_all { |v| v[:callbacks] && !v[:callbacks].empty? }.each do |event|
          if event[:trigger].call(@state)
            info "Event triggered: '#{event[:name]}'"
            @events.delete(event) if event[:consume_event]

            # Last in first serve callbacks
            event[:callbacks].reverse.each do |callback|
              callback.call
            end
          end
        end
      end
    end

    # Purely for backward compatibility
    class << self
      # Disconnect communicator, try to delete any XMPP affiliations
      def done
        info "Exit in up to 15 seconds..."

        OmfCommon.eventloop.after(10) do
          info "Release applications and network interfaces"

          allGroups do |g|
            g.resources[type: 'application'].release
            g.resources[type: 'net'].release unless g.net_ifs.find_all { |v| v.conf[:type] == 'net' }.empty?
            g.resources[type: 'wlan'].release unless g.net_ifs.find_all { |v| v.conf[:type] == 'wlan' }.empty?
          end

          OmfCommon.eventloop.after(5) do
            OmfCommon.comm.disconnect
          end
        end
      end
    end
  end
end
