defmodule ElixirHttpPlug.Error do
  @enforce_keys [:message, :code]
  defstruct [:message, :code]

  @type t :: %__MODULE__{message: String.t | map, code: String.t}
end

defmodule ElixirHttpPlug.ValidationErrors do
  @enforce_keys [:errors]
  defstruct [:errors]

  @type t :: %__MODULE__{errors: list}
end

defmodule ElixirHttpPlug.Error.Maker do
  alias ElixirHttpPlug.Error
  alias ElixirHttpPlug.ValidationErrors

  @spec validation_errors(list) :: ElixirHttpPlug.ValidationErrors.t()
  def validation_errors(errors) do
     %ValidationErrors{errors: errors}
  end

  @spec unknown_error() :: ElixirHttpPlug.Error.t()
  def unknown_error() do
    %Error{message: "Oops! Something went wrong. Try again.", code: "UNKNOWN_ERROR"}
  end

  @spec unauthorized_error(String.t() | nil) :: ElixirHttpPlug.Error.t()
  def unauthorized_error(message \\ nil) do
    %Error{message: message || "Access not allowed", code: "UNAUTHORIZED"}
  end

  @spec not_found_error() :: ElixirHttpPlug.Error.t()
  def not_found_error() do
    %Error{message: "Not Found", code: "NOT_FOUND"}
  end

  @spec entity_not_found_error(String.t(), String.t()) :: ElixirHttpPlug.Error.t()
  def entity_not_found_error(id, type) do
    %Error{message: "#{type} with id #{id} not found", code: "ENTITY_NOT_FOUND"}
  end

  @spec invalid_args_error(String.t(), String.t()) :: ElixirHttpPlug.Error.t()
  def invalid_args_error(property, message) do
    %Error{message: %{property => message}, code: "INVALID_ARGS"}
  end

  @spec invalid_args_error(String.t()) :: ElixirHttpPlug.Error.t()
  def invalid_args_error(error_message) do
    %Error{message: error_message, code: "INVALID_ARGS"}
  end
end
