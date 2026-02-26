import re
import tomllib
from pathlib import Path

import pytest
from packaging.requirements import InvalidRequirement, Requirement

PEP508_IDENTIFIER_RE = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$")
PYPROJECT_PATH = Path(__file__).resolve().parents[1] / "pyproject.toml"


def _load_project_metadata() -> dict:
    with PYPROJECT_PATH.open("rb") as pyproject_file:
        return tomllib.load(pyproject_file).get("project", {})


def _assert_pep508_identifier(name: str, context: str) -> None:
    assert PEP508_IDENTIFIER_RE.fullmatch(name), (
        f"{context} must be a PEP 508 identifier. "
        "Use only letters, numbers, hyphens, underscores, and periods."
    )


def test_project_name_is_pep508_identifier() -> None:
    project_metadata = _load_project_metadata()
    project_name = project_metadata.get("name")
    assert project_name, "project.name is missing from pyproject.toml"
    _assert_pep508_identifier(project_name, "project.name")


def test_dependency_names_are_pep508_identifiers() -> None:
    project_metadata = _load_project_metadata()
    dependencies = project_metadata.get("dependencies", [])

    for dependency in dependencies:
        try:
            requirement = Requirement(dependency)
        except InvalidRequirement as exc:
            pytest.fail(f"Invalid dependency requirement in pyproject.toml: {dependency!r} ({exc})")
        _assert_pep508_identifier(requirement.name, f"Dependency name {requirement.name!r}")
