defmodule Mix.Tasks.Alice.New.Handler do
  @moduledoc """
  Creates a new Alice handler.
  """

  use Mix.Task

  @version Mix.Project.config()[:version]
  @shortdoc "Creates a new Alice v#{@version} handler"

  @switches [
    app: :string,
    module: :string
  ]

  def run([version]) when version in ~w[-v --version] do
    Mix.shell().info("Alice v#{@version}")
  end

  def run(argv) do
    elixir_version_check!()

    case parse_opts(argv) do
      {_opts, []} ->
        Mix.Tasks.Help.run(["alice.new.handler"])

      {opts, [base_path | _]} ->
        generate(base_path, opts)
    end
  end

  defp generate(base_path, opts) do
    Mix.shell().info("probably generate some files here")
    Mix.shell().info("#{inspect({base_path, opts})}")
  end

  defp parse_opts(argv) do
    case OptionParser.parse(argv, strict: @switches) do
      {opts, argv, []} ->
        {opts, argv}

      {_opts, _argv, [switch | _]} ->
        Mix.raise("Invalid option: #{switch_to_string(switch)}")
    end
  end

  defp switch_to_string({name, nil}), do: name
  defp switch_to_string({name, val}), do: "#{name}=#{val}"

  defp elixir_version_check! do
    unless Version.match?(System.version(), "~> 1.7") do
      Mix.raise(
        "Alice v#{@version} requires at least Elixir v1.7.\n " <>
          "You have #{System.version()}. Please update accordingly"
      )
    end
  end
end
