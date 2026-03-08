# frozen_string_literal: true
require_relative "control"
require_relative "reducers"

module Jr
  class RowContext
    def initialize(obj = nil)
      @obj = obj
    end

    def reset(obj)
      @obj = obj
      self
    end

    def _
      @obj
    end

    def flat
      Control::Flat.new(@obj)
    end

    def sum(value, initial: 0)
      Reducers.event(value, initial: initial) { |acc, v| acc + v }
    end

    def min(value)
      Reducers.event(value, initial: nil) { |acc, v| acc.nil? || v < acc ? v : acc }
    end

    def max(value)
      Reducers.event(value, initial: nil) { |acc, v| acc.nil? || v > acc ? v : acc }
    end

    def sort(key = @obj, &compare)
      if compare
        Reducers.event(@obj, initial: [], emit_many: true, finish: ->(rows) { rows.sort(&compare) }) do |rows, row|
          rows << row
        end
      else
        Reducers.event([key, @obj], initial: [], emit_many: true, finish: ->(pairs) {
          pairs.sort_by(&:first).map(&:last)
        }) do |pairs, pair|
          pairs << pair
        end
      end
    end

    def group(value = @obj)
      Reducers.event(value, initial: []) { |acc, v| acc << v }
    end

    NO_KW = Object.new

    def reduce(*args, initial: NO_KW, &block)
      raise ArgumentError, "reduce requires a block" unless block

      value, init =
        if initial != NO_KW
          raise ArgumentError, "reduce(value, initial: ...): value is required" unless args.size == 1
          [args[0], initial]
        elsif args.size == 1
          [@obj, args[0]]
        elsif args.size == 2
          [args[0], args[1]]
        else
          raise ArgumentError, "reduce expects reduce(initial), reduce(value, initial: ...), or reduce(value, initial)"
        end

      Reducers.event(value, initial: init, &block)
    end
  end
end
