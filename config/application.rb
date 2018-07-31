require_relative 'boot'
require_relative '../app/src/redis_rate_limiter'

require 'rails'
# Pick the frameworks you want:
# require "active_model/railtie"
# require "active_job/railtie"
# require "active_record/railtie"
require 'action_controller/railtie'
# require "action_mailer/railtie"
require 'action_view/railtie'
# require "action_cable/engine"
# require "sprockets/railtie"
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AirtaskerTest
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # config.middleware.use RateLimiter
    config.middleware.insert_after ActionDispatch::RemoteIp,
                                   RedisRateLimiter, count: 10, interval: 30.seconds
  end
end
