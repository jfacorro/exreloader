##
## Inspired by mochiweb's reloader (Copyright 2007 Mochi Media, Inc.)
##
defmodule ExReloader do
  use Application
  import Supervisor.Spec
  require Logger

  def start do
    :ok = Application.start :exreloader
  end

  def start(_, _) do
    interval = Application.get_all_env(:exreloader)[:interval] || 1000
    children = [worker(ExReloader.Server, [interval])]
    opts = [strategy: :one_for_one,
            name: ExReloader.Server.Sup]
    Supervisor.start_link(children, opts)
  end

  ##

  def reload_modules(modules) do
    for module <- modules, do: reload(module)
  end

  def reload(module) do
    :code.purge(module)
    :code.load_file(module)
    Logger.info "Reloaded #{inspect module}"
  end

  def recompile module do
    src = source(module)
    {:file, beam} = :code.is_loaded(module)
    path = :filename.dirname(beam)
    Logger.info "Recompiling #{inspect module} in '#{src}' to '#{beam}'"
    compile(:erlang.list_to_binary(src), :erlang.list_to_binary(path))
  end

  defp compile(src, path) when is_binary(src) and is_binary(path) do
    Kernel.ParallelCompiler.files_to_path([src], path)
  end

  def source module do
    info = module.module_info()
    info[:compile][:source]
  end

  def all_changed() do
    for {m, f} <- :code.all_loaded, is_list(f), changed?(m), do: m
  end

  def changed?(module) do
    try do
        module_vsn(module.module_info) != module_vsn(:code.get_object_code(module))
    catch _ ->
        false
    end
  end

  defp module_vsn({m, beam, _f}) do
    {:ok, {^m, vsn}} = :beam_lib.version(beam)
    vsn
  end
  defp module_vsn(l) when is_list(l) do
    {_, attrs} = :lists.keyfind(:attributes, 1, l)
    {_, vsn} = :lists.keyfind(:vsn, 1, attrs)
    vsn
  end

end

defmodule ExReloader.Server do
  use GenServer
  require Logger

  def start_link(interval \\ 1000) do
    GenServer.start_link( __MODULE__, interval, [name: {:local, __MODULE__}])
  end

  def init(interval) do
    {:ok, {timestamp(), interval}, interval}
  end

  def handle_call :stop, state do
    {:stop, :shutdown, :stopped, state}
  end

  def handle_info :timeout, {last, timeout} do
    now = timestamp()
    run(last, now)
    {:noreply, {now, timeout}, timeout}
  end

  defp timestamp, do: :erlang.localtime

  defp run(from, to) do
    for {module, beam} <- :code.all_loaded, is_list(beam) do
      src = ExReloader.source(module)
      case File.stat(src) do
        {:ok, %File.Stat{mtime: mtime}} when mtime >= from and mtime < to ->
          ExReloader.recompile(module)
          ExReloader.reload(module)
        {:ok, _} -> :unmodified
        {:error, :enoent} -> :gone
        other -> other
      end
    end
  end
end
