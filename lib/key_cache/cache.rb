# frozen_string_literal: true

module KeyCache
  ##
  # KeyCache::Cache
  #
  # Description
  #
  # This modules is an Rails Concern which provides a simple mechanism for
  # caching values in redis.
  #
  # Arguments
  #
  #   key: key value to store the location. Use "/" to define segments and ":"
  #        to define segements that you want to be replaced by values returned
  #        from methods in your class
  #
  #   value: When saving the record, this method will be called to get the value
  #          to store in Redis.
  #
  #   method: defines a method which can be called to get the value of the
  #           stored Redis key
  #
  # Usage
  #
  # class SomeModel < ApplicationRecord
  #   include KeyCache::Cache
  #
  #   cache_key key: "some_model/:id",
  #             value: :some_attribute,
  #             method: :some_model_cache
  # end
  #
  # s = SomeModel.save!(some_value: "this value")
  #
  # s.some_attribute
  # > this value
  #
  # s.some_attribute_key
  # > some_model/:id
  #
  # s.some_attribute_redis_key
  # > some_model:1
  #
  # s.save_some_attribute # Saves key to Redis
  #
  # s.destroy_some_attribute # Deletes key from Redis
  #
  # s.destory # Delete record and redis key
  module Cache
    extend ActiveSupport::Concern

    class_methods do
      def cache_key(options = {})
        key = options.fetch(:key, nil)
        value = options.fetch(:value, nil)
        method = options.fetch(:method, nil)
        include_callbacks = options.fetch(:include_callbacks, true)

        return unless key && value && method

        class_eval <<-METHOD, __FILE__, __LINE__ + 1
          def #{method}
            KeyCache.redis.get(cache_key_decode("#{key}"))
          end

          def #{method}_key
            "#{key}"
          end

          def #{method}_redis_key
            cache_key_decode("#{key}")
          end

          def save_#{method}
            KeyCache.redis.set(cache_key_decode("#{key}"), self.send("#{value.to_sym}"))
          end

          #{"after_save :save_#{method}" if include_callbacks}

          def destroy_#{method}
            KeyCache.redis.del(cache_key_decode("#{key}"))
          end

          #{"after_destroy :destroy_#{method}" if include_callbacks}
        METHOD
      end

      def hash_cache_key(options = {})
        key = options.fetch(:key, nil)
        field = options.fetch(:field, nil)
        value = options.fetch(:value, nil)
        method = options.fetch(:method, nil)
        include_callbacks = options.fetch(:include_callbacks, true)
        soft_deletion = self.column_names.include?('deleted_at')

        return unless key && field && value && method

        class_eval <<-METHOD, __FILE__, __LINE__ + 1
          def #{method}
            KeyCache.redis.hget(cache_key_decode("#{key}"), self.send("#{field}"))
          end

          def #{method}_key
            "#{key}"
          end

          def #{method}_keys
            KeyCache.redis.hkeys(cache_key_decode("#{key}"))
          end

          def #{method}_values
            KeyCache.redis.hvals(cache_key_decode("#{key}"))
          end

          def #{method}_hash
            KeyCache.redis.hgetall(cache_key_decode("#{key}"))
          end

          def #{method}_redis_key
            cache_key_decode("#{key}")
          end

          def save_#{method}
            return if #{soft_deletion} && self.deleted_at.present?
            KeyCache.redis.hset(cache_key_decode("#{key}"), self.send("#{field}"), self.send("#{value.to_sym}"))
          end

          #{"after_save :save_#{method}" if include_callbacks}

          def destroy_#{method}
            return if #{soft_deletion} && self.deleted_at.nil?
            KeyCache.redis.hdel(cache_key_decode("#{key}"), self.send("#{field}"))
          end

          #{"after_destroy :destroy_#{method}" if include_callbacks}
          #{"after_save :destroy_#{method}, if: :saved_change_to_deleted_at?" if include_callbacks && soft_deletion}
        METHOD
      end
    end

    def cache_key_decode(key)
      key_parts = key.split('/')
      key_parts.map! do |v|
        v.match(/^:/) ? send(v.tr(':', '')) : v
      end
      key_parts.join(':')
    end
  end
end
