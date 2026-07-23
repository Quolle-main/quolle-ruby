# frozen_string_literal: true

module Quolle
  # Raised when the Quolle API returns a non-2xx response, or a request could
  # not be completed (network/timeout).
  class Error < StandardError
    # @return [Integer, nil] HTTP status code, or nil for transport failures.
    attr_reader :status_code
    # @return [Hash] extra fields returned alongside +error+.
    attr_reader :data

    def initialize(message, status_code: nil, data: {})
      super(message)
      @status_code = status_code
      @data = data || {}
    end
  end
end
