# frozen_string_literal: true

require "test_helper"

module Verquest
  class HelperClassMethodsTest < Minitest::Test
    include Base::HelperClassMethods

    def test_camelize_keeps_extension_and_dollar_keys
      options = {max_length: 1, "x-my_ext": 2, "$my_comment": 3}

      assert_equal({maxLength: 1, "x-my_ext": 2, "$my_comment": 3}, camelize(options))
    end
  end
end
