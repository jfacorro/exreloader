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
