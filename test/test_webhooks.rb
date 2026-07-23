# frozen_string_literal: true

require "minitest/autorun"
require "quolle"
require "openssl"
require "json"

class WebhooksTest < Minitest::Test
  def setup
    @client = Quolle::Client.new(api_key: "qle_test")
    @secret = "whsec_test"
    @body = { event: "email.delivered", emailId: "em_1" }.to_json
  end

  def header(ts, body = @body, secret = @secret)
    sig = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{ts}.#{body}")
    "t=#{ts},v1=#{sig}"
  end

  def test_verifies_valid_signature
    evt = @client.webhooks.verify(@body, header(Time.now.to_i), @secret)
    assert_equal "email.delivered", evt["event"]
  end

  def test_rejects_tampered_body
    h = header(Time.now.to_i)
    assert_raises(Quolle::Error) { @client.webhooks.verify("#{@body} ", h, @secret) }
  end

  def test_rejects_stale_timestamp
    assert_raises(Quolle::Error) { @client.webhooks.verify(@body, header(Time.now.to_i - 10_000), @secret) }
  end

  def test_rejects_wrong_secret
    h = header(Time.now.to_i, @body, "whsec_right")
    assert_raises(Quolle::Error) { @client.webhooks.verify(@body, h, "whsec_wrong") }
  end

  def test_rejects_malformed_header
    assert_raises(Quolle::Error) { @client.webhooks.verify(@body, "garbage", @secret) }
  end
end
