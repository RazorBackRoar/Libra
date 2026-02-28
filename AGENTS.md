# L!bra Project Agent Guide

**Package:** `libra`
**Version:** 0.1.15

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

---

## 🚀 Power-User Architecture & Quality Tools

This project follows the RazorBackRoar workspace power-user architecture for multi-agent coordination and standardized quality assurance.

### 📋 Multi-Agent Execution Protocol

**Control Plane:** AGENTS.md files serve as enforceable execution policies

**Branch Isolation:** One task per branch with naming conventions:
- `feat/task-name` - New features
- `fix/issue-description` - Bug fixes
- `refactor/component-name` - Code improvements

**Task Contract:** Standard task structure includes:
- Objective, scope, constraints, commands, deliverables
- Evidence bundle with diffs, test outputs, benchmarks
- Demo-like runbook for reproducible execution

### 🛠️ Standardized Quality Scripts

Load the master quality script for complete code quality workflow:

```bash
# Load all quality functions (run once per session)
source ~/.skills/scripts/quality.sh

# Quick development check
quality_quick

# Full check with auto-fixes and coverage
quality_full

# Strict pre-commit validation
quality_precommit

# Check specific file
quality_file src/libra/main.py
```

**Available Scripts:**
- `~/.skills/scripts/quality.sh` - Master script (test + lint + format)
- `~/.skills/scripts/test.sh` - Pytest execution with coverage
- `~/.skills/scripts/lint.sh` - Ruff linting + ty type checking
- `~/.skills/scripts/format.sh` - Ruff code formatting

**Quick Reference:**

```bash
# Individual operations
source ~/.skills/scripts/test.sh && test_quick
source ~/.skills/scripts/lint.sh && check_quick
source ~/.skills/scripts/format.sh && format_all

# Project setup with quality tools
source ~/.skills/scripts/quality.sh && setup_quality
```

### 📚 Documentation

- **Power-User Protocol:** `~/.skills/agents.md`
- **Quality Scripts:** `~/.skills/scripts/README.md`
- **Workspace Standards:** `/Users/home/Workspace/Apps/AGENTS.md`
