defmodule Personal.FileReader do
  @moduledoc false

  @static_folder "static"

  def read() do
    result = walk(@static_folder)

    :persistent_term.put(:folders, result)
  end

  def get_file("/") do
    get_file("index.html")
  end

  def get_file(path) do
    access_path = [@static_folder | String.split(path, "/", trim: true)]

    get_in(:persistent_term.get(:folders), access_path)
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
