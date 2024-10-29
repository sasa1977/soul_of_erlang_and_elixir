defmodule MySystem.LoadControl.SchedulerMonitor do
  use GenServer

  def start_link(arg),
    do: GenServer.start_link(__MODULE__, arg)

  @impl GenServer
  def init(_arg) do
    enqueue_next_tick()
    :erlang.system_flag(:scheduler_wall_time, true)
    {:ok, :scheduler.get_sample()}
  end

  @impl GenServer
  def handle_info(:calc_utilization, prev_sample) do
    enqueue_next_tick()
    new_sample = :scheduler.get_sample()
    utilization = :scheduler.utilization(prev_sample, new_sample)

    schedulers_online = :erlang.system_info(:schedulers_online)
    actives = for {:normal, id, value, _} <- utilization, id <= schedulers_online, do: value
    total = Enum.sum(actives) / schedulers_online

    MySystem.LoadControl.notify({:scheduler_utilization, total})

    {:noreply, new_sample}
  end

  defp enqueue_next_tick(),
    do: Process.send_after(self(), :calc_utilization, 100)
end
