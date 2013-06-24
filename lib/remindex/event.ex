defmodule Remindex.Event do
  defrecordp :state, [:server, :name, :delay]

  def start(name, moment) do
    spawn(__MODULE__, :init, [self, name, moment])
  end

  def start_link(name, moment) do
    spawn_link(__MODULE__, :init, [self, name, moment])
  end

  def cancel(pid) do
    ref = Process.monitor(pid)
    pid <- { self, ref, :cancel }

    receive do
      { ^ref, :ok } ->
        Process.demonitor(ref, [:flush])
        :ok

      { :DOWN, ^ref, :process, ^pid, _reason } -> :ok
    end
  end

  def init(server, name, moment) do
    state(server: server, name: name, delay: to_delay(moment)) |> loop
  end

  defp loop(state(server: server, delay: [current | left]) = event) do
    receive do
      { ^server, ref, :cancel } -> server <- { ref, :ok }
    after
      current * 1000 ->
        if left == [] do
          server <- { :done, state(event, :name) }
        else
          state(event, delay: left) |> loop
        end
    end
  end

  defp to_delay({{_, _, _}, {_, _, _}} = moment) do
    now = :calendar.local_time

    :calendar.datetime_to_gregorian_seconds(moment) -
      :calendar.datetime_to_gregorian_seconds(now)
      |> normalize
  end

  @limitation 49 * 24 * 60 * 60

  defp normalize(seconds) do
    if seconds > 0 do
      [rem(seconds, @limitation) | List.duplicate(@limitation, div(seconds, @limitation))]
    else
      [0]
    end
  end
end
