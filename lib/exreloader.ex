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
    Logger.info "Recompiling #{inspect module} in '#{src}'"
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
