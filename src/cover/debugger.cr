require "../lib_c/ptrace"
require "../lib_c/wait"
require "./child_process"

module Cover
  class Debugger
    Log = Cover::Log.for(self)

    @children = [] of ChildProcess

    def initialize(child_pid : LibC::PidT)
      @children << ChildProcess.new(child_pid)
    end

    def self.run(executable : String, args = nil, &)
      pid = exec_tracee(executable, args)
      debugger = new(pid)
      begin
        debugger.start
        debugger.run { yield }
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
      yield
    end

    def start : Nil
      child = @children.first { raise "Debugger already finished" }
      Log.info { "Starting debugger for #{child}" }

      # Wait for the child to reach the initial stop.
      result = LibC.waitpid(child.pid, out status, 0)
      raise "waitpid failed: #{result}" if result == -1 || !LibC::Wait.stopped?(status)
      Log.debug { "Child #{child} ready" }

      # Enable tracing of grandchildren.
      options = Pointer(Void).new(LibC::PTraceOption::TraceClone.value.to_u64)
      LibC.ptrace(LibC::PTraceRequest::SetOptions, child.pid, nil, options)
      Log.debug { "Child #{child} tracing enabled" }
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
