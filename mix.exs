defmodule Exreloader.Mixfile do
  use Mix.Project

  def project do
    [app: :exreloader, version: "0.0.1", deps: deps()]
  end

  def application do
    [applications: [:logger], mod: {ExReloader, []}]
  end

  defp deps do
    []
  end
end
