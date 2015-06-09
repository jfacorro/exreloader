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

  def reload(modules) when is_list(modules) do
    for module <- modules, do: reload(module)
  end
  def reload(module) do
    :code.purge(module)
    :code.load_file(module)
    Logger.info "Reloaded #{inspect module}"
  end

  def recompile(src, modules) do
    module = List.first(modules)
    {:file, beam} = :code.is_loaded(module)
    path = :filename.dirname(beam)

    Logger.info "Recompiling #{inspect modules} in '#{src}'"

    src_bin = :erlang.list_to_binary(src)
    path_bin = :erlang.list_to_binary(path)
    ext = :filename.extension(src_bin)
    case compile(ext, src_bin, path_bin) do
      :ok ->
        ExReloader.reload(modules)
      :error ->
        Logger.error("Error while compiling #{inspect module}")
    end
  end

  defp compile(ext, src, path) when ext in [".ex", ".exs"]  do
    result = Kernel.ParallelCompiler.files_to_path([src], path)
    case result do
      [] ->
        :error
      _  ->
        :ok
    end
  end
  defp compile(ext, src, path) when ext in [".erl", ".hrl"]  do
    src_char_list = String.to_char_list(src)
    path_char_list = String.to_char_list(path)
    opts = [{:outdir, path_char_list},
            :verbose,
            :report_errors,
            :report_warnings]
    result = :compile.file(:filename.rootname(src_char_list), opts)
    case result do
      :error ->
        :error
      {:ok, _} ->
        :ok
    end
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
