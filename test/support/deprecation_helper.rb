# frozen_string_literal: true

module Verquest
  # Runs a block with Ruby deprecation warnings turned off, then restores them.
  # Not safe for parallel tests: Warning[:deprecated] is global.
  module DeprecationHelper
    module_function

    def without_deprecation_warnings
      deprecated = Warning[:deprecated]
      Warning[:deprecated] = false
      yield
    ensure
      Warning[:deprecated] = deprecated
    end
  end
end
