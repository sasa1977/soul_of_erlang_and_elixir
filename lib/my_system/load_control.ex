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

  @impl GenServer
  def init(_arg) do
    :ets.new(__MODULE__, [:named_table, :public, read_concurrency: true, write_concurrency: true])
    :ets.insert(__MODULE__, {:target_load, 0})

    Parent.start_child({Registry, name: __MODULE__.Notifications, keys: :duplicate})
    Parent.start_child(MySystem.LoadControl.SchedulerMonitor)

    {:ok, nil}
  end

  @impl GenServer
  def handle_cast(:load_changed, state) do
    active_workers = Enum.filter(Parent.children(), &match?(%{id: {:worker, _id}}, &1))
    target_load = target_load()
    current_load = length(active_workers)
    diff = target_load - current_load

    cond do
      diff == 0 ->
        :ok

      diff > 0 ->
        Enum.each(0..(diff - 1), &start_worker(current_load + &1))

      diff < 0 ->
        active_workers
        |> Enum.sort_by(& &1.id, :desc)
        |> Enum.take(abs(diff))
        |> Enum.each(&Parent.shutdown_child(&1.id))
    end

    {:noreply, state}
  end

  defp start_worker(id) do
    Parent.start_child(%{
      id: {:worker, id},
      start: {Task, :start_link, [&run_worker/0]}
    })
  end

  defp run_worker do
    Process.sleep(:rand.uniform(1000))
    worker_loop()
  end

  defp worker_loop do
    _ = Enum.reduce(1..100, 0, &(&1 + &2))
    :erlang.garbage_collect()
    Process.sleep(1000)
    worker_loop()
  end

  defp get_value(key) do
    [{^key, value}] = :ets.lookup(__MODULE__, key)
    value
  end
end
