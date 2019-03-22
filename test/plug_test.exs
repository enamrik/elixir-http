defmodule CustomError do
  defstruct [:errors, :type]
  def new(errors) do
    %__MODULE__{errors: errors, type: "INVALID_ARGS"}
  end
end

defmodule ElixirHttpPlug.PlugConnTest do
  alias ElixirHttpPlug.PlugConn
  alias ElixirHttpPlug.Error
  alias ElixirHttpPlug.ValidationErrors
  alias ElixirHttpPlug.Error.Maker
  use Plug.Test
  use ExUnit.Case

  describe "PlugConn" do
    test "send_json_error: can map any Error type to status code based on struct type property" do
      conn = conn(:get, "/some-endpoint", "")
      response = PlugConn.send_json_error(conn, CustomError.new(["SomeError"]))

      assert response.status == 400
      assert (response.resp_body |> Poison.decode!) == %{"errors" => ["SomeError"]}
    end

    test "send_json_error: can send unknown error" do
      conn = conn(:get, "/some-endpoint", "")
      response = PlugConn.send_json_error(conn, "UnknownError")

      assert response.status == 500
      assert (response.resp_body |> Poison.decode!) == %{"errors" => [%{"message" => "UnknownError"}]}
    end

    test "send_json_error: can send validation error" do
      conn = conn(:get, "/some-endpoint", "")
      response = PlugConn.send_json_error(conn, %ValidationErrors{errors: [%{"firstName" => "Can't be null"}]})

      assert response.status == 400
      assert (response.resp_body |> Poison.decode!) == %{"errors" => [%{"firstName" => "Can't be null"}]}
    end

    test "send_json_error: can send error" do
      conn = conn(:get, "/some-endpoint", "")
      response = PlugConn.send_json_error(conn, %Error{code: 400, message: "SomeError1"})

      assert response.status == 400
      assert (response.resp_body |> Poison.decode!) ==%{
               "errors" => [%{"message" => "SomeError1"} ]}
    end

    test "send_json_error: can send error list" do
      conn = conn(:get, "/some-endpoint", "")
      errors = [
        %Error{code: 400, message: "SomeError1"},
        %Error{code: 500, message: "SomeError2"}]

      response = PlugConn.send_json_error(conn, errors)

      assert response.status == 400
      assert (response.resp_body |> Poison.decode!) ==%{
               "errors" => [
                 %{"message" => "SomeError1", "code" => 400},
                 %{"code" => 500, "message" => "SomeError2"}]}
    end

    test "send_json_error: can send status and message" do
      conn = conn(:get, "/some-endpoint", "")

      response = PlugConn.send_json_error(conn, status_code: 401, message: "Unauthorized")

      assert response.status == 401
      assert (response.resp_body |> Poison.decode!) ==%{"errors" => [%{"message" => "Unauthorized"}]}
    end

    test "to_json_response: can handle errors with textual codes" do
      conn = conn(:get, "/some-endpoint", "")

      response = PlugConn.to_json_response(
        {:error, Maker.entity_not_found_error("someEntityId", "SomeEntity")},
        conn)

      assert response.status == 404
      assert (response.resp_body |> Poison.decode!) ==%{
               "errors" => [%{"message" => "SomeEntity with id someEntityId not found"}]}
    end

    test "to_json_response: can handle validation errors" do
      conn = conn(:get, "/some-endpoint", "")

      response = PlugConn.to_json_response({:error, %ValidationErrors{errors: ["SomeError"]}}, conn)

      assert response.status == 400
      assert (response.resp_body |> Poison.decode!) ==%{"errors" => ["SomeError"]}
    end

    test "to_json_response: can write Error type as error response" do
      conn = conn(:get, "/some-endpoint", "")

      response = PlugConn.to_json_response({:error, %Error{code: 400, message: "SomeError"}}, conn)

      assert response.status == 400
      assert (response.resp_body |> Poison.decode!)
             == %{"errors" => [%{"message" => "SomeError"}]}
    end

    test "to_json_response: will convert error list to http error" do
      conn = conn(:get, "/some-endpoint", "")
      errors = [
        %Error{code: 400, message: "SomeError1"},
        %Error{code: 500, message: "SomeError2"}]

      response = PlugConn.to_json_response({:error, errors}, conn)

      assert response.status == 400
      assert (response.resp_body |> Poison.decode!) ==
               %{"errors" => [
                   %{"message" => "SomeError1", "code" => 400},
                   %{"code" => 500, "message" => "SomeError2"}]}
    end

    test "to_json_response: will convert string error to http error" do
      conn = conn(:get, "/some-endpoint", "")

      response = PlugConn.to_json_response({:error, "SomeError"}, conn)

      assert response.status == 500
      assert (response.resp_body |> Poison.decode!) == %{"errors" => [ %{"message" => "SomeError"}]}
    end

    test "to_json_response: will convert native Elixir success with value to http 200" do
      conn = conn(:get, "/some-endpoint", "")
      value = {:ok, %{key: "someValue"}}

      response = PlugConn.to_json_response(value, conn)

      assert response.status == 200
      assert (response.resp_body |> Poison.decode!) == %{"key" => "someValue"}
    end

    test "to_json_response: will convert native Elixir success with no value to http 201" do
      conn = conn(:get, "/some-endpoint", "")
      value = :ok

      response = PlugConn.to_json_response(value, conn)

      assert response.status == 201
      assert response.resp_body == ""
    end

    test "to_json_response: will convert unrecognized types to 200" do
      conn = conn(:get, "/some-endpoint", "")
      value = %{key: "someValue"}

      response = PlugConn.to_json_response(value, conn)

      assert response.status == 200
      assert (response.resp_body |> Poison.decode!) == %{"key" => "someValue"}
    end

    test "status400: can set status 400 response message" do
      response_message = "Invalid Token"
      conn = conn(:get, "/some-endpoint", "")
      conn =  PlugConn.status400(conn, response_message)
      assert conn.status == 400
      assert Poison.decode!(conn.resp_body) == %{"errors" => [%{"message" => response_message}]}
    end

    test "status400: can respond with 400" do
      conn = conn(:get, "/some-endpoint", "")
      conn =  PlugConn.status400(conn)
      assert conn.status == 400
      assert Poison.decode!(conn.resp_body) == %{"errors" => [%{"message" => "Bad Request"}]}
    end

    test "status404: can respond with 404" do
      conn = conn(:get, "/some-endpoint", "")
      assert PlugConn.status404(conn).status == 404
    end

    test "status500: can respond with 500" do
      conn = conn(:get, "/some-endpoint", "")
      assert PlugConn.status500(conn).status == 500
    end

    test "send_json: can create json response" do
      conn = conn(:get, "/some-endpoint", "")
      assert (PlugConn.send_json(conn, %{"key" => "value"}).resp_body |> Poison.decode!) == %{"key" => "value"}
    end

    test "send_json: can handle invalid json" do
      conn = conn(:get, "/some-endpoint", "")
      assert (PlugConn.send_json(conn, {"key", "value"}).resp_body |> Poison.decode!)
             == %{"errors" => [%{"message" => "Unknown Service Error"}]}
    end
  end
end
