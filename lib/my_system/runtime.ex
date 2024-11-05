defmodule Runtime do
  def trace(pid) do
    Task.async(fn ->
      :erlang.trace(pid, true, [:call])

      try do
        :erlang.trace(pid, true, [:call])
      rescue
        ArgumentError ->
          []
      else
        _ ->
          :erlang.trace_pattern({:_, :_, :_}, true, [:local])
          Process.send_after(self(), :stop_trace, :timer.seconds(1))

          fn ->
            receive do
              {:trace, ^pid, :call, {mod, fun, args}} -> {mod, fun, args}
              :stop_trace -> :stop_trace
            end
          end
          |> Stream.repeatedly()
          |> Stream.take(50)
          |> Enum.take_while(&(&1 != :stop_trace))
      end
    end)
    |> Task.await()
  end
end
