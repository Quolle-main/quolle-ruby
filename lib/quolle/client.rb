# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

require_relative "version"
require_relative "error"
require_relative "resources/emails"
require_relative "resources/webhooks"

module Quolle
  # The Quolle API client.
  #
  #   quolle = Quolle::Client.new(api_key: "qle_...")
  #   result = quolle.emails.send(
  #     from: "hello@mail.yourdomain.com",
  #     to: "customer@example.com",
  #     subject: "Welcome!",
  #     html: "<h1>Thanks for signing up</h1>"
  #   )
  #   puts result["id"]
  class Client
    DEFAULT_BASE_URL = "https://api.quolle.com"

    # @return [Quolle::Resources::Emails]
    attr_reader :emails
    # @return [Quolle::Resources::Webhooks]
    attr_reader :webhooks

    # @param api_key [String, nil] your API key (falls back to QUOLLE_API_KEY)
    # @param base_url [String]
    # @param timeout [Integer] per-request timeout in seconds
    # @param max_retries [Integer] retries for transient failures (default 3)
    def initialize(api_key: nil, base_url: DEFAULT_BASE_URL, timeout: 30, max_retries: 3)
      @api_key = api_key || ENV["QUOLLE_API_KEY"]
      raise ArgumentError, "A Quolle API key is required (pass api_key: or set QUOLLE_API_KEY)" if @api_key.nil? || @api_key.empty?

      @base_url = base_url.sub(%r{/+\z}, "")
      @timeout = timeout
      @max_retries = max_retries
      @emails = Resources::Emails.new(self)
      @webhooks = Resources::Webhooks.new(self)
    end

    # Perform an authenticated request and return the parsed JSON body.
    #
    # Transient failures (HTTP 429 and 5xx, plus network errors) are retried with
    # exponential backoff, honoring Retry-After on 429. To avoid double-sending, a
    # POST is only retried on a 5xx/network error when an Idempotency-Key is
    # present; a 429 (never processed) is always safe to retry.
    #
    # @raise [Quolle::Error] on a non-2xx response or transport failure after retries
    # @return [Hash]
    def request(method, path, body: nil, headers: {})
      uri = URI.parse("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      klass = {
        "GET" => Net::HTTP::Get,
        "POST" => Net::HTTP::Post,
        "DELETE" => Net::HTTP::Delete
      }.fetch(method.upcase)

      idempotent = %w[GET DELETE].include?(method.upcase)
      has_idem = headers.keys.any? { |k| k.to_s.downcase == "idempotency-key" }

      last_error = nil
      (0..@max_retries).each do |attempt|
        req = klass.new(uri.request_uri)
        req["Authorization"] = "Bearer #{@api_key}"
        req["Content-Type"] = "application/json"
        req["Accept"] = "application/json"
        req["User-Agent"] = "quolle-ruby/#{Quolle::VERSION}"
        headers.each { |k, v| req[k] = v }
        req.body = JSON.generate(body) unless body.nil?

        begin
          resp = http.request(req)
        rescue StandardError => e
          last_error = Quolle::Error.new("Network error: #{e.message}")
          if attempt < @max_retries && (idempotent || has_idem)
            sleep(backoff(attempt, nil))
            next
          end
          raise last_error
        end

        parsed = resp.body.to_s.empty? ? {} : (JSON.parse(resp.body) rescue {})
        status = resp.code.to_i

        if (200..299).cover?(status)
          return parsed
        end

        message = parsed.delete("error") || "Request failed with status #{status}"
        last_error = Quolle::Error.new(message, status_code: status, data: parsed)
        retryable = status == 429 || ((500..504).cover?(status) && (idempotent || has_idem))
        if attempt < @max_retries && retryable
          sleep(backoff(attempt, resp["Retry-After"]))
          next
        end
        raise last_error
      end

      raise(last_error || Quolle::Error.new("Request failed"))
    end

    private

    # Seconds to wait before the next retry: Retry-After if given, else
    # exponential backoff (0.5, 1, 2, …) capped at 8s, with jitter.
    def backoff(attempt, retry_after)
      if retry_after && retry_after.to_s =~ /\A\d+\z/
        return retry_after.to_i
      end

      [0.5 * (2**attempt), 8.0].min + rand * 0.25
    end
  end
end
