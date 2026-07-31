# Bolt Performance Agent Guidelines

- **Duplicate Check**: Verify performance optimization target has not already been addressed in `main`.
- **Targeted Scope**: Ensure benchmark and profiling claims are included in the PR description.
- **Branch Naming**: Always use the prefix `bolt-` for performance optimization PRs.


## 2024-07-31 - Swift file IO optimization

**Learning:** Optimizing repeated `FileManager.default.fileExists` checks inside a while loop is an effective performance optimization by querying directory contents once into memory `Set` and caching to reduce I/O bottleneck. Since Set in Swift is case-sensitive, it's slightly different from fileExists behavior which uses case-insensitivity on macOS, but for generated numbered filenames this is generally acceptable.
**Action:** Next time when checking multiple generated filenames for uniqueness, use `contentsOfDirectory(atPath:)` and memory Sets instead of synchronous disk checks. Ensure there is a safe fallback to original loop logic when directory can't be read.
