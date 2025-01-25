defmodule ParserTests do
  @moduledoc false

  use ExUnit.Case

  alias Personal.Parser

  test "hi" do
    input = """
    # hello world
    hola que tal bro
    """

    expected = "<h1>hello world</h1><p>hola que tal bro</p>"

    output = Parser.ast_to_html()

    assert output == expected
  end
end
