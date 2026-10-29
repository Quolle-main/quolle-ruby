# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "quolle"

# Domains, API keys and webhook endpoints (K8): each method hits the right route.
class ManagementTest < Minitest::Test
  Resp = Struct.new(:code, :body) do
    def [](_k) = nil
  end

  class Recorder
    attr_reader :seen

    def initialize(status = 200, body = nil)
      @seen = []
      @status = status
      @body = body || JSON.generate({ "domains" => [{ "id" => "d1" }], "domain" => { "id" => "d1" },
                                      "keys" => [{ "id" => "k1" }], "webhooks" => [], "deliveries" => [], "events" => [] })
    end

    def use_ssl=(_); end
    def open_timeout=(_); end
    def read_timeout=(_); end

    def request(req)
      @seen << [req.method, req.path, req.body && JSON.parse(req.body)]
      Resp.new(@status.to_s, @body)
    end
  end

  def with_http(rec)
    original = Net::HTTP.method(:new)
    Net::HTTP.define_singleton_method(:new) { |*_| rec }
    yield Quolle::Client.new(api_key: "qle_test", max_retries: 0)
  ensure
    Net::HTTP.define_singleton_method(:new, original)
  end

  def routes(rec) = rec.seen.map { |m, p, _| "#{m} #{p}" }

  def test_domains
    rec = Recorder.new
    with_http(rec) do |q|
      assert_equal "d1", q.domains.list.first["id"]
      q.domains.create("mail.acme.com")
      assert_equal "d1", q.domains.get("d1")["id"]
      q.domains.records("d1")
      q.domains.verify("d1")
      q.domains.remove("d1")
    end
    assert_equal ["GET /v1/domains", "POST /v1/domains", "GET /v1/domains/d1", "GET /v1/domains/d1/records",
                  "POST /v1/domains/d1/recheck", "DELETE /v1/domains/d1"], routes(rec)
    assert_equal({ "domain" => "mail.acme.com" }, rec.seen[1][2])
  end

  def test_api_keys
    rec = Recorder.new
    with_http(rec) do |q|
      assert_equal "k1", q.api_keys.list.first["id"]
      q.api_keys.create(name: "ci", scope: "sending", expires_in_days: 30)
      q.api_keys.remove("k1")
    end
    assert_equal ["GET /v1/keys", "POST /v1/keys", "DELETE /v1/keys/k1"], routes(rec)
    assert_equal({ "name" => "ci", "scope" => "sending", "expiresInDays" => 30 }, rec.seen[1][2])
  end

  def test_webhook_endpoints
    rec = Recorder.new
    with_http(rec) do |q|
      q.webhooks.events
      q.webhooks.list
      q.webhooks.create(url: "https://x.io/h", events: ["email.delivered"])
      q.webhooks.get("w1")
      q.webhooks.update("w1", events: ["email.bounced"])
      q.webhooks.test("w1")
      q.webhooks.deliveries("w1", status: "failed", limit: 10)
      q.webhooks.redeliver("w1", "dl1")
      q.webhooks.rotate_secret("w1")
      q.webhooks.remove("w1")
    end
    assert_equal ["GET /v1/webhooks/events", "GET /v1/webhooks", "POST /v1/webhooks", "GET /v1/webhooks/w1",
                  "PATCH /v1/webhooks/w1", "POST /v1/webhooks/w1/test",
                  "GET /v1/webhooks/w1/deliveries?status=failed&limit=10",
                  "POST /v1/webhooks/w1/deliveries/dl1/redeliver", "POST /v1/webhooks/w1/rotate-secret",
                  "DELETE /v1/webhooks/w1"], routes(rec)
    assert_equal({ "events" => ["email.bounced"] }, rec.seen[4][2])
  end

  def test_restricted_key_error_code
    rec = Recorder.new(403, JSON.generate({ "code" => "restricted_api_key", "error" => "This API key can only send email." }))
    err = with_http(rec) { |q| assert_raises(Quolle::Error) { q.api_keys.list } }
    assert_equal "restricted_api_key", err.code
  end
end
