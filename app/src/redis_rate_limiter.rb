class RedisRateLimiter
  def initialize(app, interval:, count:, **options)
    @app = app

    @interval = interval.to_i # Time interval in seconds
    @count = count.to_i       # Max number of requests allowed per interval

    raise ArgumentError('interval must be set to a positive integer') if @interval <= 0
    raise ArgumentError('count must be set to a positive integer') if @count <= 0

    @code = options[:code] || 429 # https://tools.ietf.org/html/rfc6585#section-4
    @message = options[:message] || 'Rate limit exceeded'
    @identifier = options[:identifier]
    @key_prefix = options[:key_prefix] || self.class.name.underscore

    @store = configure_store(**options)
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    blocked?(request) ? limit_exceeded(request) : @app.call(env)
  end

  private

  def configure_store(**options)
    redis_options = options.slice(:host, :port, :db, :url, :path, :password, :sentinels, :role)
    redis = options[:redis] || Redis.new(**redis_options)

    # Make sure that Redis connects successfully on app start
    redis.multi do
      redis.set @key_prefix, 'test'
      redis.expire @key_prefix, 1
    end
    redis
  end

  def blocked?(request)
    # Uses 'Fixed window' rate limiting https://konghq.com/blog/how-to-design-a-scalable-rate-limiting-algorithm/
    # See also https://redis.io/commands/incr#pattern-rate-limiter-1

    now_timestamp = Time.now.to_i
    epoch_timestamp = now_timestamp - (now_timestamp % @interval) # round down current time to interval multiple
    key = [
      @key_prefix,
      Time.at(epoch_timestamp).strftime('%Y-%m-%dT%H:%M:%S'),
      @interval,
      identifier(request)
    ].join(':')

    get_set_count(key) > @count
  end

  def get_set_count(key)
    response = @store.multi do
      @store.incr key # sets to 0 if doesn't exist, then increments and returns the value
      @store.expire key, @interval
    end
    response[0].to_i
  rescue Redis::BaseConnectionError => e
    Rails.logger.error e
    Rails.logger.error e.backtrace.join("\n")
    1 # In case of Redis connection failure, disable rate limiting
  end

  def identifier(request)
    @identifier ? @identifier.call(request) : request.remote_ip
  end

  def limit_exceeded(request)
    if request.env['PATH_INFO'].start_with? '/api/'
      [@code, {'Content-Type' => 'application/json; charset=utf-8'}, [{error: @message}.to_json]]
    else
      [@code, {'Content-Type' => 'text/plain; charset=utf-8'}, [@message]]
    end
  end
end
