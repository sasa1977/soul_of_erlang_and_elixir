defmodule MySystem.LoadControl do
  def set_num_schedulers(num) do
    :erlang.system_flag(:schedulers_online, num)
    :erlang.system_flag(:dirty_cpu_schedulers_online, num)
  end

  def num_schedulers,
    do: :erlang.system_info(:schedulers_online)
end
