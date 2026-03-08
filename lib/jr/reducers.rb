# frozen_string_literal: true

module Jr
  module Reducers
    module_function

    Event = Struct.new(:factory, :value, :emit_many)

    class Reduce
      def initialize(initial, finish_fn: nil, &step_fn)
        @acc = initial
        @step_fn = step_fn
        @finish_fn = finish_fn || ->(acc) { acc }
      end

      def step(value)
        @acc = @step_fn.call(@acc, value)
      end

      def finish
        @finish_fn.call(@acc)
      end
    end

    def reduce(initial, finish: nil, &step_fn)
      Reduce.new(initial, finish_fn: finish, &step_fn)
    end

    def event(value, initial:, finish: nil, emit_many: false, &step_fn)
      Event.new(-> { reduce(initial, finish: finish, &step_fn) }, value, emit_many)
    end
  end
end
