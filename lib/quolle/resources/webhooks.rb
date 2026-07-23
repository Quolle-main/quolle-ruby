# frozen_string_literal: true

require "openssl"
require "json"

module Quolle
  module Resources
    # Verify that an incoming webhook really came from Quolle.
    class Webhooks
      DEFAULT_TOLERANCE = 300 # seconds

      def initialize(_client = nil); end

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
    end
  end
end
