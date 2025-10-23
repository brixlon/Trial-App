defmodule TrialAppWeb.DepartmentLiveTest do
  use TrialAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrialApp.OrganizationsFixtures

  @create_attrs %{name: "some name", description: "some description"}
  @update_attrs %{name: "some updated name", description: "some updated description"}
  @invalid_attrs %{name: nil, description: nil}

  setup :register_and_log_in_user

  defp create_department(%{scope: scope}) do
    department = department_fixture(scope)

    %{department: department}
  end

  describe "Index" do
    setup [:create_department]

    test "lists all departments", %{conn: conn, department: department} do
      {:ok, _index_live, html} = live(conn, ~p"/departments")

      assert html =~ "Listing Departments"
      assert html =~ department.name
    end

    test "saves new department", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/departments")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Department")
               |> render_click()
               |> follow_redirect(conn, ~p"/departments/new")

      assert render(form_live) =~ "New Department"

      assert form_live
             |> form("#department-form", department: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#department-form", department: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/departments")

      html = render(index_live)
      assert html =~ "Department created successfully"
      assert html =~ "some name"
    end

    test "updates department in listing", %{conn: conn, department: department} do
      {:ok, index_live, _html} = live(conn, ~p"/departments")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#departments-#{department.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/departments/#{department}/edit")

      assert render(form_live) =~ "Edit Department"

      assert form_live
             |> form("#department-form", department: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#department-form", department: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/departments")

      html = render(index_live)
      assert html =~ "Department updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes department in listing", %{conn: conn, department: department} do
      {:ok, index_live, _html} = live(conn, ~p"/departments")

      assert index_live |> element("#departments-#{department.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#departments-#{department.id}")
    end
  end

  describe "Show" do
    setup [:create_department]

    test "displays department", %{conn: conn, department: department} do
      {:ok, _show_live, html} = live(conn, ~p"/departments/#{department}")

      assert html =~ "Show Department"
      assert html =~ department.name
    end

    test "updates department and returns to show", %{conn: conn, department: department} do
      {:ok, show_live, _html} = live(conn, ~p"/departments/#{department}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/departments/#{department}/edit?return_to=show")

      assert render(form_live) =~ "Edit Department"

      assert form_live
             |> form("#department-form", department: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#department-form", department: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/departments/#{department}")

      html = render(show_live)
      assert html =~ "Department updated successfully"
      assert html =~ "some updated name"
    end
  end
end
