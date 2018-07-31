# Airtasker challenge

This is a very empty Rails app. It has only 1 route; /api/widgets.
There are no models nor database configuration.

A custom middleware called RedisRateLimiter is implemented in app/src/redis_rate_limiter.rb and enabled only for the production environment.

## Setup instructions
1. ```git clone https://github.com/mcclymont/airtasker-test```
2. ```cd airtasker-test```
3. ```bundle install```

## Configuration
RedisRateLimiter is added as a middleware in config/environments/production.rb like so:
```
config.middleware.insert_after ActionDispatch::RemoteIp,
                               RedisRateLimiter, count: 100, interval: 1.hour
```
The available options for RedisRateLimiter are
| Option | Description | Default|
| --- | --- | --- |
| interval | (integer) Time interval in seconds | |
| count | (integer) Max count of requests during each interval | |
| code | (integer) HTTP status code for rejection case | 429 |
| message | (string) Response body content for rejection case | Rate limit exceeded |
| identifier | (proc) Callable that takes request argument and returns unique identifier | -> (request) { request.remote_ip } |
| key_prefix | (string) Prefix to redis keys | redis_rate_limiter |
| store | (object) Object instance that implements the redis-rb interface | Redis.new |

## Usage

### Tests
```bundle exec rspec```
### Check style
```rubocop```
### Manually check rate limiting
1. ```RAILS_ENV=production bundle exec rails server```
2. ```for i in {1..100}; do curl localhost:3000/api/widgets; done```
3. ```curl localhost:3000/api/widgets``` Should now be blocked until the next hour

