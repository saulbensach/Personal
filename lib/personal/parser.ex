defmodule Personal.Parser do
  @moduledoc false

  @content_folder "content"

  def parse() do
    data = "content/index.md"
    |> File.read!()
    |> String.replace("\r", "")

    parsed = data
    |> String.split(" ", trim: true)
    |> Enum.map(fn word ->
      if String.contains?(word, "\n") do
        word
        |> String.split("\n")
        |> Enum.intersperse("\n")
      else
        word
      end
    end)
    |> List.flatten()
    |> Enum.reduce({"", ""}, fn word, {last_token, acc} ->
      maybe_token = token(word)
      cond do
        word == "\n" and last_token != "" ->
          {"", acc <> "</#{last_token}>"}

        is_nil(maybe_token) ->
          {last_token, acc <> word <> " "}

        maybe_token == :jump ->
          {last_token, acc <> " "}

        true ->
          {maybe_token, acc <> "<#{maybe_token}>"}
      end
    end)
    |> elem(1)
    |> IO.inspect

    File.write("static/index.html", parsed)
    Personal.FileReader.read()
  end

  defp token("#"), do: "h1"
  defp token("##"), do: "h2"
  defp token("###"), do: "h3"
  defp token("####"), do: "h4"
  defp token("#####"), do: "h5"
  defp token("######"), do: "h6"
  defp token("\n"), do: :jump
  defp token(_), do: nil
end
