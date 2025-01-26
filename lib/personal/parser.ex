defmodule Personal.Parser do
  @moduledoc false

  def parse(file) do
    file
    |> File.read!()
    |> markdown_to_ast()
    |> IO.inspect()
    |> ast_to_html()
  end

  def markdown_to_ast(binary) do
    binary
    |> String.replace("\r", "")
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_line/1)
    |> group_code_blocks()
    |> group_lists()
  end

  def ast_to_html(ast) do
    ast
    |> iterate()
    |> IO.iodata_to_binary()
  end

  def functions() do
    [
      &code_block/1,
      &ordered_list/1,
      &unordered_list/1,
      &quoted/1,
      &horizontal_ruler/1,
      &header_token/1,
      &image_block/1,
      &paragraph/1
    ]
  end

  defp parse_line(line) do
    Enum.reduce_while(functions(), nil, fn fun, _acc ->
      try do
        fun.(String.trim(line))
      rescue
        _ -> paragraph(String.trim(line))
      end
    end)
  end

  defp group_code_blocks(ast) do
    Enum.reduce(ast, {false, [], []}, fn
      {:code, _}, {false, _acc, final_acc} ->
        {true, [], final_acc}

      {:code, _}, {true, acc, final_acc} ->
        {false, [], [{:code, Enum.reverse(acc)} | final_acc]}

      {_, line}, {true, acc, final_acc} ->
        {true, [line | acc], final_acc}

      line, {false, acc, final_acc} ->
        {false, acc, [line | final_acc]}
    end)
    |> elem(2)
    |> Enum.reverse()
  end

  # weird af
  # finds blocks of li and groups them
  # finally for each block create the ul
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
      |> Enum.reject(& &1 == [])

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

  # if a line starts with ! is an img
  defp image_block("!" <> contents) do
    ["["<> alt, rest] = String.split(contents, "](")
    right_part = String.trim_trailing(rest, ")")
    [link, title] = String.split(right_part, " ", trim: true, parts: 2)

    halt({:img, {link, String.replace(title, "\"", ""), alt}})
  end


  defp image_block(contents), do: continue(contents)

  # now do when an image is in the middle of something
  # dirty af
  defp image_block_in_line({type, contents}) do
    if String.contains?(contents, "![") do
      # fetch when it starts the block and slice it
      starting_index = find_index_for_pattern(contents, "![")
      last_index = find_index_for_pattern(contents, ")")
      maybe_image = String.slice(contents, (starting_index+1)..last_index)

      # same logic as for base case
      ["["<> alt, rest] = String.split(maybe_image, "](")
      right_part = String.trim_trailing(rest, ")")
      [link, title] = String.split(right_part, " ", trim: true, parts: 2)

      # replace the image thing from the OG image
      first = String.slice(contents, 0..(starting_index-1))
      last = String.slice(contents, last_index..-2//1)

      image = {:img, {link, String.replace(title, "\"", ""), alt}}
      halt({type, [first, image, last]})
    else
      continue(contents)
    end
  rescue
    _ -> continue(contents)
  end

  defp code_block("```"), do: halt({:code, ""})
  defp code_block(contents), do: continue(contents)

  defp unordered_list("- " <> contents), do: halt({:li_un, "- " <> contents})
  defp unordered_list(contents), do: continue(contents)

  # matches for N. and replaces from watever until point
  defp ordered_list(contents) do
    if Regex.match?(~r/^\d+\.\s.+/, contents) do
      halt({:li_or, contents})
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

  defp paragraph(contents) do
    case image_block_in_line({:p, contents}) do
      {:halt, inline_image} ->
        IO.inspect(inline_image, label: "INLINE!")
        halt(inline_image)
      {:cont, _} ->
        halt({:p, contents})
    end
  end

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
  def write_block({:p, content}) when is_list(content), do:  ["<p>", iterate(content), "</p>"]
  def write_block({:p, content}), do: ["<p>", content, "</p>"]
  def write_block({:ul, content}), do: ["<ul>", iterate(content), "</ul>"]
  def write_block({:ol, content}), do: ["<ol>", iterate(content), "</ol>"]
  def write_block({:li, content}), do: ["<li>", clean_li(content), "</li>"]
  def write_block({:img, {link, title, alt}}), do: ["<img src=\"#{link}\" title=\"#{title}\" alt=\"#{alt}\" />"]
  def write_block({:a, {link, text}}), do: ["<a href=\"#{link}\">", text, "</a>"]
  def write_block({:br, content}), do: [content, "<br>"]
  def write_block({:code, content}), do: ["<code>", iterate(add_jumps(clean_ast(content))), "</code>"]
  def write_block({:quoted, content}), do: ["<blockquote>", write_block(content), "</blockquote>"]
  def write_block({:hr, _content}), do: ["<hr />"]
  def write_block([]), do: []
  def write_block(content), do: content

  def clean_li("- " <> content), do: content
  def clean_li(content), do: String.replace(content, ~r/^\d+\.\s/, "")

  # recursively remove all ast and just keep the content
  def clean_ast(ast) do
    Enum.map(ast, fn
      {_, item} when is_list(item) ->
        clean_ast(ast)

      item ->
        item
    end)
  end

  def add_jumps(ast) do
    Enum.map(ast, &{:br, &1})
  end

  defp find_index_for_pattern(line, pattern) do
    line
    |> String.split("", trim: true)
    |> Enum.chunk_every(2)
    |> Enum.map(&Enum.join(&1, ""))
    |> Enum.with_index()
    |> Enum.find(fn {key, _index} -> key == pattern end)
    |> elem(1)
    |> Kernel.*(2)
  end
end
