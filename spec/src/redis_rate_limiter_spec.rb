require 'rails_helper'

RSpec.describe RedisRateLimiter do
  let(:app) { ->(env) { [200, env, 'app'] } }
  let(:redis) { MockRedis.new }
  let(:message) { nil }
  let(:code) { nil }
  let(:identifier) { nil }

  let :middleware do
    RedisRateLimiter.new(app, redis: redis, interval: interval, count: count,
                              message: message, code: code, identifier: identifier)
  end

  def env_for(remote_ip = '127.0.0.1', url = 'http://example.com/test', opts = {})
    Rack::MockRequest.env_for(url, opts).tap do |env|
      env['REMOTE_ADDR'] = remote_ip
    end
  end

  context 'with a max count of 5 and interval of 60 seconds' do
    let(:interval) { 60 }
    let(:count) { 5 }

    before(:each) { Timecop.freeze } # keep Time.now frozen to the same value
    after(:each) { Timecop.return }

    it 'passes the first request' do
      code, _env, body = middleware.call env_for
      expect(code).to eq 200
      expect(body).to eq 'app'
    end

    it 'blocks on the 6th request' do
      5.times do
        code, _env = middleware.call env_for
        expect(code).to eq 200
      end

      code, _env = middleware.call env_for
      expect(code).to eq 429
    end

    it 'blocks based on ip address' do
      5.times { middleware.call env_for '2.2.2.2' }

      code, _env = middleware.call env_for '2.2.2.2'
      expect(code).to eq 429

      code, _env = middleware.call env_for '1.1.1.1'
      expect(code).to eq 200
    end

    it 'resets after the interval boundary' do
      Timecop.travel Time.parse('2018-01-01 01:00:05')
      5.times { middleware.call env_for }

      Timecop.travel Time.parse('2018-01-01 01:00:59')
      code, _env = middleware.call env_for
      expect(code).to eq 429

      Timecop.travel Time.parse('2018-01-01 01:01:00')

      code, _env = middleware.call env_for
      expect(code).to eq 200
    end

    describe 'identifier option' do
      context 'when using request.url instead of request.ip' do
        let(:identifier) { ->(request) { request.url } }

        it 'blocks based on url not on ip address' do
          5.times { middleware.call env_for '1.1.1.1', 'http://example.com/a' }

          code, _env = middleware.call env_for '1.1.1.1', 'http://example.com/a'
          expect(code).to eq 429

          code, _env = middleware.call env_for '2.2.2.2', 'http://example.com/a'
          expect(code).to eq 429

          code, _env = middleware.call env_for '1.1.1.1', 'http://example.com/b'
          expect(code).to eq 200
        end
      end
    end

    describe 'error response' do
      before(:each) { 5.times { middleware.call env_for } }

      context 'with the default error message' do
        it 'shows the correct error message body when blocked' do
          _code, _env, body = middleware.call env_for
          expect(body).to eq ['Rate limit exceeded']
        end

        context 'in the api' do
          it 'shows the correct error message in JSON format' do
            _code, _env, body = middleware.call env_for '127.0.0.1', 'http://example.com/api/test'
            expect(body).to eq [{error: 'Rate limit exceeded'}.to_json]
          end
        end
      end

      context 'with a custom error message' do
        let(:message) { 'Blocked!' }
        it 'shows the correct error message body when blocked' do
          _code, _env, body = middleware.call env_for
          expect(body).to eq ['Blocked!']
        end
      end

      context 'with a custom status code' do
        let(:code) { 403 }
        it 'responds with the custom status code when blocked' do
          code, _env, _body = middleware.call env_for
          expect(code).to eq 403
        end
      end
    end
  end
end
