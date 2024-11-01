defmodule MySystem.LoadControl.SchedulerMonitor do
  use GenServer

  def start_link(arg),
    do: GenServer.start_link(__MODULE__, arg)

  @impl GenServer
  def init(_arg) do
    enqueue_next_tick()
    :erlang.system_flag(:scheduler_wall_time, true)
    sample = :scheduler.get_sample()
    {:ok, %{sample: sample, utilizations: []}}
  end

  @impl GenServer
  def handle_info(:calc_utilization, state) do
    enqueue_next_tick()
    new_sample = :scheduler.get_sample()
    utilization = :scheduler.utilization(state.sample, new_sample)

    schedulers_online = :erlang.system_info(:schedulers_online)
    actives = for {:normal, id, value, _} <- utilization, id <= schedulers_online, do: value
    total = Enum.sum(actives) / schedulers_online

    utilizations = Enum.take([total | state.utilizations], MySystem.LoadControl.num_points())

    MySystem.LoadControl.notify({:scheduler_utilizations, utilizations})

    {:noreply, %{sample: new_sample, utilizations: utilizations}}
  end

  defp enqueue_next_tick(),
    do: Process.send_after(self(), :calc_utilization, 100)
end
