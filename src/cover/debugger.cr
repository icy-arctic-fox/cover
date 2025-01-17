require "../lib_c/ptrace"
require "../lib_c/wait"
require "./child_process"
require "./debug_symbols"

module Cover
  class Debugger
    Log = Cover::Log.for(self)

    @children = [] of ChildProcess

    def initialize(child_pid : LibC::PidT)
      @children << ChildProcess.new(child_pid)
    end

    def self.run(executable : String, args = nil, &)
      symbols = DebugSymbols.load(executable)
      pid = exec_tracee(executable, args)
      debugger = new(pid)
      begin
        debugger.start
        symbols.each do |symbol|
          address = Pointer(Void).new(symbol.low_pc.to_u64!)
          debugger.add_breakpoint(address)
        end
        debugger.run { |child, type| yield child, type }
      ensure
        debugger.stop
      end
    end

    private def self.exec_tracee(executable : String, args)
      pid = Crystal::System::Process.fork(will_exec: true)
      return pid if pid # Parent returns

      LibC.ptrace(LibC::PTraceRequest::TraceMe, 0, nil, nil)
      Process.exec(executable, args)
      exit 127 # Unreachable
    end

    def run(&)
      advance

      until @children.empty?
        # Log.trace { "Waiting for next event" }
        puts "Waiting for next event"
        active_pid = LibC.waitpid(-1, out status, LibC::WaitArg::All)
        raise "waitpid failed: #{active_pid}" if active_pid == -1

        # Log.trace { "Child #{active_pid} produced status #{status}" }
        puts "Child #{active_pid} produced status #{status}"
        child = @children.find { |child| child.pid == active_pid }
        raise "Debugger got unexpected child #{active_pid}" unless child

        if LibC::Wait.stopped?(status)
          if LibC::Wait.stop_signal(status) == Signal::TRAP.value
            Log.debug { "Child #{child} hit a breakpoint" }
            yield child, :trap
          else
            signal = Signal.new(LibC::Wait.stop_signal(status))
            Log.debug { "Forwarding signal #{signal} to child #{child}" }
            data = Pointer(Void).new(signal.value)
            LibC.ptrace(LibC::PTraceRequest::Continue, child.pid, nil, data)
            next
          end
        end

        if LibC::Wait.signaled?(status) || LibC::Wait.exited?(status)
          Log.debug { "Child #{child} exited" }
          yield child, :exit
          @children.delete(child)
          next
        end

        if LibC::Wait.stopped?(status)
          Log.debug { "Child #{child} stopped for an unknown reason, continuing" }
          child.continue
          next
        end

        raise "Debugger got unexpected status #{status}"
      end
    end

    private def child
      @children.first { raise "Debugger already finished" }
    end

    def add_breakpoint(address : Void*)
      child.set_breakpoint(address)
    end

    def start : Nil
      Log.info { "Starting debugger for #{child}" }

      # Wait for the child to reach the initial stop.
      result = LibC.waitpid(child.pid, out status, 0)
      raise "waitpid failed: #{result}" if result == -1 || !LibC::Wait.stopped?(status)
      # Log.debug { "Child #{child} ready" }
      puts "Child #{child} ready"

      # Enable tracing of grandchildren.
      options = Pointer(Void).new(LibC::PTraceOption::TraceClone.value.to_u64)
      LibC.ptrace(LibC::PTraceRequest::SetOptions, child.pid, nil, options)
      # Log.debug { "Child #{child} tracing enabled" }
      puts "Child #{child} tracing enabled"
    end

    def stop
      @children.each &.stop
      @children.clear
    end

    def advance
      @children.each &.continue
    end
  end
end
