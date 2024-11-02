defmodule MySystem.Math do
  use Parent.Supervisor

  def start_link(_arg),
    do: Parent.Supervisor.start_link([], name: __MODULE__)

  def sum(number) do
    caller = self()

    {:ok, pid} =
      Parent.Client.start_child(
        __MODULE__,
        %{
          start: {Task, :start_link, [fn -> calc_sum(caller, number) end]},
          restart: :temporary,
          ephemeral?: true,
          meta: caller
        }
      )

    Process.monitor(pid)
    pid
  end

  defp calc_sum(_caller, 13), do: raise("error")
  defp calc_sum(caller, n), do: send(caller, {:sum, self(), calc_sum(1, n, 0)})

  defp calc_sum(from, from, sum), do: sum + from
  defp calc_sum(from, to, acc_sum), do: calc_sum(from + 1, to, acc_sum + from)
end
