# frozen_string_literal: true

require_relative "jrf/version"
require_relative "jrf/cli"
require_relative "jrf/pipeline"

module Jrf
  def self.new(*blocks)
    Pipeline.new(*blocks)
  end
end
