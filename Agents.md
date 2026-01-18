# Agents

This document defines how automated agents should work in this repo.

## Scope
- Follow these guidelines for code, docs, and PRs.
- Keep changes small and focused.

## Project overview
- LumoKit is a Swift package for on-device RAG workflows.
- Core code lives in `Sources/LumoKit/`.
- Tests live in `Tests/LumoKitTests/`.

## Development workflow
- Run `swiftlint`, `swift build`, and `swift test` before opening a PR.
- Keep README examples and API overview in sync with public API changes.

## Coding guidelines
- Preserve public API stability unless a change is explicitly required.
- Add tests for behavior changes and regressions.
- Avoid non-ASCII text unless needed.

## PR checklist
- Include a clear summary and testing notes.
- Call out any user-visible behavior changes.
