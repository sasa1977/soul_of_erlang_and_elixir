defmodule Mix.Tasks.MySystem.Upgrade do
  # Mix.Task behaviour is not in PLT since Mix is not a runtime dep, so we disable the warning
  @dialyzer :no_undefined_callbacks

  use Mix.Task

  def run(_args) do
    Node.start(:"upgrader@127.0.0.1")
    Node.set_cookie(:super_secret)
    Node.connect(:"my_system_1@127.0.0.1")

    Enum.each(
      [MySystem.Math, MySystemWeb.Math],
      fn module ->
        :ok =
          File.cp!(
            "_build/prod/lib/my_system/ebin/#{module}.beam",
            "_build/prod/rel/my_system/lib/my_system-0.1.0/ebin/#{module}.beam"
          )

        :rpc.call(:"my_system_1@127.0.0.1", :code, :purge, [module])
        {:module, ^module} = :rpc.call(:"my_system_1@127.0.0.1", :code, :load_file, [module])
      end
    )

    Mix.Shell.IO.info("Upgrade finished successfully.")
  end
end
