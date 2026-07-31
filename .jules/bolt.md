# Bolt Performance Agent Guidelines

- **Duplicate Check**: Verify performance optimization target has not already been addressed in `main`.
- **Targeted Scope**: Ensure benchmark and profiling claims are included in the PR description.
- **Branch Naming**: Always use the prefix `bolt-` for performance optimization PRs.

## 2026-02-20 - Swift withTaskGroup progress closure execution
**Learning:** `Scanner.swift` in `L!bra` is marked `@MainActor`. The `for await result in group` loop resumes on the exact same execution context (executor) as the original `for` loop, so hopping to the `MainActor` using `await MainActor.run` is unnecessary and could trigger strict concurrency warnings with non-@Sendable closures in modern Swift versions.
**Action:** When working with async sequences like TaskGroup inside `@MainActor` contexts, you don't need manual actor hops for UI updates within the continuation of the async call.
