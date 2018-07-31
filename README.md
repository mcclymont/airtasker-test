# Airtasker challenge

This is a very empty Rails app. It has only 1 route; /api/widgets.
There are no models nor database configuration.

A custom middleware called RedisRateLimiter is implemented in app/src/redis_rate_limiter.rb and enabled only for the production environment.

## Setup instructions
1. ```git clone https://github.com/mcclymont/airtasker-test```
2. ```cd airtasker-test```
3. ```bundle install```

## Usage

### Tests
```bundle exec rspec```
### Check style
```rubocop```
### Manually check rate limiting
1. ```RAILS_ENV=production bundle exec rails server```
2. ```for i in {1..100}; do curl localhost:3000/api/widgets; done```
3. ```curl localhost:3000/api/widgets``` Should now be blocked until the next hour

