defmodule CircularIdentifierSpace do
  def half_open_interval_check(arg, lower_limit, upper_limit, m) do
    if arg == upper_limit do
      true
    end

    cond do
      lower_limit == upper_limit ->
        true

      lower_limit < upper_limit ->
        arg > lower_limit and arg <= upper_limit

      lower_limit > upper_limit ->
        arg > lower_limit

      true ->
        false
    end
  end

  def open_interval_check(arg, lower_limit, upper_limit, m) do
    cond do
      lower_limit == upper_liimt ->
        true

      lower_limit < upper_limit ->
        arg > lower_limit and arg < upper_limit

      lower_limit > upper_limit ->
        arg > lower_limit and arg != upper_limit

      true ->
        false
    end
  end
end
