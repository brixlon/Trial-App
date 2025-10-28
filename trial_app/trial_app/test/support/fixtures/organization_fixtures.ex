defmodule TrialApp.OrganizationFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TrialApp.Organization` context.
  """

  @doc """
  Generate a department.
  """
  def department_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        description: "some description",
        name: "some name"
      })

    {:ok, department} = TrialApp.Organization.create_department(scope, attrs)
    department
  end

  @doc """
  Generate a team.
  """
  def team_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "some name"
      })

    {:ok, team} = TrialApp.Organization.create_team(scope, attrs)
    team
  end

  @doc """
  Generate a employee.
  """
  def employee_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        email: "some email",
        name: "some name",
        role: "some role"
      })

    {:ok, employee} = TrialApp.Organization.create_employee(scope, attrs)
    employee
  end
end
