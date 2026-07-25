# frozen_string_literal: true

require "minitest/autorun"
require "quolle"

# Exercises the real Client#request retry logic by stubbing the HTTP transport.
class FakeResp
  def initialize(code, body = "{}", headers = {})
    @code = code
    @body = body
    @headers = headers
  end

  def code = @code.to_s
  def body = @body
  def [](k) = @headers[k]
end

# A fake Net::HTTP whose #request pops the next scripted outcome (a FakeResp or
# an exception to raise). Records how many times it was called.
class FakeHttp
  attr_reader :calls

  def initialize(script)
    @script = script
    @calls = 0
  end

  def use_ssl=(_); end
  def open_timeout=(_); end
  def read_timeout=(_); end

  def request(_req)
    @calls += 1
    outcome = @script.shift
    raise outcome if outcome.is_a?(Exception)

    outcome
  end
end

class RetryTest < Minitest::Test
  def run_with(script, **send_opts)
    fake = FakeHttp.new(script)
    client = Quolle::Client.new(api_key: "qle_test")
    # No real waiting between retries.
    client.define_singleton_method(:sleep) { |*| }

    # Stub Net::HTTP.new to return our fake transport, then restore it. Done
    # manually (not via minitest/mock, which isn't reliably present on CI runners).
    original_new = Net::HTTP.method(:new)
    Net::HTTP.define_singleton_method(:new) { |*_args| fake }
    begin
      result = client.emails.send(from: "a@b.com", to: "c@d.com", subject: "s", html: "<p>x</p>", **send_opts)
      [fake.calls, result, nil]
    rescue Quolle::Error => e
      [fake.calls, nil, e]
    ensure
      Net::HTTP.define_singleton_method(:new, original_new)
    end
  end

  def test_retries_on_429_then_succeeds
    calls, result, error = run_with([
      FakeResp.new(429, '{"error":"rate limited"}'),
      FakeResp.new(429, '{"error":"rate limited"}'),
      FakeResp.new(200, '{"id":"em_ok"}')
    ])
    assert_nil error
    assert_equal "em_ok", result["id"]
    assert_equal 3, calls
  end

  def test_post_5xx_without_idempotency_does_not_retry
    calls, _result, error = run_with([FakeResp.new(500, '{"error":"boom"}')])
    refute_nil error
    assert_equal 1, calls # must not retry a POST 5xx (no double-send)
  end

  def test_post_5xx_with_idempotency_retries
    calls, result, error = run_with(
      [FakeResp.new(503, '{"error":"later"}'), FakeResp.new(200, '{"id":"em_ok"}')],
      idempotency_key: "order_1"
    )
    assert_nil error
    assert_equal "em_ok", result["id"]
    assert_equal 2, calls
  end
end
