require "../lib_c/ptrace"

module Cover
  module Memory
    extend self

    def peek_byte(pid : LibC::PidT, pointer : Void*) : UInt8
      value = peek(pid, pointer)
      byte_at(value, pointer.address % sizeof(LibC::SizeT))
    end

    private def peek(pid : LibC::PidT, pointer : Void*) : LibC::SizeT
      aligned = align(pointer)
      value = LibC.ptrace(LibC::PTRACE_PEEKTEXT, pid, aligned, nil)
      value.to_u!
    end

    def poke_byte(pid : LibC::PidT, pointer : Void*, value : UInt8) : UInt8
      original = 0_u8
      poke(pid, pointer) do |old|
        index = pointer.address % sizeof(LibC::SizeT)
        original = byte_at(old, index)
        replace_byte(old, index, value)
      end
      original
    end

    private def poke(pid : LibC::PidT, pointer : Void*, & : LibC::SizeT -> LibC::SizeT) : LibC::SizeT
      original = peek(pid, pointer)
      value = yield original
      poke(pid, pointer, value)
      original
    end

    private def poke(pid : LibC::PidT, pointer : Void*, value : LibC::SizeT) : Nil
      aligned = align(pointer)
      data = Pointer(Void).new(value)
      LibC.ptrace(LibC::PTRACE_POKETEXT, pid, aligned, data)
    end

    def align(pointer : Void*) : Void*
      address = (pointer.address // sizeof(LibC::SizeT)) * sizeof(LibC::SizeT)
      Pointer(Void).new(address)
    end

    private def byte_at(value : UInt32, index : Int32) : UInt8
      bytes = value.unsafe_as(StaticArray(UInt8, 4))
      bytes[index]
    end

    private def byte_at(value : UInt64, index : Int32) : UInt8
      bytes = value.unsafe_as(StaticArray(UInt8, 8))
      bytes[index]
    end

    private def replace_byte(value : UInt32, index : Int32, byte : UInt8) : UInt32
      bytes = value.unsafe_as(StaticArray(UInt8, 4))
      bytes[index] = byte
      bytes.unsafe_as(UInt32)
    end

    private def replace_byte(value : UInt64, index : Int32, byte : UInt8) : UInt64
      bytes = value.unsafe_as(StaticArray(UInt8, 8))
      bytes[index] = byte
      bytes.unsafe_as(UInt64)
    end
  end
end
