# frozen_string_literal: true

require_relative "control"
require_relative "row_context"
require_relative "stage"

module Jrf
  class Pipeline
    def initialize(*blocks)
      raise ArgumentError, "at least one stage block is required" if blocks.empty?

      @ctx = RowContext.new
      @stages = blocks.map { |block| Stage.new(@ctx, block: block) }
    end

    def call(input)
      output = []
      input.each { |value| process_value(value, @stages, output) }
      flush_reducers(@stages, output)
      output
    end

    private

    def process_value(input, stages, output)
      current_values = [input]

      stages.each do |stage|
        next_values = []

        current_values.each do |value|
          out = stage.call(value)
          if out.equal?(Control::DROPPED)
            next
          elsif out.is_a?(Control::Flat)
            unless out.value.is_a?(Array)
              raise TypeError, "flat expects Array, got #{out.value.class}"
            end
            next_values.concat(out.value)
          else
            next_values << out
          end
        end

        return if next_values.empty?
        current_values = next_values
      end

      output.concat(current_values)
    end

    def flush_reducers(stages, output)
      stages.each_with_index do |stage, idx|
        rows = stage.finish
        next if rows.empty?

        rest = stages.drop(idx + 1)
        rows.each { |value| process_value(value, rest, output) }
      end
    end
  end
end
