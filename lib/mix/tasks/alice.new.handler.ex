defmodule Mix.Tasks.Alice.New.Handler.Common do
  require Mix.Generator

  @alice_version Mix.Project.config()[:version]

  templates = [
    formatter: "templates/formatter.exs",
    gitignore: "templates/gitignore.eex",
    readme: "templates/new_handler/README.md.eex",
    mix_exs: "templates/new_handler/mix.exs.eex",
    config: "templates/new_handler/config/config.exs.eex",
    handler: "templates/new_handler/lib/alice/handlers/handler.ex.eex",
    handler_test: "templates/new_handler/test/alice/handlers/handler_test.exs.eex"
  ]

  Enum.each(templates, fn {name, file} ->
    Mix.Generator.embed_template(name, from_file: file)
  end)

  def formatter(assigns), do: formatter_template(assigns)
  def gitignore(assigns), do: gitignore_template(assigns)

  def alice_version(), do: @alice_version

  def elixir_version_check! do
    unless Version.match?(System.version(), "~> 1.7") do
      Mix.raise(
        "Alice v#{@alice_version} requires at least Elixir v1.7.\n " <>
          "You have #{System.version()}. Please update accordingly"
      )
    end
  end

  def check_handler_name!(name, inferred?) do
    unless name =~ Regex.recompile!(~r/^[a-z][a-z0-9_]*$/) do
      inferred_message =
        if inferred? do
          ". The handler name is inferred from the path, if you'd like to " <>
            "explicitly name the handler then use the \"--handler NAME\" option"
        else
          ""
        end

      Mix.raise(
        "Handler name must start with a lowercase ASCII letter, followed by " <>
          "lowercase ASCII letters, numbers, or underscores, got: #{inspect(name)}" <>
          inferred_message
      )
    end

    if name |> String.trim() |> String.downcase() == "alice" do
      Mix.raise("Handler name cannot be alice")
    end
  end

  def check_mod_name_validity!(name) do
    unless name =~ Regex.recompile!(~r/^[A-Z]\w*(\.[A-Z]\w*)*$/) do
      Mix.raise(
        "Module name must be a valid Elixir alias (for example: MyHandler), got: #{inspect(name)}"
      )
    end
  end

  def handler_module(module_name) do
    Module.concat(["Alice", "Handlers", module_name])
  end

  def check_mod_name_availability!(module) do
    module
    |> Module.split()
    |> Enum.reduce([], fn name, acc ->
      mod = Module.concat([Elixir, name | acc])

      if Code.ensure_loaded?(mod) do
        Mix.raise("Module name #{inspect(mod)} is already taken, please choose another name")
      else
        [name | acc]
      end
    end)
  end

  def check_directory_existence!(path) do
    msg = "The directory #{inspect(path)} already exists. Are you sure you want to continue?"

    if File.dir?(path) and not Mix.shell().yes?(msg) do
      Mix.raise("Please select another directory for installation")
    end
  end
end

defmodule Mix.Tasks.Alice.New.Handler do
  @moduledoc ~S"""
  Generates a new Alice handler.

  This is the easiest way to set up a new Alice handler.

  ## Install `alice.new`

  ```bash
  mix archive.install hex alice_new
  ```

  ## Build a Handler

  First, navigate the command-line to the directory where you want to create
  your new Alice handler. Then run the following commands: (change `my_handler`
  to the name of your handler)

  ```bash
  mix alice.new.handler my_handler
  cd alice_my_handler
  mix deps.get
  ```

  ## Writing Route Handlers

  In lib/alice/handlers/my_handler.ex:

  ```elixir
  defmodule Alice.Handlers.MyHandler do
    use Alice.Router

    command ~r/repeat after me: (?<term>.+)/i, :repeat
    route ~r/repeat after me: (?<term>.+)/i, :repeat

    @doc "`repeat after me: thing` - replies you said, 'thing'"
    def repeat(conn) do
      term = Alice.Conn.last_capture(conn)
      response_text = "you said, '#{term}'"

      reply(conn, response_text)
    end
  end
  ```

  ## Testing Handlers

  Alice provides several helpers to make it easy to test your handlers.  First
  you'll need to invoke to add `use Alice.HandlersCase, handlers:
  [YourHandler]` passing it the handler you're trying to test. Then you can use
  `message_received()` within your test, which will simulate a message coming
  in from the chat backend and route it through to the handlers appropriately.
  If you're wanting to invoke a command, you'll need to make sure your message
  includes `<@alice>` within the string. From there you can use either
  `first_reply()` to get the first reply sent out or `all_replies()` which will
  return a List of replies that have been received during your test. You can
  use either to use normal assertions on to ensure your handler behaves in the
  manner you expect.

  In `test/alice/handlers/my_handler_test.exs`:

  ```elixir
  defmodule Alice.Handlers.MyHandler do
    use Alice.HandlersCase, handlers: Alice.Handlers.MyHandler

    test "the repeat command repeats a term" do
      send_message("<@alice> repeat after me: this is a boring handler")
      assert first_reply() == "you said, 'this is a boring handler'"
    end

    test "the repeat route repeats a term" do
      send_message("repeat after me: this is a boring handler")
      assert first_reply() == "you said, 'this is a boring handler'"
    end
  end
  ```

  ## Registering Handlers

  In the `mix.exs` file of your bot, add your handler to the list of handlers
  to register on start

  ```elixir
  def application do
    [ applications: [:alice],
      mod: {Alice, [Alice.Handlers.MyHandler] } ]
  end
  ```
  """
  use Mix.Task
  import Mix.Generator
  alias Mix.Tasks.Alice.New.Handler.Common

  @shortdoc "Creates a new Alice v#{Common.alice_version()} handler"

  @switches [
    name: :string,
    module: :string
  ]

  def run([version]) when version in ~w[-v --version] do
    Mix.shell().info("Alice v#{Common.alice_version()}")
  end

  def run(argv) do
    case parse_opts(argv) do
      {_opts, []} ->
        Mix.Tasks.Help.run(["alice.new.handler"])

      {opts, [path | _]} ->
        Common.elixir_version_check!()

        basename = Path.basename(Path.expand(path))
        path = Path.join([Path.dirname(path), "alice_#{basename}"])

        handler_name = opts[:name] || basename
        app = "alice_#{handler_name}"
        Common.check_handler_name!(handler_name, !opts[:name])

        module_name = opts[:module] || Macro.camelize(handler_name)
        Common.check_mod_name_validity!(module_name)

        module = Common.handler_module(module_name)
        Common.check_mod_name_availability!(module)

        unless path == "." do
          Common.check_directory_existence!(path)
          File.mkdir_p!(path)
        end

        File.cd!(path, fn ->
          generate(app, handler_name, module, path, opts)
        end)
    end
  end

  defp generate(app_name, handler_name, handler_module, path, opts) do
    Mix.shell().info(
      "#{
        inspect(
          app_name: app_name,
          handler_name: handler_name,
          handler_module: handler_module,
          path: path,
          opts: opts
        )
      }"
    )

    assigns = [
      app_name: app_name,
      handler_name: handler_name,
      handler_module: handler_module,
      elixir_version: get_version(System.version()),
      alice_version: Common.alice_version()
    ]

    create_file(".formatter.exs", Common.formatter(assigns))
    create_file(".gitignore", Common.gitignore(assigns))
    # create_file("README.md", Common.readme_template(assigns))
    # create_file("mix.exs", Common.mix_exs_template(assigns))
    #
    # create_directory("config")
    # create_file("config/config/exs", Common.config_template(assigns))
    #
    # create_directory("lib")
    # create_directory("lib/alice/handlers")
    #
    # create_file(
    #   "lib/alice/handlers/#{handler_name}.ex",
    #   Common.handler_template(assigns)
    # )
    #
    # create_directory("test/alice/handlers")
    #
    # create_file(
    #   "test/alice/handlers/#{handler_name}_test.exs",
    #   Common.handler_test_template(assigns)
    # )
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

  defp get_version(version) do
    {:ok, version} = Version.parse(version)

    "#{version.major}.#{version.minor}" <>
      case version.pre do
        [h | _] -> "-#{h}"
        [] -> ""
      end
  end
end
