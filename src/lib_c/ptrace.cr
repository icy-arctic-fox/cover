lib LibC
  enum PTraceRequest
    TraceMe      =  0
    PeekText     =  1
    PeekData     =  2
    PeekUser     =  3
    PokeText     =  4
    PokeData     =  5
    PokeUser     =  6
    Continue     =  7
    Kill         =  8
    SingleStep   =  9
    GetRegisters = 12
    SetRegisters = 13
    Attach       = 16
    Detach       = 17
    Syscall      = 24

    SetOptions      = 0x4200
    GetEventMessage = 0x4201
    GetSignalInfo   = 0x4202
    SetSignalInfo   = 0x4203

    # GetFpregs = 14
    # SetFpregs = 15
    # GetFpxregs = 18
    # SetFpxregs = 19
  end

  enum PTraceEvent
    Fork      =   1
    VFork     =   2
    Clone     =   3
    Exec      =   4
    VForkDone =   5
    Exit      =   6
    SecComp   =   7
    Stop      = 128
  end

  @[Flags]
  enum PTraceOption
    TraceSysGood   = 1
    TraceFork      = 1 << PTraceEvent::Fork
    TraceVFork     = 1 << PTraceEvent::VFork
    TraceClone     = 1 << PTraceEvent::Clone
    TraceExec      = 1 << PTraceEvent::Exec
    TraceVForkDone = 1 << PTraceEvent::VForkDone
    TraceExit      = 1 << PTraceEvent::Exit
    TraceSecComp   = 1 << PTraceEvent::SecComp
    TraceStop      = 1 << PTraceEvent::Stop

    ExitKill       = 1 << 20
    SuspendSecComp = 1 << 21
  end

  struct UserRegs
    r15 : UInt64
    r14 : UInt64
    r13 : UInt64
    r12 : UInt64
    rbp : UInt64
    rbx : UInt64
    r11 : UInt64
    r10 : UInt64
    r9 : UInt64
    r8 : UInt64
    rax : UInt64
    rcx : UInt64
    rdx : UInt64
    rsi : UInt64
    rdi : UInt64
    orig_rax : UInt64
    rip : UInt64
    cs : UInt64
    eflags : UInt64
    rsp : UInt64
    ss : UInt64
    fs_base : UInt64
    gs_base : UInt64
    ds : UInt64
    es : UInt64
    fs : UInt64
    gs : UInt64
  end

  fun ptrace(op : PTraceRequest, pid : PidT, addr : Void*, data : Void*) : Long
end
