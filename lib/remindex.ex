defmodule Remindex do
  defdelegate [terminate, subscribe(pid),
               add(name, moment), cancel(name),
               listen(seconds)], to: __MODULE__.Server

  defdelegate [start, start_link], to: __MODULE__.Supervisor
end
