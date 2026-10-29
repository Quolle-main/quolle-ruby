# frozen_string_literal: true

require_relative "path"

module Quolle
  module Resources
    # Sending domains (+client.domains+). Needs a full-access API key.
    class Domains
      def initialize(client)
        @client = client
      end

      # @return [Array<Hash>] every sending domain, with verification and warm-up state
      def list
        @client.request("GET", "/v1/domains")["domains"] || []
      end

      # Add a domain (e.g. "mail.example.com").
      # @return [Hash] +domain+ and the +dnsRecords+ to publish
      def create(domain)
        @client.request("POST", "/v1/domains", body: { domain: domain })
      end

      # @return [Hash] one domain
      def get(id)
        @client.request("GET", "/v1/domains/#{Path.escape(id)}")["domain"]
      end

      # @return [Hash] the DNS records to publish, and which are found
      def records(id)
        @client.request("GET", "/v1/domains/#{Path.escape(id)}/records")
      end

      # Check DNS again now instead of waiting for the next automatic check.
      def verify(id)
        @client.request("POST", "/v1/domains/#{Path.escape(id)}/recheck")
      end

      # Remove a domain. Mail can no longer be sent from it.
      def remove(id)
        @client.request("DELETE", "/v1/domains/#{Path.escape(id)}")
      end
    end
  end
end
