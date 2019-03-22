defmodule ElixirHttpPlug.ErrorTest do
  alias ElixirHttpPlug.Error.Maker
  alias ElixirHttpPlug.ValidationErrors
  use ExUnit.Case

  describe "Error" do
    test "can make validation error" do
      assert Maker.validation_errors([%{error: "someError"}]) == %ValidationErrors{errors: [%{error: "someError"}]}
    end

    test "can make unknown error" do
      assert Maker.unknown_error().code == "UNKNOWN_ERROR"
    end

    test "can make unauthorized error" do
      assert Maker.unauthorized_error("SomeMessage").code == "UNAUTHORIZED"
    end

    test "can make not_found error" do
      assert Maker.not_found_error().code == "NOT_FOUND"
    end

    test "can make entity not_found error" do
      assert Maker.entity_not_found_error("1", "videos").code == "ENTITY_NOT_FOUND"
    end

    test "can make invalid_args error for property" do
      assert Maker.invalid_args_error("someField", "someError").code == "INVALID_ARGS"
    end

    test "can make invalid_args error" do
      assert Maker.invalid_args_error("someField missing").code == "INVALID_ARGS"
      assert Maker.invalid_args_error("someField", "missing").code == "INVALID_ARGS"
    end
  end
end
