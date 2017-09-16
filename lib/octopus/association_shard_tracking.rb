module Octopus
  module AssociationShardTracking
    class MismatchedShards < StandardError
      attr_reader :record, :current_shard

      def initialize(record, current_shard)
        @record = record
        @current_shard = current_shard
      end

      def message
        [
          "Association Error: Records are from different shards",
          "Record: #{record.inspect}",
          "Current Shard: #{current_shard.inspect}",
          "Current Record Shard: #{record.current_shard.inspect}",
        ].join(" ")
      end
    end

    habtm_args = [association_id, scope = nil, options = {}, &extension]
    habtm_args51 = [association_id, scope = nil, **options, &extension]

    def self.extended(base)
      base.send(:include, InstanceMethods)
      puts "~~~DX~~~ Including 51" if Octopus.rails51?
      base.send(:include, Rails51Methods) if Octopus.rails51?
    end

    module Rails51Methods
      def has_and_belongs_to_many(association_id, scope = nil, **options, &extension)
        if options == {} && scope.is_a?(Hash)
          default_octopus_opts(scope)
        else
          default_octopus_opts(options)
        end
        super
      end
      
      def default_octopus_opts(**options)
        options[:before_add] = [ :connection_on_association=, options[:before_add] ].compact.flatten
        options[:before_remove] = [ :connection_on_association=, options[:before_remove] ].compact.flatten
      end
    end

    module InstanceMethods
      def connection_on_association=(record)
        return unless ::Octopus.enabled?
        return if !self.class.connection.respond_to?(:current_shard) || !self.respond_to?(:current_shard)

        if !record.current_shard.nil? && !current_shard.nil? && record.current_shard != current_shard
          raise MismatchedShards.new(record, current_shard)
        end

        record.current_shard = self.class.connection.current_shard = current_shard if should_set_current_shard?
      end
    end

    def has_many(association_id, scope = nil, options = {}, &extension)
      if options == {} && scope.is_a?(Hash)
        default_octopus_opts(scope)
      else
        default_octopus_opts(options)
      end
      super
    end

    def has_and_belongs_to_many(association_id, scope = nil, **options, &extension)
      if options == {} && scope.is_a?(Hash)
        default_octopus_opts(scope)
      else
        default_octopus_opts(options)
      end
      super
    end

    def default_octopus_opts(options)
      options[:before_add] = [ :connection_on_association=, options[:before_add] ].compact.flatten
      options[:before_remove] = [ :connection_on_association=, options[:before_remove] ].compact.flatten
    end
  end
end

ActiveRecord::Base.extend(Octopus::AssociationShardTracking)
