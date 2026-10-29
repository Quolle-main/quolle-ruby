# frozen_string_literal: true

require_relative "path"

module Quolle
  module Resources
    # API keys (+client.api_keys+). Needs a full-access key; a sending-only key
    # gets 403 +restricted_api_key+.
    class ApiKeys
      def initialize(client)
        @client = client
      end

      # @return [Array<Hash>] active keys (only a +preview+ of each key)
      def list
        @client.request("GET", "/v1/keys")["keys"] || []
      end

      # Create a key. The returned +key+ (qle_…) is shown once; store it now.
      #
      # @param scope ["full", "sending", nil] "sending" keys can only send email and read its status
      # @param domains [Array<String>, nil] limit the key to these sending domains
      # @param expires_in_days [Integer, nil] days until the key stops working
      def create(name:, scope: nil, domains: nil, expires_in_days: nil)
        body = { name: name }
        body[:scope] = scope if scope
        body[:domains] = domains if domains
        body[:expiresInDays] = expires_in_days if expires_in_days
        @client.request("POST", "/v1/keys", body: body)
      end

      # Revoke a key. Requests made with it fail from now on.
      def remove(id)
        @client.request("DELETE", "/v1/keys/#{Path.escape(id)}")
      end
    end
  end
end
