# frozen_string_literal: true

require "optparse"

require_relative "cli/runner"
require_relative "version"

module Jrf
  class CLI
    USAGE = "usage: jrf [options] 'STAGE >> STAGE >> ...'"

    def self.run(argv = ARGV, input: ARGF, out: $stdout, err: $stderr)
      verbose = false
      lax = false
      pretty = false
      jit = true
      atomic_write_bytes = Runner::DEFAULT_OUTPUT_BUFFER_LIMIT
      parser = build_option_parser(
        out: out,
        verbose: -> { verbose = true },
        lax: -> { lax = true },
        pretty: -> { pretty = true },
        no_jit: -> { jit = false },
        atomic_write_bytes: ->(value) { atomic_write_bytes = value }
      )

      result = catch(:jrf_cli_exit) do
        begin
          parser.order!(argv)
        rescue OptionParser::ParseError => e
          err.puts e.message
          err.puts USAGE
          return 1
        end
        nil
      end
      return result unless result.nil?

      if argv.empty?
        err.puts USAGE
        return 1
      end

      expression = argv.shift
      enable_yjit if jit

      inputs = Enumerator.new do |y|
        if argv.empty?
          y << input
        else
          argv.each do |path|
            if path == "-"
              y << input
            elsif path.end_with?(".gz")
              require "zlib"
              Zlib::GzipReader.open(path) do |source|
                y << source
              end
            else
              File.open(path, "rb") do |source|
                y << source
              end
            end
          end
        end
      end
      Runner.new(
        inputs: inputs,
        out: out,
        err: err,
        lax: lax,
        pretty: pretty,
        atomic_write_bytes: atomic_write_bytes
      ).run(expression, verbose: verbose)
      0
    end

    def self.build_option_parser(out:, verbose:, lax:, pretty:, no_jit:, atomic_write_bytes:)
      OptionParser.new do |opts|
        opts.banner = USAGE
        opts.summary_indent = "  "
        opts.summary_width = 29
        opts.separator ""
        opts.separator "JSON filter with the power and speed of Ruby."
        opts.separator ""
        opts.separator "Options:"
        opts.on("-v", "--verbose", "print parsed stage expressions") { verbose.call }
        opts.on("--lax", "allow multiline JSON texts; split inputs by whitespace (also detects JSON-SEQ RS 0x1e)") { lax.call }
        opts.on("-p", "--pretty", "pretty-print JSON output instead of compact NDJSON") { pretty.call }
        opts.on("--no-jit", "do not enable YJIT, even when supported by the Ruby runtime") { no_jit.call }
        opts.on("--atomic-write-bytes N", Integer, "group short outputs into atomic writes of up to N bytes") do |value|
          atomic_write_bytes.call(parse_atomic_write_bytes(value))
        end
        opts.on("-V", "--version", "show version and exit") do
          out.puts Jrf::VERSION
          throw :jrf_cli_exit, 0
        end
        opts.on("-h", "--help", "show this help and exit") do
          out.puts opts
          out.puts
          out.puts "Pipeline:"
          out.puts "  Connect stages with top-level >>."
          out.puts "  The current value in each stage is available as _."
          out.puts
          out.puts "Examples:"
          out.puts <<~TEXT.chomp
            jrf '_["foo"]'
            jrf 'select(_["x"] > 10) >> _["foo"]'
            jrf '_["items"] >> flat'
            jrf 'sort(_["at"]) >> _["id"]'
            jrf '_["msg"] >> reduce(nil) { |acc, v| acc ? "\#{acc} \#{v}" : v }'
          TEXT
          out.puts
          out.puts "See Also:"
          out.puts "  https://github.com/kazuho/jrf#readme"
          throw :jrf_cli_exit, 0
        end
      end
    end

    def self.parse_atomic_write_bytes(value)
      bytes = Integer(value, exception: false)
      return bytes if bytes && bytes.positive?

      raise OptionParser::InvalidArgument, "--atomic-write-bytes requires a positive integer"
    end

    def self.enable_yjit
      return unless defined?(RubyVM::YJIT) && RubyVM::YJIT.respond_to?(:enable)

      RubyVM::YJIT.enable
    end
  end
end
