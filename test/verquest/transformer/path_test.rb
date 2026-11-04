# frozen_string_literal: true

require "test_helper"

module Verquest
  class Transformer
    class PathTest < Minitest::Test
      NOT_FOUND = Path::NOT_FOUND

      def test_extract
        data = {"user" => {"name" => "A", "site" => nil}, "users" => [{"name" => "B"}, {}], "count" => 1}

        cases = {
          "user/name" => "A",
          "user/missing" => NOT_FOUND,
          "users[]/name" => ["B", NOT_FOUND],
          "users/name" => ["B", NOT_FOUND],
          "count/value" => NOT_FOUND,
          "user/site/id" => NOT_FOUND,
          "" => data
        }

        assert_equal cases, cases.to_h { |path, _| [path, Path.new(path).extract(data)] }
      end

      def test_extract_returns_null_parent_below_an_explicit_null
        data = {"user" => {"site" => nil}, "items" => [{"meta" => nil}]}

        cases = {
          "user/site/id" => Path::NullParent.new(1),
          "user/site/owner/id" => Path::NullParent.new(2),
          "items[]/meta/note" => [Path::NullParent.new(1)],
          "user/site" => nil
        }

        assert_equal cases, cases.to_h { |path, _| [path, Path.new(path).extract(data, nulls: true)] }
      end

      def test_set
        cases = {
          ["user/name", "A"] => {"user" => {"name" => "A"}},
          ["users[]/name", ["A", NOT_FOUND]] => {"users" => [{"name" => "A"}, {}]},
          ["user/site_id", Path::NullParent.new(1)] => {"user" => nil},
          ["user/site/id", Path::NullParent.new(1)] => {"user" => {"site" => nil}},
          ["site_id", Path::NullParent.new(2)] => {"site_id" => nil}
        }

        assert_equal cases.values, cases.keys.map { |(path, value)| Path.new(path).set({}, value) }
      end

      def test_set_null_parent_keeps_an_existing_value
        result = {"user" => {"site" => {"id" => "1"}}}

        assert_equal({"user" => {"site" => {"id" => "1"}}}, Path.new("user/site/name").set(result, Path::NullParent.new(1)))
      end
    end
  end
end
