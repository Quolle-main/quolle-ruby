# frozen_string_literal: true

module Quolle
  module Resources
    # Send and manage emails.
    class Emails
      def initialize(client)
        @client = client
      end

      # Queue an email for immediate or scheduled delivery.
      #
      # Provide either +:html+ (with +:subject+) or a +:template+ slug (with
      # optional +:variables+). Pass +idempotency_key:+ to make retries safe.
      # +type:+ (or +message_type:+) is "transactional" (default) or
      # "marketing"; marketing mail gets unsubscribe headers and honours
      # unsubscribes.
      #
      # @param params [Hash] from:, to:, subject:, html:, text:, template:,
      #   variables:, reply_to:/replyTo:, scheduled_at:/scheduledAt:, metadata:,
      #   attachments:, type:
      # @return [Hash] at least "id" and "message"
      def create(idempotency_key: nil, **params)
        headers = idempotency_key ? { "Idempotency-Key" => idempotency_key } : {}
        @client.request("POST", "/v1/emails/send", body: normalize(params), headers: headers)
      end

      # Same as {#create}. Kept because it's the documented name; note that it
      # shadows Object#send on this object, so prefer +create+ in new code
      # (and +public_send+ / +__send__+ for dynamic dispatch).
      def send(idempotency_key: nil, **params)
        create(idempotency_key: idempotency_key, **params)
      end

      # Send up to 100 emails in one all-or-nothing request.
      #
      # @param emails [Array<Hash>]
      # @return [Hash] { "queued" => Integer, "ids" => Array<String> }
      def send_batch(emails, idempotency_key: nil)
        headers = idempotency_key ? { "Idempotency-Key" => idempotency_key } : {}
        body = { emails: emails.map { |e| normalize(e) } }
        @client.request("POST", "/v1/emails/batch", body: body, headers: headers)
      end

      # Retrieve a single email by ID.
      # @return [Hash]
      def get(id)
        resp = @client.request("GET", "/v1/emails/#{escape(id)}")
        resp["email"] || resp
      end

      # Cancel a scheduled email that has not yet been sent.
      # @return [Hash]
      def cancel(id)
        @client.request("DELETE", "/v1/emails/#{escape(id)}/cancel")
      end

      private

      # Accept Ruby-idiomatic snake_case keys and map them to the API's
      # camelCase where they differ. Existing camelCase keys pass through.
      def normalize(params)
        out = {}
        params.each do |key, value|
          k = key.to_s
          k = "replyTo" if k == "reply_to"
          k = "scheduledAt" if k == "scheduled_at"
          k = "type" if k == "message_type"
          out[k] = value
        end
        out
      end

      # Path-segment encoding. (encode_www_form_component turned a space into
      # "+", which is a literal plus in a URL path.)
      def escape(id)
        id.to_s.b.gsub(/[^A-Za-z0-9\-._~]/) { |ch| format("%%%02X", ch.ord) }
      end
    end
  end
end
