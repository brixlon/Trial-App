defmodule TrialAppWeb.PositionLiveTest do
  use TrialAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrialApp.OrganizationsFixtures

  @create_attrs %{description: "some description", title: "some title"}
  @update_attrs %{description: "some updated description", title: "some updated title"}
  @invalid_attrs %{description: nil, title: nil}

  setup :register_and_log_in_user

  defp create_position(%{scope: scope}) do
    position = position_fixture(scope)

    %{position: position}
  end

  describe "Index" do
    setup [:create_position]

    test "lists all positions", %{conn: conn, position: position} do
      {:ok, _index_live, html} = live(conn, ~p"/positions")

      assert html =~ "Listing Positions"
      assert html =~ position.title
    end

    test "saves new position", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/positions")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Position")
               |> render_click()
               |> follow_redirect(conn, ~p"/positions/new")

      assert render(form_live) =~ "New Position"

      assert form_live
             |> form("#position-form", position: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#position-form", position: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/positions")

      html = render(index_live)
      assert html =~ "Position created successfully"
      assert html =~ "some title"
    end

    test "updates position in listing", %{conn: conn, position: position} do
      {:ok, index_live, _html} = live(conn, ~p"/positions")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#positions-#{position.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/positions/#{position}/edit")

      assert render(form_live) =~ "Edit Position"

      assert form_live
             |> form("#position-form", position: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#position-form", position: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/positions")

      html = render(index_live)
      assert html =~ "Position updated successfully"
      assert html =~ "some updated title"
    end

    test "deletes position in listing", %{conn: conn, position: position} do
      {:ok, index_live, _html} = live(conn, ~p"/positions")

      assert index_live |> element("#positions-#{position.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#positions-#{position.id}")
    end
  end

  describe "Show" do
    setup [:create_position]

    test "displays position", %{conn: conn, position: position} do
      {:ok, _show_live, html} = live(conn, ~p"/positions/#{position}")

      assert html =~ "Show Position"
      assert html =~ position.title
    end

    test "updates position and returns to show", %{conn: conn, position: position} do
      {:ok, show_live, _html} = live(conn, ~p"/positions/#{position}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/positions/#{position}/edit?return_to=show")

      assert render(form_live) =~ "Edit Position"

      assert form_live
             |> form("#position-form", position: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#position-form", position: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/positions/#{position}")

      html = render(show_live)
      assert html =~ "Position updated successfully"
      assert html =~ "some updated title"
    end
  end
end
