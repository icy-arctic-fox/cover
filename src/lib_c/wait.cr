module LibC::Wait
  extend self

  STOPPED   =   0x7f
  CONTINUED = 0xffff
  CORE_DUMP =   0x80

  # Equivalent to _WSTATUS
  private def status(x)
    x & 0xff
  end

  # Equivalent to WIFSTOPPED
  def stopped?(x)
    status(x) == STOPPED
  end

  # Equivalent to WSTOPSIG
  def stop_signal(x)
    (x >> 8) & 0xff
  end

  # Equivalent to WIFSIGNALED
  def signaled?(x)
    status(x) != STOPPED && status(x) != 0
  end

  # Equivalent to WTERMSIG
  def termination_signal(x)
    status(x)
  end

  # Equivalent to WIFEXITED
  def exited?(x)
    status(x) == 0
  end

  # Equivalent to WEXITSTATUS
  def exit_status(x)
    (x >> 8).to_u8!
  end

  # Equivalent to WIFCONTINUED
  def continued?(x)
    (status(x) & CONTINUED) == CONTINUED
  end

  # Equivalent to WCOREDUMP
  def core_dump?(x)
    (status(x) & CORE_DUMP) == CORE_DUMP
  end
end
