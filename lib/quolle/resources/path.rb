# frozen_string_literal: true

module Quolle
  module Resources
    # Path-segment encoding shared by the resources.
    module Path
      module_function

      def escape(id)
        id.to_s.b.gsub(/[^A-Za-z0-9\-._~]/) { |ch| format("%%%02X", ch.ord) }
      end
    end
  end
end
