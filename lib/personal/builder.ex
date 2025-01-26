defmodule Personal.Builder do
  @moduledoc false

  @template_folder "template"
  @output_folder "static"

  def render() do
    File.cp_r!(@template_folder, @output_folder)

    html = Personal.Parser.parse("content/index.md")

    if not File.exists?("static") do
      File.mkdir("static")
    end

    File.read!("static/index.html")
    |> IO.inspect()
    |> String.replace("{{body}}", html)
    |> then(&File.write("static/index.html", &1))

    Personal.FileReader.read()
  end
end
