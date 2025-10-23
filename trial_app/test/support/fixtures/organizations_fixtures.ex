defmodule TrialApp.OrganizationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TrialApp.Organizations` context.
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

    {:ok, department} = TrialApp.Organizations.create_department(scope, attrs)
    department
  end

  @doc """
  Generate a team.
  """
  def team_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        description: "some description",
        name: "some name"
      })

    {:ok, team} = TrialApp.Organizations.create_team(scope, attrs)
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
        position: "some position"
      })

    {:ok, employee} = TrialApp.Organizations.create_employee(scope, attrs)
    employee
  end

  @doc """
  Generate a position.
  """
  def position_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        description: "some description",
        title: "some title"
      })

    {:ok, position} = TrialApp.Organizations.create_position(scope, attrs)
    position
  end
end
