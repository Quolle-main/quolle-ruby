# frozen_string_literal: true

require_relative "quolle/version"
require_relative "quolle/error"
require_relative "quolle/client"

# Official Ruby SDK for the Quolle email API.
module Quolle
  # Convenience constructor: Quolle.new(api_key: "qle_...")
  def self.new(**kwargs)
    Client.new(**kwargs)
  end
end
