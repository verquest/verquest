# frozen_string_literal: true

require "zeitwerk"
require "json-schema"

loader = Zeitwerk::Loader.new
loader.tag = File.basename(__FILE__, ".rb")
loader.push_dir(File.dirname(__FILE__))
loader.setup

module Verquest
  Error = Class.new(StandardError)
  VersionNotFound = Class.new(Verquest::Error)
  PropertyNotFound = Class.new(Verquest::Error)

  # Your code goes here...
end
