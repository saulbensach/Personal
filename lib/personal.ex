defmodule Personal do

  def read() do
    walk("static")
  end

  def walk(folder) do
    folder
    |> File.ls!()
    |> Enum.reduce(Map.new() |> Map.put(folder, %{}), fn item, acc ->
      if File.dir?("#{folder}/#{item}") do
        childrens =
          "#{folder}/#{item}"
          |> walk()
          |> Map.values()
          |> List.flatten()
          |> List.first()

        Map.update!(acc, folder, &Map.put(&1, item, childrens))
      else
        path = "#{folder}/#{item}"

        Map.update!(acc, folder, &Map.put(&1, item, File.read!(path)))
      end
    end)
  end
end
