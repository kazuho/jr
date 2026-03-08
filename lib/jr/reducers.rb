# frozen_string_literal: true

module Jr
  module Reducers
    module_function

    Event = Struct.new(:factory, :value)

    class Reduce
      def initialize(initial, &step_fn)
        @acc = initial
        @step_fn = step_fn
      end

      def step(value)
        @acc = @step_fn.call(@acc, value)
      end

      def finish
        @acc
      end
    end

    def reduce(initial, &step_fn)
      Reduce.new(initial, &step_fn)
    end

    def event(value, initial:, &step_fn)
      Event.new(-> { reduce(initial, &step_fn) }, value)
    end

    def sum_event(value, initial: 0)
      event(value, initial: initial) { |acc, v| acc + v }
    end

    def min_event(value)
      event(value, initial: nil) { |acc, v| acc.nil? || v < acc ? v : acc }
    end

    def max_event(value)
      event(value, initial: nil) { |acc, v| acc.nil? || v > acc ? v : acc }
    end
  end
end
