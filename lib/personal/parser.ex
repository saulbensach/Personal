defmodule Personal.Parser do
  @moduledoc false

  def parse() do
    "content/index.md"
    |> File.read!()
    |> markdown_to_ast()
    #|> IO.inspect()
    |> ast_to_html()
    |> then(&File.write("static/index.html", &1))

    Personal.FileReader.read()
  end

  def markdown_to_ast(binary) do
    binary
    |> String.replace("\r", "")
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_line/1)
    |> group_lists()
  end

  def ast_to_html(ast) do
    ast
    |> iterate()
    |> IO.iodata_to_binary()
  end

  defp parse_line(line) do
    Enum.reduce_while(functions(), nil, fn fun, _acc ->
      fun.(String.trim(line))
    end)
  end

  # weird af
  defp group_lists(ast) do
    indexes =
      ast
      |> Enum.with_index()
      # just read for a li and stop when someting else is not a l
      |> Enum.reduce_while({nil, MapSet.new(), []}, fn
        {{:li_un, _}, index}, {_prev, acc, acc_final} ->
          {:cont, {:li_un, MapSet.put(acc, index), acc_final}}

        {{:li_or, _}, index}, {_prev, acc, acc_final} ->
          {:cont, {:li_or, MapSet.put(acc, index), acc_final}}

        {_ , _index}, {prev, acc, acc_final} ->
          if prev == :li_un or prev == :li_or do
            {:cont, {prev, MapSet.new(), [MapSet.to_list(acc) | acc_final]}}
          else
            {:cont, {prev, acc, acc_final}}
          end
      end)
      |> then(fn {_, set, rest} ->
        [MapSet.to_list(set) | rest]
      end)

    Enum.reduce(indexes, ast, fn indexes, acc ->
      items = Enum.map(indexes, &Enum.at(acc, &1))

      # take one item to see if it is ordered or what
      # and we asume the first item dictates what it is
      type =
        items
        |> List.first()
        |> elem(0)

      type = if type == :li_un, do: :ul, else: :ol

      acc = List.update_at(acc, List.first(indexes), fn _ ->
        {type, Enum.map(items, fn {_, contents} -> {:li, contents} end)}
      end)

      indexes = List.delete_at(indexes, 0)

      Enum.reduce(indexes, acc, fn _index, acc ->
        List.delete_at(acc, List.first(indexes))
      end)
    end)
  end

  def functions() do
    [
      &ordered_list/1,
      &unordered_list/1,
      &quoted/1,
      &horizontal_ruler/1,
      &header_token/1,
      &paragraph/1
    ]
  end

  defp unordered_list("- " <> contents), do: halt({:li_un, contents})
  defp unordered_list(contents), do: continue(contents)

  # matches for N. and replaces from watever until point
  defp ordered_list(contents) do
    if Regex.match?(~r/^\d+\.\s.+/, contents) do
      halt({:li_or, String.replace(contents, ~r/^\d+\.\s/, "")})
    else
      continue(contents)
    end
  end

  defp horizontal_ruler("---"), do: halt({:hr, ""})
  defp horizontal_ruler("___"), do: halt({:hr, ""})
  defp horizontal_ruler("***"), do: halt({:hr, ""})
  defp horizontal_ruler(contents), do: continue(contents)

  defp quoted("> " <> contents), do: halt({:quoted, parse_line(contents)})
  defp quoted(contents), do: continue(contents)


  defp header_token("# " <> contents), do: halt({:h1, contents})
  defp header_token("## " <> contents), do: halt({:h2, contents})
  defp header_token("### " <> contents), do: halt({:h3, contents})
  defp header_token("#### " <> contents), do: halt({:h4, contents})
  defp header_token("##### " <> contents), do: halt({:h5, contents})
  defp header_token("###### " <> contents), do: halt({:h6, contents})
  defp header_token(contents), do: continue(contents)

  defp paragraph(contents), do: halt({:p, contents})

  defp halt(leaf), do: {:halt, leaf}
  defp continue(leaf), do: {:cont, leaf}

  # AST to HTML builder
  def iterate(content) do
    Enum.map(content, &write_block/1)
  end

  def write_block({:h1, content}), do: ["<h1>", content, "</h1>"]
  def write_block({:h2, content}), do: ["<h2>", content, "</h2>"]
  def write_block({:h3, content}), do: ["<h3>", content, "</h3>"]
  def write_block({:h4, content}), do: ["<h4>", content, "</h4>"]
  def write_block({:h5, content}), do: ["<h5>", content, "</h5>"]
  def write_block({:h6, content}), do: ["<h6>", content, "</h6>"]
  def write_block({:p, content}), do: ["<p>", content, "</p>"]
  def write_block({:ul, content}), do: ["<ul>", iterate(content), "</ul>"]
  def write_block({:ol, content}), do: ["<ol>", iterate(content), "</ol>"]
  def write_block({:li, content}), do: ["<li>", content, "</li>"]
  def write_block({:quoted, content}), do: ["<blockquote>", write_block(content), "</blockquote>"]
  def write_block({:hr, _content}), do: ["<hr />"]
  def write_block(_), do: []
end
