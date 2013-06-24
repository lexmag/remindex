defmodule Remindex.Supervisor do
  def start do
    spawn(__MODULE__, :init, [])
  end

  def start_link do
    spawn_link(__MODULE__, :init, [])
  end

  def init do
    Process.flag(:trap_exit, true)
    loop
  end

  defp loop do
    pid = Remindex.Server.start_link

    receive do
      { :EXIT, _from, :shutdown } -> exit(:shutdown)

      { :EXIT, ^pid, reason } ->
        IO.puts "Process #{inspect pid} exited for reason #{inspect reason}"
        loop
    end
  end
end
