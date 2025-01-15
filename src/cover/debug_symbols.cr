# Crystal's call stack processing is heavily referenced for this code.
# See: https://github.com/crystal-lang/crystal/blob/master/src/exception/call_stack/elf.cr
# and: https://github.com/crystal-lang/crystal/blob/master/src/exception/call_stack/dwarf.cr

require "crystal/dwarf"
require "string_pool"

{% if flag?(:win32) %}
  require "crystal/pe"
{% else %}
  require "crystal/elf"
{% end %}

module Cover
  record DebugSymbol,
    symbol : String,
    path : String,
    line : Int64,
    low_pc : LibC::SizeT,
    high_pc : LibC::SizeT

  class DebugSymbols
    include Enumerable(DebugSymbol)

    Log = Cover::Log.for(self)

    def initialize(@symbols : Array(DebugSymbol))
      # Symbols must be sorted by low PC for binary search.
      @symbols.sort_by! { |s| s.low_pc }
    end

    def at_pc?(pc : LibC::SizeT) : DebugSymbol?
      @symbols.bsearch { |s| s.low_pc >= pc }
    end

    def each(& : T ->)
      @symbols.each { |s| yield s }
    end

    def size
      @symbols.size
    end

    def self.load(file : String)
      # TODO: Win32 isn't fully supported.
      base_address = 0_u64
      {{ flag?(:win32) ? Crystal::PE : Crystal::ELF }}.open(file) do |image|
        {% if flag?(:win32) %}
          Log.debug { "Processing PE file #{file}" }
          base_address -= image.original_image_base
        {% else %}
          Log.debug { "Processing ELF file #{file}" }
        {% end %}

        strings = image.read_section?(".debug_str") do |sh, io|
          Log.debug { "Loading section .debug_str at 0x#{sh.offset.to_s(16)} - #{sh.size} bytes" }
          Crystal::DWARF::Strings.new(io, sh.offset, sh.size)
        end

        line_strings = image.read_section?(".debug_line_str") do |sh, io|
          Log.debug { "Loading section .debug_line_str at 0x#{sh.offset.to_s(16)} - #{sh.size} bytes" }
          Crystal::DWARF::Strings.new(io, sh.offset, sh.size)
        end

        line_numbers = image.read_section?(".debug_line") do |sh, io|
          Log.debug { "Loading section .debug_line at 0x#{sh.offset.to_s(16)} - #{sh.size} bytes" }
          Crystal::DWARF::LineNumbers.new(io, sh.size, 0, strings, line_strings)
        end

        symbols = [] of DebugSymbol
        pool = StringPool.new

        image.read_section?(".debug_info") do |sh, io|
          Log.debug { "Loading section .debug_info at 0x#{sh.offset.to_s(16)} - #{sh.size} bytes" }

          while (offset = io.pos - sh.offset) < sh.size
            info = Crystal::DWARF::Info.new(io, offset)
            image.read_section?(".debug_abbrev") do |sh, io|
              Log.debug { "Loading section .debug_abbrev at 0x#{sh.offset.to_s(16)} - #{sh.size} bytes" }
              info.read_abbreviations(io)
            end

            info.each do |code, abbrev, attributes|
              next unless abbrev && abbrev.tag.subprogram?
              name = low_pc = high_pc = nil

              attributes.each do |(at, form, value)|
                case at
                when Crystal::DWARF::AT::DW_AT_name
                  value = case form
                          when .strp?      then strings.try &.decode(value.as(UInt32 | UInt64))
                          when .line_strp? then line_strings.try &.decode(value.as(UInt32 | UInt64))
                          end
                  name = value.as(String)
                when Crystal::DWARF::AT::DW_AT_low_pc
                  low_pc = value.as(LibC::SizeT)
                when Crystal::DWARF::AT::DW_AT_high_pc
                  if form.addr?
                    high_pc = value.as(LibC::SizeT)
                  elsif value.responds_to?(:to_i)
                    high_pc = low_pc.as(LibC::SizeT) + value.to_i
                  end
                end
              end

              if low_pc && high_pc && name
                if ln = line_numbers
                  if row = ln.find(low_pc)
                    name = pool.get(name)
                    path = pool.get(row.path)
                    line = row.line

                    Log.trace { "Found symbol #{name} at #{path}:#{line}" }
                    symbols << DebugSymbol.new(name, path, line, low_pc, high_pc)
                  end
                end
              end
            end
          end
        end

        new(symbols)
      end
    end
  end
end
