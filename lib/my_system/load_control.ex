defmodule MySystem.LoadControl do
  use Parent.GenServer

  def start_link(arg),
    do: Parent.GenServer.start_link(__MODULE__, arg, name: __MODULE__)

  def set_load(value) do
    :ets.insert(__MODULE__, {:target_load, value})
    GenServer.cast(__MODULE__, :load_changed)
    :ok
  end

  def target_load, do: get_value(:target_load)

  def set_num_schedulers(num) do
    :erlang.system_flag(:schedulers_online, num)
    :erlang.system_flag(:dirty_cpu_schedulers_online, num)
  end

  def num_schedulers,
    do: :erlang.system_info(:schedulers_online)

  def subscribe do
    Registry.register(__MODULE__.Notifications, :subscriber, nil)
    :ok
  end

  def notify(message) do
    for {pid, _value} <- Registry.lookup(__MODULE__.Notifications, :subscriber),
        do: {send(pid, message)}

    :ok
  end

  def num_points, do: 600

  @impl GenServer
  def init(_arg) do
    :ets.new(__MODULE__, [:named_table, :public, read_concurrency: true, write_concurrency: true])
    :ets.insert(__MODULE__, {:target_load, 0})

    Parent.start_child({Registry, name: __MODULE__.Notifications, keys: :duplicate})
    Parent.start_child(MySystem.LoadControl.SchedulerMonitor)

    Process.send_after(self(), :aggregate_successes, 100)

    {:ok, %{success_values: [], successes: 0, recorded_at: :erlang.monotonic_time()}}
  end

  @impl GenServer
  def handle_cast(:load_changed, state) do
    active_workers = Enum.filter(Parent.children(), &match?(%{id: {:worker, _id}}, &1))
    target_load = target_load()
    current_load = length(active_workers)
    diff = target_load - current_load

    # If diff is negative, redundant workers will stop themselves. This reduces the load on
    # the parent process.
    if diff > 0, do: Enum.each(0..(diff - 1), &start_worker(current_load + &1))

    {:noreply, state}
  end

  def handle_cast(:worker_success, state),
    do: {:noreply, %{state | successes: state.successes + 1}}

  @impl GenServer
  def handle_info(:aggregate_successes, state) do
    now = :erlang.monotonic_time()
    Process.send_after(self(), :aggregate_successes, 100)

    diff = :erlang.convert_time_unit(now - state.recorded_at, :native, :millisecond)
    success_value = state.successes * 1000 / diff
    success_values = Enum.take([success_value | state.success_values], num_points())

    notify({__MODULE__, :success_values, success_values})

    {:noreply, %{state | successes: 0, recorded_at: now, success_values: success_values}}
  end

  defp start_worker(id) do
    parent = self()

    Parent.start_child(%{
      id: {:worker, id},
      start: {Task, :start_link, [fn -> run_worker(parent, id) end]},
      restart: :transient,
      ephemeral?: true
    })
  end

  defp run_worker(parent, id) do
    Process.sleep(:rand.uniform(1000))

    Stream.repeatedly(fn ->
      _ = Enum.reduce(1..100, 0, &(&1 + &2))
      :erlang.garbage_collect()
      Process.sleep(1000)
      GenServer.cast(parent, :worker_success)
    end)
    |> Stream.take_while(fn _ -> id < target_load() end)
    |> Stream.run()
  end

  defp get_value(key) do
    [{^key, value}] = :ets.lookup(__MODULE__, key)
    value
  end
end
