# frozen_string_literal: true

require "minitest/autorun"
require "quolle"

# Tests stub Client#request so no network is touched; we assert the resource
# builds the right method/path/body/headers and parses responses correctly.
class RecordingClient < Quolle::Client
  attr_reader :last
  attr_accessor :response

  def initialize
    super(api_key: "qle_test")
    @response = {}
  end

  def request(method, path, body: nil, headers: {})
    @last = { method: method, path: path, body: body, headers: headers }
    @response
  end
end

class EmailsTest < Minitest::Test
  def setup
    @client = RecordingClient.new
    @emails = Quolle::Resources::Emails.new(@client)
  end

  def test_requires_api_key
    ENV.delete("QUOLLE_API_KEY")
    assert_raises(ArgumentError) { Quolle::Client.new(api_key: nil) }
  end

  def test_send_maps_snake_case_and_path
    @client.response = { "id" => "em_1", "message" => "Email queued successfully" }
    result = @emails.send(
      from: "hello@mail.acme.com",
      to: "user@example.com",
      subject: "Hi",
      html: "<p>Hi</p>",
      reply_to: "support@acme.com"
    )
    assert_equal "em_1", result["id"]
    assert_equal "POST", @client.last[:method]
    assert_equal "/v1/emails/send", @client.last[:path]
    assert_equal "hello@mail.acme.com", @client.last[:body]["from"]
    # reply_to -> replyTo
    assert_equal "support@acme.com", @client.last[:body]["replyTo"]
    refute @client.last[:body].key?("reply_to")
  end

  def test_send_idempotency_header
    @emails.send(from: "a@b.com", to: "c@d.com", subject: "s", html: "<p>x</p>",
                 idempotency_key: "order_123")
    assert_equal "order_123", @client.last[:headers]["Idempotency-Key"]
  end

  def test_send_batch
    @client.response = { "queued" => 2, "ids" => %w[a b] }
    out = @emails.send_batch([
                               { from: "a@b.com", to: "x@y.com", subject: "1", html: "<p>1</p>" },
                               { from: "a@b.com", to: "z@y.com", subject: "2", html: "<p>2</p>" }
                             ])
    assert_equal 2, out["queued"]
    assert_equal "/v1/emails/batch", @client.last[:path]
    assert_equal 2, @client.last[:body][:emails].length
  end

  def test_get_unwraps_email
    @client.response = { "email" => { "id" => "em_1", "status" => "delivered" } }
    email = @emails.get("em_1")
    assert_equal "delivered", email["status"]
    assert_equal "GET", @client.last[:method]
  end

  def test_cancel_uses_delete
    @client.response = { "message" => "Scheduled email cancelled" }
    out = @emails.cancel("em_1")
    assert_equal "Scheduled email cancelled", out["message"]
    assert_equal "DELETE", @client.last[:method]
    assert @client.last[:path].end_with?("/cancel")
  end

  def test_error_carries_status_and_data
    err = Quolle::Error.new("Monthly limit reached", status_code: 402, data: { "limit" => 3000 })
    assert_equal 402, err.status_code
    assert_equal 3000, err.data["limit"]
    assert_equal "Monthly limit reached", err.message
  end

  def test_create_is_the_same_as_send
    @client.response = { "id" => "em_1" }
    @emails.create(from: "a@b.co", to: "c@d.co", subject: "s", html: "<p>x</p>")
    assert_equal "/v1/emails/send", @client.last[:path]
  end

  def test_message_type_maps_to_type
    @emails.create(from: "a@b.co", to: "c@d.co", subject: "s", html: "<p>x</p>", message_type: "marketing")
    assert_equal "marketing", @client.last[:body]["type"]
  end

  def test_ids_are_path_encoded_not_form_encoded
    @client.response = { "email" => {} }
    @emails.get("a b/c")
    assert_equal "/v1/emails/a%20b%2Fc", @client.last[:path]
  end

  def test_error_carries_api_code
    e = Quolle::Error.new("Warm-up cap reached", status_code: 429, code: "warmup_limit_exceeded")
    assert_equal "warmup_limit_exceeded", e.code
  end
end
