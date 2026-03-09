# frozen_string_literal: true

require_relative "control"
require_relative "reducers"

module Jrf
  class Stage
    class FinishValue
      def [](key)
        self
      end

      def method_missing(name, *args, &block)
        self
      end

      def respond_to_missing?(name, include_private = false)
        true
      end
    end

    FinishedRows = Struct.new(:rows)
    FINISH_VALUE = FinishValue.new

    attr_reader :method_name, :src

    def initialize(ctx, method_name, src: nil)
      @ctx = ctx
      @method_name = method_name
      @src = src
      @reducers = []
      @cursor = 0
      @used_reducer = false
      @finishing = false
    end

    def call(input)
      @ctx.reset(input)
      @cursor = 0
      @used_reducer = false
      @finishing = false
      @ctx.__jrf_current_stage = self
      result = @ctx.public_send(@method_name)

      @used_reducer ? Control::DROPPED : result
    end

    def allocate_reducer(value, initial:, finish: nil, &step_fn)
      idx = @cursor
      if @finishing
        @cursor += 1
        rows = @reducers.fetch(idx).finish
        return rows.length == 1 ? rows.first : FinishedRows.new(rows)
      end

      finish_rows = finish || ->(acc) { [acc] }
      @reducers[idx] ||= Reducers.reduce(initial, finish: finish_rows, &step_fn)
      @reducers[idx].step(value)
      @used_reducer = true
      @cursor += 1
      nil
    end

    def allocate_map(type, collection, &block)
      idx = @cursor
      map_reducer = (@reducers[idx] ||= MapReducer.new(type))

      if @finishing
        result = map_reducer.finish(type) do |slot|
          if slot.empty?
            slot.value
          else
            with_scoped_reducers(slot.reducers, finishing: true) { block.call(FINISH_VALUE) }
          end
        end
        @cursor += 1
        return result
      end

      result =
        case type
        when :array
          raise TypeError, "map expects Array, got #{collection.class}" unless collection.is_a?(Array)
          collection.each_with_index.map do |v, i|
            slot = map_reducer.slot(i)
            slot_result, reducer_used = with_scoped_reducers(slot.reducers) { block.call(v) }
            slot.value = slot_result unless reducer_used
            reducer_used ? nil : slot.value
          end
        when :hash
          raise TypeError, "map_values expects Hash, got #{collection.class}" unless collection.is_a?(Hash)
          collection.each_with_object({}) do |(k, v), acc|
            slot = map_reducer.slot(k)
            slot_result, reducer_used = with_scoped_reducers(slot.reducers) { block.call(v) }
            slot.value = slot_result unless reducer_used
            acc[k] = reducer_used ? nil : slot.value
          end
        end

      @cursor += 1
      result
    end

    def allocate_group_by(key, &block)
      idx = @cursor
      map_reducer = (@reducers[idx] ||= MapReducer.new(:hash))

      if @finishing
        result = map_reducer.finish(:hash) do |slot|
          with_scoped_reducers(slot.reducers, finishing: true) { block.call(FINISH_VALUE) }
        end
        @cursor += 1
        return result
      end

      row = @ctx._
      slot = map_reducer.slot(key)
      result, reducer_used = with_scoped_reducers(slot.reducers) { block.call(row) }
      slot.value = result unless reducer_used
      @used_reducer = true
      @cursor += 1
      nil
    end

    def reducer?
      @reducers.any? { |reducer| !reducer.empty? }
    end

    def finish
      return [] unless reducer?

      @ctx.reset(FINISH_VALUE)
      @cursor = 0
      @finishing = true
      @ctx.__jrf_current_stage = self
      result = @ctx.public_send(@method_name)
      rows = result.is_a?(FinishedRows) ? result.rows : [result]
      @reducers = []
      rows
    ensure
      @finishing = false
    end

    private

    def with_scoped_reducers(reducer_list, finishing: false)
      saved_reducers = @reducers
      saved_cursor = @cursor
      saved_used_reducer = @used_reducer
      saved_finishing = @finishing
      @reducers = reducer_list
      @cursor = 0
      @finishing = finishing
      if finishing
        yield
      else
        @used_reducer = false
        result = yield
        reducer_used = @used_reducer
        [result, reducer_used]
      end
    ensure
      @reducers = saved_reducers
      @cursor = saved_cursor
      @used_reducer = finishing ? saved_used_reducer : (saved_used_reducer || reducer_used)
      @finishing = saved_finishing
    end

    class MapReducer
      def initialize(type)
        @type = type
        @slots = {}
      end

      def slot(key)
        @slots[key] ||= SlotState.new
      end

      def empty?
        @slots.empty? || @slots.values.all?(&:empty?)
      end

      def finish(type)
        case @type
        when :array
          keys = @slots.keys.sort
          keys.map { |k| yield @slots.fetch(k) }
        when :hash
          result = {}
          @slots.each { |k, slot| result[k] = yield slot }
          result
        end
      end

      class SlotState
        attr_reader :reducers
        attr_accessor :value

        def initialize
          @reducers = []
        end

        def empty?
          @reducers.empty?
        end
      end
    end
  end
end
