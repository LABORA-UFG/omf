# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfEc::Context
  # Holds application configuration
  class AppContext
    attr_accessor :name, :orig_name, :app_def, :param_values, :oml_collections, :proto_props

    # Keep track of contexts for each app, i.e. multiple contexts can share
    # the same app def. This happens for example when a group can have the
    # same applications added to it many times, but with different parameter
    # values for each. Thus we need to distinguish these different context
    @@context_count = Hash.new

    def initialize(name, location = nil, group)
      load_oedl(location) unless location.nil?
      if OmfEc.experiment.app_definitions.key?(name)
        self.app_def = OmfEc.experiment.app_definitions[name]
        self.param_values = Hash.new
        self.oml_collections = Array.new
        @@context_count[name] = 0 unless @@context_count.key?(name)
        id = @@context_count[name]
        @@context_count[name] += 1
        self.name = "#{name}_cxt_#{id}"
        self.orig_name = name
        @group = group
        self
      else
        raise RuntimeError, "Cannot create context for unknown application '#{name}'"
      end
    end

    def setProperty(key, property_value)
      app_def_param = app_def.properties.parameters
      raise OEDLUnknownProperty.new(key, "Unknown parameter '#{key}' for application "+
        "definition '#{app_def.name}'") if app_def_param.nil? || !app_def_param.key?(key)
      if property_value.kind_of?(OmfEc::ExperimentProperty)
        @param_values[key] = property_value.value
        # if this app parameter has its dynamic attribute set to true, then
        # we register a callback block to the ExperimentProperty, which will
        # be called each time the property changes its value
        if app_def_param[key][:dynamic] and @group.kind_of?(OmfEc::Group)
          info "Binding dynamic parameter '#{key}' to the property '#{property_value.name}'"
          property_value.on_change do |new_value|
            info "Updating dynamic app parameter '#{key}' with value: '#{new_value}'"
            OmfEc.subscribe_and_monitor(@group.resource_group(:application)) do |topic|
              p = properties
              p[:parameters][key.to_sym][:value] = property_value.value
              topic.configure(p, { guard: { hrn: @name}, assert: OmfEc.experiment.assertion } )
            end
          end
        end
      else
        @param_values[key] = property_value
      end
      self
    end

    def bindProperty(prop_name, prop_ref = prop_name)
      @proto_props ||= Hashie::Mash.new
      @proto_props[prop_name] = prop_ref
    end

    # For now this follows v5.4 syntax...
    # We have not yet finalised an OML syntax inside OEDL for v6
    # TODO: v6 currently does not support OML filters. Formerly in v5.x, these
    # filters were defined in an optional block.
    def measure(mp, opts, &block)
      collect_point = opts.delete(:collect)
      collect_point ||= OmfEc.experiment.oml_uri
      if collect_point.nil?
        warn "No OML URI configured for measurement collection! "+
             "(see option 'oml_uri'). Disabling OML Collection for '#{mp}'."
        return
      end
      stream = { :mp => mp , :filters => [] }.merge(opts)
      index = @oml_collections.find_index { |c| c[:url] == collect_point }
      @oml_collections << {:url => collect_point, :streams => [stream] } if index.nil?
      @oml_collections[index][:streams] << stream unless index.nil?
    end

    def properties
      # deep copy the properties from the app definition
      original = Marshal.load(Marshal.dump(app_def.properties))
      # now build the properties for this context
      # - use the properties from app definition as the base
      # - if this context's param_values has a property which also exists in
      #   the app def and if that property has an assigned value, then
      #   use that value for the properties of this context
      p = original.merge({type: 'application', state: 'created'})
      @param_values.each do |k,v|
        if p[:parameters].key?(k)
          p[:parameters][k][:value] = v.kind_of?(OmfEc::ExperimentProperty) ? v.value : v
        end
      end
      if @oml_collections.size > 0
        p[:use_oml] = true
        p[:oml][:id] = @name
        p[:oml][:experiment] = OmfEc.experiment.id
        p[:oml][:collection] = @oml_collections
      end
      p
    end

    def mp_table_names
      {}.tap do |m_t_n|
        @oml_collections.map { |v| v[:streams] }.flatten.each do |s|
          mp = s[:mp].to_s
          m_t_n[mp] = "#{self.app_def.name}_#{mp}"
        end
      end
    end
  end
end
