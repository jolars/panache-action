# AGENTS.md

Guidance for agentic coding assistants in `panache-action`.

## Scope

- Repo type: composite GitHub Action.
- Purpose: install `panache` and run format/lint checks.
- Primary files: `action.yml`, `scripts/install-panache.sh`, `scripts/install-panache.ps1`.
- CI coverage: Linux/macOS/Windows on x64 and ARM64.

## Rules Files Status

- `.cursorrules`: not present.
- `.cursor/rules/`: not present.
- `.github/copilot-instructions.md`: not present.
- If any appear later, treat them as higher-priority instructions.

## Repository Map

- `action.yml`: action API (inputs/outputs) and execution steps.
- `scripts/install-panache.sh`: Unix installer.
- `scripts/install-panache.ps1`: Windows installer.
- `.github/workflows/test.yml`: integration tests.
- `.github/workflows/release.yml`: test + semantic-release.
- `.github/workflows/update-major-minor-tags.yml`: release tag maintenance.
- `fixtures/ok.md`, `fixtures/bad.md`: expected pass/fail fixtures.
- `.releaserc.json`: semantic-release + conventional commit settings.

## Tooling Assumptions

- No `package.json`, `Makefile`, or Python project files.
- No compile/build artifact pipeline.
- Tests are workflow-driven.
- Installer smoke checks require network access.

## Build/Lint/Test Commands

Run from repo root.

### Build

- No compile step exists.
- Use `.github/workflows/test.yml` as the main quality gate.

### Lint and Validation

- Shell syntax:
  - `sh -n scripts/install-panache.sh`
- PowerShell parse check:
  - `pwsh -NoLogo -NoProfile -Command "[void][ScriptBlock]::Create((Get-Content -Raw 'scripts/install-panache.ps1'))"`
- Optional stronger checks (if installed):
  - `shellcheck scripts/install-panache.sh`
  - `actionlint`

### Test

- Main workflow: `.github/workflows/test.yml`.
- Jobs:
  - `test-pass` should succeed with `fixtures/ok.md`.
  - `test-fail` should fail with `fixtures/bad.md` (failure is asserted).

### Run a Single Test

- Preferred local approach with `act`:
  - `act pull_request -W .github/workflows/test.yml -j test-pass`
  - `act pull_request -W .github/workflows/test.yml -j test-fail`

- Focused Unix smoke checks without `act`:
  - Pass path:
    - `tmpdir="$(mktemp -d)" && PANACHE_INSTALL_DIR="$tmpdir" bash scripts/install-panache.sh && "$tmpdir/panache" format --check fixtures/ok.md && "$tmpdir/panache" lint --check fixtures/ok.md`
  - Expected fail path:
    - `tmpdir="$(mktemp -d)" && PANACHE_INSTALL_DIR="$tmpdir" bash scripts/install-panache.sh && "$tmpdir/panache" format --check fixtures/bad.md`
    - Expect non-zero exit code.

### Release Dry Run

- `npx --yes --package @semantic-release/commit-analyzer --package @semantic-release/release-notes-generator --package @semantic-release/changelog --package @semantic-release/github --package @semantic-release/git semantic-release --dry-run`

## Code Style Guidelines

Follow existing patterns and keep diffs focused.

### General

- Preserve Unix/Windows behavior parity.
- Avoid broad refactors unless requested.
- Avoid formatting-only churn.
- Update `README.md` when behavior or API changes.

### YAML (`action.yml`, workflows)

- Use 2-space indentation.
- Keep input names kebab-case (`panache-version`).
- Keep action input booleans as strings (`"true"`, `"false"`).
- Keep OS conditionals explicit.
- Use clear step names, including platform qualifiers when helpful.

### Shell (`scripts/install-panache.sh`)

- Keep POSIX `sh` compatibility.
- Keep script prologue as:
  - `#!/usr/bin/env sh`
  - `set -eu`
- Use `case` for OS/arch branching.
- Quote variable expansions unless splitting is intentional.
- Print clear stderr errors and exit non-zero on unsupported cases.
- Keep temp cleanup deterministic (`trap` + `rm -rf`).

### PowerShell (`scripts/install-panache.ps1`)

- Keep `$ErrorActionPreference = 'Stop'` near top.
- Use descriptive camelCase names.
- Prefer explicit cmdlets over aliases.
- Use `try/finally` for cleanup.
- Throw explicit errors for unsupported architecture.

### JSON (`.releaserc.json`)

- Use 2-space indentation.
- Keep double-quoted keys.
- Keep plugin order/behavior stable unless intentionally changing release logic.

### Markdown (`README.md`)

- Keep examples runnable and in sync with `action.yml`.
- Keep inputs/outputs docs accurate.

## Imports, Types, Naming, Error Handling

- Imports/modules: none in primary source files; preserve simplicity.
- Types:
  - Treat action inputs/outputs as strings.
  - Parse explicitly when needed.
  - Use runtime type APIs in PowerShell where useful.
- Naming:
  - Action inputs: kebab-case.
  - Env vars: UPPER_SNAKE_CASE.
  - Shell locals/functions: lowercase (snake_case preferred).
  - PowerShell variables: camelCase.
- Error handling:
  - Fail fast on invalid OS/architecture.
  - Keep messages actionable and include offending values.
  - Preserve non-zero exit codes for failures.
  - Assert expected failures in tests.

## API and Compatibility

- Public API is `action.yml` inputs/outputs.
- Input/output changes may be breaking; update docs and examples together.
- Do not rename existing inputs casually.

## Security and Safety

- Download artifacts only over HTTPS from GitHub Releases.
- Never log secrets/tokens.
- Treat release/tag automation edits as high risk.

## Agent Checklist

- Keep changes minimal and targeted.
- Run syntax checks for touched scripts.
- Run at least one focused test job when behavior changes.
- Keep README tables/examples aligned with behavior.
- Use Conventional Commits (`feat:`, `fix:`, `chore:`).

## Release Notes Convention

- semantic-release reads commit intent from conventional commits.
- Use `feat:` for user-facing additions.
- Use `fix:` for behavior corrections.
- Use `chore:` for maintenance/internal updates.

## Avoid

- Do not expand CI matrix scope without clear reason.
- Do not add one-platform behavior without parity consideration.
- Do not introduce unnecessary new dependencies.
- Do not mix unrelated refactors into functional changes.
