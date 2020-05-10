defmodule Convo.CLI do
  def main(_args \\ []) do
    path_to_release = Path.absname("_build/dev/rel/convo/bin/convo")
    System.cmd(path_to_release, ["start"])
  end
end
