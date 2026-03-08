# frozen_string_literal: true

module Jrf
  module Control
    Flat = Struct.new(:value)
    DROPPED = Object.new.freeze
  end
end
