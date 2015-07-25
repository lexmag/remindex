defmodule Remindex.Server do
  require Record
  Record.defrecordp :state, events: HashDict.new, clients: HashDict.new

  def start do
    pid = spawn(__MODULE__, :init, [])
    Process.register(pid, __MODULE__)
    pid
  end

  def start_link do
    pid = spawn_link(__MODULE__, :init, [])
    Process.register(pid, __MODULE__)
    pid
  end

  def init(s \\ state), do: loop(s)

  def terminate do
    send __MODULE__, :shutdown
  end

  def subscribe(pid) do
    ref = Process.monitor Process.whereis(__MODULE__)
    send __MODULE__, { self, ref, { :subscribe, pid }}

    receive do
      { ^ref, :ok } -> :ok

      { :DOWN, ^ref, :process, _pid, reason } -> { :error, reason }
    after
      5000 -> { :error, :timeout }
    end
  end

  def add(name, moment) do
    ref = make_ref
    send __MODULE__, { self, ref, { :add, name, moment }}

    receive do
      { ^ref, message } -> message
    after
      5000 -> { :error, :timeout }
    end
  end

  def cancel(name) do
    ref = make_ref
    send __MODULE__, { self, ref, { :cancel, name }}
 

    receive do
      { ^ref, :ok } -> :ok
    after
      5000 -> { :error, :timeout }
    end
  end

  def listen(seconds) do
    receive do
      { :done, _name } = message -> [message | listen(0)]
    after
      seconds * 1000 -> []
    end
  end

  defp loop(state(events: events, clients: clients) = server) do
    receive do
      { pid, msg_ref, { :subscribe, client }} ->
        ref = Process.monitor client
        dict = Dict.put(clients, ref, client)

        send pid, { msg_ref, :ok }
        state(server, clients: dict) |> loop

      { pid, msg_ref, { :add, name, moment }} ->
        if valid_datetime? moment do
          event = Remindex.Event.start_link(name, moment)
          dict = Dict.put(events, name, event)

          send pid, { msg_ref, :ok }
          state(server, events: dict) |> loop
        else
          send pid, { msg_ref, { :error, :badmoment }}
          loop(server)
        end

      { pid, msg_ref, { :cancel, name }} ->
        { event, dict } = Dict.pop(events, name)

        if event do
          Remindex.Event.cancel(event)
        end

        send pid, { msg_ref, :ok }
        state(server, events: dict) |> loop

      { :done, name } ->
        { event, dict } = Dict.pop(events, name)

        if event do
          Enum.each clients, fn({_ref, pid}) ->
            send pid, { :done, name }
          end
        end

        state(server, events: dict) |> loop

      :shutdown -> exit(:shutdown)

      { :DOWN, ref, :process, _pid, _reason } ->
        dict = Dict.delete(clients, ref)

        state(server, clients: dict) |> loop

      :code_change -> __MODULE__.init(server)

      unknown ->
        IO.puts "Unknown message: #{inspect unknown}"
        loop(server)
    end
  end

  defp valid_datetime?({ date, time }) do
    try do
      :calendar.valid_date(date) and valid_time?(time)
    rescue
      FunctionClauseError -> false
    end
  end
  defp valid_datetime?(_), do: false

  defp valid_time?({ hours, minutes, seconds }) do
    hours in 0..23 and
    minutes in 0..59 and
    seconds in 0..59
  end
end
