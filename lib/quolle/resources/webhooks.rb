# frozen_string_literal: true

require "openssl"
require "json"
require "uri"
require_relative "path"

module Quolle
  module Resources
    # Verify incoming webhooks, and manage webhook endpoints (+client.webhooks+).
    # +verify+ makes no API call; the management methods need a full-access key.
    class Webhooks
      DEFAULT_TOLERANCE = 300 # seconds

      def initialize(client = nil)
        @client = client
      end

      # @return [Array<Hash>] the events a webhook can subscribe to
      def events
        req("GET", "/v1/webhooks/events")["events"] || []
      end

      # @return [Array<Hash>]
      def list
        req("GET", "/v1/webhooks")["webhooks"] || []
      end

      # Add an endpoint. The returned +secret+ (whsec_…) is shown once; store it.
      def create(url:, events:)
        req("POST", "/v1/webhooks", { url: url, events: events })
      end

      def get(id)
        req("GET", "/v1/webhooks/#{Path.escape(id)}")
      end

      # Change the URL or events. The signing secret stays the same.
      def update(id, url: nil, events: nil)
        body = {}
        body[:url] = url if url
        body[:events] = events if events
        req("PATCH", "/v1/webhooks/#{Path.escape(id)}", body)
      end

      def remove(id)
        req("DELETE", "/v1/webhooks/#{Path.escape(id)}")
      end

      # Send a signed +webhook.test+ event now and report how the endpoint answered.
      def test(id)
        req("POST", "/v1/webhooks/#{Path.escape(id)}/test")
      end

      # Deliveries from the last 30 days, newest first.
      # @param status ["succeeded", "pending", "failed", nil]
      def deliveries(id, status: nil, limit: nil)
        params = { status: status, limit: limit }.compact
        qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
        req("GET", "/v1/webhooks/#{Path.escape(id)}/deliveries#{qs}")["deliveries"] || []
      end

      # Send a delivery again, with the same body and +eventId+.
      def redeliver(id, delivery_id)
        req("POST", "/v1/webhooks/#{Path.escape(id)}/deliveries/#{Path.escape(delivery_id)}/redeliver")
      end

      # Replace the signing secret. Takes effect immediately; the new +secret+ is returned once.
      def rotate_secret(id)
        req("POST", "/v1/webhooks/#{Path.escape(id)}/rotate-secret")
      end

      # Verify a webhook signature and return the parsed event.
      #
      # @param payload [String] the RAW request body
      # @param signature_header [String] the value of the +Quolle-Signature+ header
      # @param secret [String] your webhook signing secret (whsec_…)
      # @param tolerance [Integer] max timestamp age in seconds (replay window)
      # @raise [Quolle::Error] on a malformed header, stale timestamp, or bad signature
      # @return [Hash] the parsed event
      def verify(payload, signature_header, secret, tolerance: DEFAULT_TOLERANCE)
        parts = signature_header.to_s.split(",").each_with_object({}) do |seg, acc|
          k, v = seg.strip.split("=", 2)
          acc[k] = v if k && v
        end
        t = parts["t"]
        v1 = parts["v1"]
        raise Quolle::Error.new("Invalid Quolle-Signature header") if t.nil? || v1.nil? || t.empty? || v1.empty?

        ts = t.to_i
        if (Time.now.to_i - ts).abs > tolerance
          raise Quolle::Error.new("Webhook timestamp outside the tolerance window (possible replay)")
        end

        expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{ts}.#{payload}")
        unless secure_compare(expected, v1)
          raise Quolle::Error.new("Webhook signature verification failed")
        end

        JSON.parse(payload)
      end

      private

      # Constant-time string comparison (no timing side channel).
      def secure_compare(a, b)
        return false unless a.bytesize == b.bytesize

        l = a.unpack("C*")
        res = 0
        b.each_byte { |byte| res |= byte ^ l.shift }
        res.zero?
      end

      def req(method, path, body = nil)
        raise Quolle::Error.new("Webhooks was created without a client; use client.webhooks") unless @client

        body ? @client.request(method, path, body: body) : @client.request(method, path)
      end
    end
  end
end
