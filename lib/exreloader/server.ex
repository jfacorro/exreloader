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
    :code.all_loaded
    |> Enum.filter(fn {_, beam} -> is_list(beam) end)
    |> Enum.reduce(%{}, fn({module, _}, map) ->
      src = ExReloader.source(module)
      modules = [module | map[src] || []]
      Map.put(map, src, modules)
    end)
    |> Map.to_list
    |> Enum.map(fn {src, modules} -> recompile?(src, modules, from, to) end)
  end

  def recompile?(src, mods, from, to) do
    case File.stat(src) do
      {:ok, %File.Stat{mtime: mtime}} when mtime >= from and mtime < to ->
        ExReloader.recompile(src, mods)
      {:ok, _} -> :unmodified
      {:error, :enoent} -> :gone
      other -> other
    end
  end
end
