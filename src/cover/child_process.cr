module Cover
  class ChildProcess
    BREAKPOINT = 0xcc_u8
    Log        = Cover::Log.for(self)

    getter pid : LibC::PidT

    def initialize(@pid)
      @modifications = {} of Void* => UInt8
    end

    protected def initialize(@pid, modifications : Hash(Void*, UInt8))
      @modifications = modifications.dup
    end

    def continue : Nil
      Log.debug { "Continuing child process #{pid}" }
      LibC.ptrace(LibC::PTraceRequest::Continue, @pid, nil, nil)
    end

    def stop : Nil
      Log.debug { "Stopping child process #{pid}" }
      LibC.ptrace(LibC::PTraceRequest::Kill, @pid, nil, nil)
    end

    def set_breakpoint(address : Void*) : Nil
      @modifications.put_if_absent(address) do
        # Log.debug { "Setting breakpoint at 0x#{address.address.to_s(16)}" }
        puts "Setting breakpoint at 0x#{address.address.to_s(16)}"
        Memory.poke_byte(@pid, address, BREAKPOINT)
      end
    end

    def remove_breakpoint(address : Void*) : Bool
      return false unless original_byte = @modifications.delete(address)
      return false if original_byte != BREAKPOINT
      Log.debug { "Removing breakpoint at 0x#{address.address.to_s(16)}" }
      Memory.poke_byte(@pid, address, original_byte)
      true
    end

    def remove_hit_breakpoint : Bool
      return false unless remove_breakpoint(instruction_pointer)
      decrement_instruction_pointer
      true
    end

    def registers : LibC::UserRegs
      registers = LibC::UserRegs.new
      Errno.value = :none
      result = LibC.ptrace(LibC::PTraceRequest::GetRegisters, @pid, nil, pointerof(registers))
      raise RuntimeError.from_os_error("ptrace getregs", Errno.value) if result == -1
      registers
    end

    def registers=(registers : LibC::UserRegs)
      Errno.value = :none
      result = LibC.ptrace(LibC::PTraceRequest::SetRegisters, @pid, nil, pointerof(registers))
      raise RuntimeError.from_os_error("ptrace setregs", Errno.value) if result == -1
      registers
    end

    def instruction_pointer : Void*
      Pointer(Void).new(registers.rip)
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
