Level 2 Document: Refer to /Users/home/Workspace/Apps/AGENTS.md (Level 1) for global SSOT standards.

# L!bra Project Agent Guide

**Package:** `libra`
**Version:** 0.1.4
**Context Level:** LEVEL 3 (Application-Specific)

L!bra is a project in the RazorBackRoar workspace.
This directory is the project root.

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

`~/Workspace/Skills/`

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
