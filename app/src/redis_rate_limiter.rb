class RedisRateLimiter
  def initialize(app, **options)
    @app = app

    @interval = options[:interval].to_i
    @count = options[:count].to_i

    raise ArgumentError('interval must be set to a positive integer') if @interval <= 0
    raise ArgumentError('count must be set to a positive integer') if @count <= 0

    @code = options[:code] || 429 # https://tools.ietf.org/html/rfc6585#section-4
    @message = options[:message] || 'Rate limit exceeded'
    @identifier = options[:identifier]
    @key_prefix = options[:key_prefix] || 'redis-rate-limiter'

    redis_options = options.slice(:host, :port, :db, :url, :path, :password, :sentinels, :role)
    @redis = options[:redis] || Redis.new(**redis_options)

    # Make sure that Redis connects successfully on app start
    @redis.multi do
      @redis.set @key_prefix, 'test'
      @redis.expire @key_prefix, 1
    end
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    blocked?(request) ? limit_exceeded(request) : @app.call(env)
  end

  private

  def blocked?(request)
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
    response = @redis.multi do
      @redis.incr key # increments the number @ key by 1, sets to 0 if doesn't exist (then incremented)
      @redis.expire key, @interval
    end

    response[0].to_i
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
