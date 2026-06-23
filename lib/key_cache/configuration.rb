# frozen_string_literal: true

module KeyCache
  class << self
    attr_writer :redis

    def redis
      @redis ||
        (Redis.current if defined?(Redis) && Redis.respond_to?(:current)) ||
        raise(ArgumentError, "KeyCache.redis is not configured")
    end

    def configure
      yield self
    end
  end
end
