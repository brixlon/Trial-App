defmodule TrialAppWeb.EmployeeLiveTest do
  use TrialAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrialApp.OrganizationsFixtures

  @create_attrs %{name: "some name", position: "some position", email: "some email"}
  @update_attrs %{name: "some updated name", position: "some updated position", email: "some updated email"}
  @invalid_attrs %{name: nil, position: nil, email: nil}

  setup :register_and_log_in_user

  defp create_employee(%{scope: scope}) do
    employee = employee_fixture(scope)

    %{employee: employee}
  end

  describe "Index" do
    setup [:create_employee]

    test "lists all employees", %{conn: conn, employee: employee} do
      {:ok, _index_live, html} = live(conn, ~p"/employees")

      assert html =~ "Listing Employees"
      assert html =~ employee.name
    end

    test "saves new employee", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/employees")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Employee")
               |> render_click()
               |> follow_redirect(conn, ~p"/employees/new")

      assert render(form_live) =~ "New Employee"

      assert form_live
             |> form("#employee-form", employee: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#employee-form", employee: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/employees")

      html = render(index_live)
      assert html =~ "Employee created successfully"
      assert html =~ "some name"
    end

    test "updates employee in listing", %{conn: conn, employee: employee} do
      {:ok, index_live, _html} = live(conn, ~p"/employees")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#employees-#{employee.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/employees/#{employee}/edit")

      assert render(form_live) =~ "Edit Employee"

      assert form_live
             |> form("#employee-form", employee: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#employee-form", employee: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/employees")

      html = render(index_live)
      assert html =~ "Employee updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes employee in listing", %{conn: conn, employee: employee} do
      {:ok, index_live, _html} = live(conn, ~p"/employees")

      assert index_live |> element("#employees-#{employee.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#employees-#{employee.id}")
    end
  end

  describe "Show" do
    setup [:create_employee]

    test "displays employee", %{conn: conn, employee: employee} do
      {:ok, _show_live, html} = live(conn, ~p"/employees/#{employee}")

      assert html =~ "Show Employee"
      assert html =~ employee.name
    end

    test "updates employee and returns to show", %{conn: conn, employee: employee} do
      {:ok, show_live, _html} = live(conn, ~p"/employees/#{employee}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/employees/#{employee}/edit?return_to=show")

      assert render(form_live) =~ "Edit Employee"

      assert form_live
             |> form("#employee-form", employee: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#employee-form", employee: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/employees/#{employee}")

      html = render(show_live)
      assert html =~ "Employee updated successfully"
      assert html =~ "some updated name"
    end
  end
end
