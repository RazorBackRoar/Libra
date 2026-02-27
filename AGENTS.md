# L!bra Project Agent Guide

**Package:** `libra`
**Version:** 0.1.14

## Scope

L!bra is a project in the RazorBackRoar workspace.
This directory is the project root.

---

## 🎯 Quick Context

- **Purpose:** Native macOS video workflow suite — drag-and-drop sorting, metadata-aware classification, duplicate detection, and filename sanitization pipelines
- **Primary Tech:** PySide6, `.razorcore` (build/save tooling)
- **Key Modules:** `video_tools/` (sorter, duplicate_finder, apple_organizer, batch_processor), `core/`, `gui/`
- **Build Commands:** `librabuild` or `razorbuild L!bra`

> **Note:** `video_tools/**` is excluded from `ty` type-checking (known blind spot — unannotated ffmpeg/subprocess signatures). Ruff linting still covers it. See `pyproject.toml` `[tool.ty.src]` for details.

---

## Agent Behavior

Agents should:

1. Treat this directory as the project root.
2. Read this AGENTS.md first.
3. Then consult global Skills.

Nearest AGENTS.md overrides higher levels.

---

## Skills

Global skills live in:

`~/.skills/`

Agents should consult Skills before generating:

- Code
- Configurations
- Tooling setups

---

## Project Purpose

L!bra contains application code and supporting media utilities.
It is part of the shared RazorBackRoar app ecosystem.

---

## Ecosystem Integration

- L!bra depends on `.razorcore`. Install with:
  `uv add --editable ../.razorcore`
- Keep compatibility with workspace commands such as:
  `librabuild`, `librapush`, and `razorbuild L!bra`
- Use `uv` for all environment and dependency management (`uv venv`, `uv sync`, `uv run`).

---

## Rules

- Keep changes minimal and targeted.
- Avoid unnecessary duplication.
- Prefer shared Skills and shared tooling.
- Preserve symlinks and project structure.
