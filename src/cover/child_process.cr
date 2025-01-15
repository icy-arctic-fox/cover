module Cover
  class ChildProcess
    Log = Cover::Log.for(self)

    getter pid : LibC::PidT

    def initialize(@pid)
      @modifications = {} of Void* => UInt8
    end

    protected def initialize(@pid, modifications : Hash(Void*, UInt8))
      @modifications = modifications.dup
    end

    def continue
      Log.debug { "Continuing child process #{pid}" }
      LibC.ptrace(LibC::PTraceRequest::Continue, @pid, nil, nil)
    end

    def stop
      Log.debug { "Stopping child process #{pid}" }
      LibC.ptrace(LibC::PTraceRequest::Kill, @pid, nil, nil)
    end

    def set_breakpoint(address : Void*) : Nil
      @modifications.put_if_absent do
        original_byte = Memory.peek_byte(@pid, address)
        Memory.poke_byte(@pid, address, 0xcc)
        original_byte
      end
    end

    def remove_breakpoint(address : Void*) : Bool
      return false unless original_byte = @modifications.delete(address)
      Memory.poke_byte(@pid, address, original_byte)
      true
    end

    def remove_hit_breakpoint(address : Void*) : Bool
      return false unless remove_breakpoint(address)
      decrement_instruction_pointer
      true
    end

    def registers : LibC::UserRegs
      registers = LibC::UserRegs.new
      LibC.ptrace(LibC::PTRACE_GETREGS, @pid, nil, pointerof(registers))
      registers
    end

    def registers=(registers : LibC::UserRegs)
      LibC.ptrace(LibC::PTRACE_SETREGS, @pid, nil, pointerof(registers))
      registers
    end

    private def decrement_instruction_pointer
      registers = self.registers
      registers.rip -= 1
      self.registers = registers
    end

    def to_s(io : IO) : Nil
      io << pid
    end
  end
end
