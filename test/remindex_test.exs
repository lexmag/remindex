Code.require_file "../test_helper.exs", __ENV__.file

defmodule RemindexTest do
  use ExUnit.Case

  defp datetime_from_now(seconds) do
    now = :calendar.local_time

    :calendar.datetime_to_gregorian_seconds(now) + seconds
      |> :calendar.gregorian_seconds_to_datetime
  end

  defp refute_raise(_, function), do: function.()

  defp with(options \\ [], function) do
    pid = Remindex.start

    :timer.sleep(10)

    if :subscribe in options do
      Remindex.subscribe(self)
    end

    if :silence in options do
      { _, null } = File.open("/dev/null", [:write])
      Process.group_leader(null, pid)
    end

    function.()

    Remindex.terminate

    :timer.sleep(10)
  end

  test "adds event" do
    with fn ->
      assert Remindex.add("Test", :calendar.local_time) == :ok
    end
  end

  test "doesn't notify if there are no subscribes" do
    with fn ->
      Remindex.add("Test", datetime_from_now(1))

      refute_receive { :done, "Test" }, 1_100
    end
  end

  test "notifies subscribers of an event" do
    with [:subscribe], fn ->
      Remindex.add("Test", datetime_from_now(1))

      assert_receive { :done, "Test" }, 1_100
    end
  end

  test "accepts distant future events" do
    with fn ->
      distant_future = datetime_from_now(50 * 24 * 60 * 60 * 1_000)

      refute_raise :timeout_value, fn ->
        Remindex.add("Test", distant_future)
      end
    end
  end

  test "listens to upcoming events" do
    with [:subscribe], fn ->
      Enum.each 0..1, fn(x) -> Remindex.add("Test", datetime_from_now(x)) end

      :timer.sleep(2_000)

      assert Remindex.listen(5) == [done: "Test", done: "Test"]
    end
  end

  test "cancels event" do
    with [:subscribe], fn ->
      Remindex.add("Test", datetime_from_now(1))

      assert Remindex.cancel("Test") == :ok

      refute_receive { :done, "Test" }, 1_100
    end
  end

  test "restarts server" do
    with [:subscribe, :silence], fn ->
      Process.exit Process.whereis(Remindex.Server), :die

      :timer.sleep(10)

      assert is_pid(Process.whereis(Remindex.Server))
    end
  end
end
