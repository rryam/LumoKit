# Agents

This document defines how automated agents should work in this repo.

## Scope
- Follow these guidelines for code, docs, and PRs.
- Keep changes small and focused.
- Prefer incremental changes with clear validation steps.
- Avoid unrelated formatting-only edits.

## Project overview
- LumoKit is a Swift package for on-device RAG workflows.
- Public API is defined in `Sources/LumoKit/LumoKit.swift`.
- Chunking logic lives in `Sources/LumoKit/Chunking/`.
- Tests live in `Tests/LumoKitTests/`.
- `README.md` is the source of truth for API examples and install info.

## Dependencies
- `PicoDocs` is used for document ingestion and parsing.
- `VecturaKit` handles vector storage and search.
- Keep any wrapper APIs aligned with upstream names and behavior.

## Development workflow
- Create a feature branch per task.
- Keep commits scoped and descriptive.
- Run `swiftlint`, `swift build`, and `swift test` before opening a PR.
- Keep README examples and API overview in sync with public API changes.
- Prefer `swift test` over selective runs unless tests are isolated.

## Coding guidelines
- Preserve public API stability unless a change is explicitly required.
- Favor clarity over cleverness in chunking logic.
- Use explicit error handling and avoid force unwraps.
- Add tests for behavior changes and regressions.
- Avoid non-ASCII text unless needed.
- Minimize allocations in chunking paths; reuse existing helper patterns.

## API changes
- If the public API changes, update `README.md` and add tests.
- For new features, include a short usage example in README or tests.
- When adding methods that wrap VecturaKit, mirror naming and behavior.
- Maintain async/await signatures consistent with existing public APIs.

## Chunking behavior
- Ensure chunks never exceed `chunkSize` unless explicitly documented.
- Avoid duplicating content when splitting oversized segments.
- Keep metadata positions consistent with original text offsets.
- Preserve content type in `ChunkMetadata`.
- Preserve overlap semantics and flags (`hasOverlapWithPrevious/Next`).

## Concurrency
- Keep heavy work off the main actor unless required by APIs.
- Avoid introducing shared mutable state across chunkers.
- Prefer pure functions and local state for chunking logic.

## Error handling
- Use `LumoKitError` for predictable user-facing failures.
- Wrap lower-level errors with context using `LumoKitError.chunkingFailed`.
- Avoid swallowing errors in fallbacks; wrap and rethrow.
- Keep error mappings consistent with existing `LumoKitError` cases.

## Testing
- Add regression tests for bugs and edge cases.
- Prefer small, deterministic inputs to reduce flakiness.
- When fixing chunking issues, add a test that would have failed before.
- Keep tests in `Tests/LumoKitTests/` and match existing naming patterns.

## Documentation
- Keep `README.md` examples and API overview up to date.
- Document new behaviors or breaking changes in release notes.
- Keep `Claude.md` as a simple pointer to this file.
- Update README version snippets when releasing new versions.

## Versioning and releases
- Follow semantic versioning; note breaking changes clearly.
- Include release notes for user-visible changes and fixes.
- Ensure `README.md` matches the latest release version.

## PR checklist
- Include a clear summary and testing notes.
- Call out any user-visible behavior changes.
- Link related issues or PRs when applicable.