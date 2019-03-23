defmodule ElixirHttpPlug.PlugConn do
  import Plug.Conn, only: [put_resp_content_type: 2, send_resp: 3]
  alias ElixirHttpPlug.Error
  alias ElixirHttpPlug.ValidationErrors
  require Logger

  @spec status201(Plug.Conn.t) :: Plug.Conn.t
  def status201(conn), do: conn |> send_resp(201, "")

  @spec status204(Plug.Conn.t) :: Plug.Conn.t
  def status204(conn), do: conn |> send_resp(204, "")

  @spec status400(Plug.Conn.t, String.t) :: Plug.Conn.t
  def status400(conn, message \\ "Bad Request"), do: conn |> send_json_error(status_code: 400, message: message)

  @spec status404(Plug.Conn.t) :: Plug.Conn.t
  def status404(conn), do: conn |> send_json_error(status_code: 404, message: "Resource Not Found")

  @spec status500(Plug.Conn.t) :: Plug.Conn.t
  def status500(conn), do: conn |> send_json_error(status_code: 500, message: "Unknown Service Error")

  @spec to_json_response(:ok | {:ok, any} | {:error, any}, Plug.Conn.t) :: Plug.Conn.t
  def to_json_response(result, conn) do
    case result do
      {:error, error}                                -> conn |> send_json_error(error)
      {:ok, value}                                   -> conn |> send_json(value)
      :ok                                            -> conn |> status204
      unknown_type                                   -> conn |> send_json(unknown_type)
    end
  end

  @spec send_json(Plug.Conn.t, map) :: Plug.Conn.t
  def send_json(conn, map) do
    map
    |> to_json(
         success: fn json  -> conn
                              |> put_resp_content_type("application/json")
                              |> send_resp(200, json)
         end,
         failure: fn error -> Logger.error("PlugConn.send_json:Request Failed:500, #{inspect(error)}")
                              conn |> status500
         end
       )
  end

  @spec send_json_error(Plug.Conn.t, any) :: Plug.Conn.t
  def send_json_error(conn, error) do
    [status_code: code, message: message] =
      case error do
        [status_code: code, message: message]          -> [status_code: system_error_to_status(code), message: message]
        [%Error{message: _, code: code} = head | tail] -> [status_code: system_error_to_status(code), message: [head] ++ tail]
        %Error{message: message, code: code}           -> [status_code: system_error_to_status(code), message: message]
        %{__struct__: _, type: type, errors: errors}   -> [status_code: system_error_to_status(type), message: errors]
        %ValidationErrors{errors: errors}              -> [status_code: 400, message: errors]
        error                                          -> [status_code: 500, message: error]
      end

    format_error(message)
    |> to_json(
         success: fn json       -> Logger.error("PlugConn.send_error:Request Failed:#{code}: #{inspect(error)}")
                                   conn
                                   |> put_resp_content_type("application/json")
                                   |> send_resp(code, json)
         end,
         failure: fn json_error -> Logger.error("Request Failed:500, #{inspect(json_error)}: " <>
                                                "code: #{inspect(code)}, message: #{inspect(error)}")
                                   conn |> status500
         end
       )
  end

  @spec format_error(any) :: %{errors: any}
  defp format_error(error) do
    case error do
      error when is_binary(error) -> %{errors: [%{message: error}]}
      error when is_map(error)    -> %{errors: [error]}
      error when is_list(error)   -> %{errors: error}
      error                       -> %{errors: [%{message: inspect(error)}]}
    end
  end

  @spec system_error_to_status(integer | String.t) :: integer
  defp system_error_to_status(code) do
    case code do
      int when is_integer(int) -> int
      "UNAUTHORIZED"           -> 401
      "ENTITY_NOT_FOUND"       -> 404
      "NOT_FOUND"              -> 404
      "INVALID_ARGS"           -> 400
      "DB_ERROR"               -> 500
      "UNKNOWN_ERROR"          -> 500
      _                        -> 500
    end
  end

  @spec to_json(map, [{:success, (binary -> any)}, {:failure, (String.t -> any)}]) :: any
  defp to_json(data, [success: success, failure: failure]) do
    case Poison.encode(data) do
      {:ok, val} -> success.(val)
      error -> failure.("Invalid: #{inspect(error)}")
    end
  end
end
