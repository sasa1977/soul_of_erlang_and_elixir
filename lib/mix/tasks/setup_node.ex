defmodule Mix.Tasks.MySystem.SetupNode do
  # Mix.Task behaviour is not in PLT since Mix is not a runtime dep, so we disable the warning
  @dialyzer :no_undefined_callbacks

  use Mix.Task

  def run(_args) do
    {:ok, nodes} = :erl_epmd.names(~c"127.0.0.1")

    nodes =
      for {node_name, _epmd_port} <- nodes,
          node_name = to_string(node_name),
          node_name =~ ~r/^my_system_\d+$/,
          into: MapSet.new(),
          do: node_name

    node_name =
      Stream.iterate(1, &(&1 + 1))
      |> Stream.map(&"my_system_#{&1}")
      |> Enum.find(&(not MapSet.member?(nodes, &1)))

    Node.start(:"#{node_name}@127.0.0.1")
    Node.set_cookie(:super_secret)
  end
end
