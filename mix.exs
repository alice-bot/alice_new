defmodule AliceNew.MixProject do
  use Mix.Project

  @alice_version "0.4.3"
  @github "https://github.com/alice-bot/alice_new"

  def project do
    [
      app: :alice_new,
      start_permanent: Mix.env() == :prod,
      version: @alice_version,
      elixir: "~> 1.7",
      deps: deps(),
      package: [
        licenses: ["MIT"],
        links: %{github: @github},
        files: ~w(lib templates .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
      ],
      source_url: @github,
      homepage_url: "https://www.alice-bot.org",
      docs: [main: "Mix.Tasks.Alice.New.Handler"],
      aliases: aliases(),
      preferred_cli_env: [
        build: :prod,
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],
      test_coverage: [tool: ExCoveralls],
      description: """
      AliceNew - Mix task to generate a new Alice handler

      Provides a `mix alice.new.handler` task to bootstrap a new Alice handler
      """
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:eex]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.21", only: [:dev, :docs], runtime: false},
      {:excoveralls, "~> 0.12", only: :test},
      {:credo, "~> 1.3", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      build: [&build_releases/1]
    ]
  end

  defp build_releases(_) do
    Mix.Tasks.Compile.run([])
    Mix.Tasks.Archive.Build.run([])
    Mix.Tasks.Archive.Build.run(["--output=alice_new.ez"])
    File.mkdir_p("./archives")
    File.rename("alice_new.ez", "./archives/alice_new.ez")
    File.rename("alice_new-#{@alice_version}.ez", "./archives/alice_new-#{@alice_version}.ez")
  end
end
