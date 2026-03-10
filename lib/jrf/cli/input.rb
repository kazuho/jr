# frozen_string_literal: true

require "zlib"

module Jrf
  class CLI
    class Input
      def initialize(paths, stdin:)
        @paths = paths.dup
        @use_stdin_only = @paths.empty?
        @stdin = stdin
        @current_source = nil
        @stdin_exhausted = false
      end

      def each_line(&block)
        each_source do |source|
          source.each_line(&block)
        end
      end

      def read(length = nil, outbuf = nil)
        return read_all(outbuf) if length.nil?

        chunk = +""
        while chunk.bytesize < length
          source = next_source
          break unless source

          part = source.read(length - chunk.bytesize)
          if part.nil? || part.empty?
            close_current_source
            next
          end

          chunk << part
        end

        return nil if chunk.empty?

        if outbuf
          outbuf.replace(chunk)
        else
          chunk
        end
      end

      private

      def read_all(outbuf)
        chunks = +""
        while (part = read(4096))
          chunks << part
        end

        if outbuf
          outbuf.replace(chunks)
        else
          chunks
        end
      end

      def each_source
        if @use_stdin_only
          yield @stdin
        else
          @paths.each do |path|
            open_source(path) do |source|
              yield source
            end
          end
        end
      end

      def next_source
        return nil if @use_stdin_only && @stdin_exhausted
        return @current_source if @current_source
        if @use_stdin_only
          @current_source = @stdin
          return @current_source
        end

        path = @paths.shift
        return nil unless path

        if path == "-"
          @current_source = @stdin
        elsif path.end_with?(".gz")
          @current_source = Zlib::GzipReader.open(path)
        else
          @current_source = File.open(path, "rb")
        end

        @current_source
      end

      def close_current_source
        if @current_source&.equal?(@stdin)
          @stdin_exhausted = true
          @current_source = nil
          return
        end
        return unless @current_source

        @current_source.close
        @current_source = nil
      end

      def open_source(path)
        if path == "-"
          yield @stdin
        elsif path.end_with?(".gz")
          Zlib::GzipReader.open(path) do |io|
            yield io
          end
        else
          File.open(path, "rb") do |io|
            yield io
          end
        end
      end
    end
  end
end
