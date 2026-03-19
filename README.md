# GitHub Action for Panache <img src='https://raw.githubusercontent.com/jolars/panache/refs/heads/main/images/logo.png' align="right" width="139" />

A GitHub Action that installs [panache](https://github.com/jolars/panache) and
runs formatting and lint checks in CI.

The action installs prebuilt release artifacts and supports GitHub-hosted
runners for Linux, macOS, and Windows on both x64 and ARM64.

## Usage

### Basic

```yaml
name: panache

on:
  pull_request:
  push:
    branches: [main]

jobs:
  panache:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: jolars/panache-action@v1
```

### Pin panache version

```yaml
- uses: jolars/panache-action@v1
  with:
    version: v2.23.0
```

### Format only

```yaml
- uses: jolars/panache-action@v1
  with:
    lint: "false"
```

### Lint only

```yaml
- uses: jolars/panache-action@v1
  with:
    format: "false"
```

### Use custom config

```yaml
- uses: jolars/panache-action@v1
  with:
    config: .panache.toml
```

## Inputs

| Input     | Description                                       | Default  |
| --------- | ------------------------------------------------- | -------- |
| `path`    | File or directory to check                        | `.`      |
| `version` | Panache version to install (`latest` or `vX.Y.Z`) | `latest` |
| `format`  | Run `panache format --check`                      | `true`   |
| `lint`    | Run `panache lint --check`                        | `true`   |
| `config`  | Optional path to panache config file              | `""`     |

## Outputs

| Output    | Description                   |
| --------- | ----------------------------- |
| `version` | Installed panache CLI version |

## Versioning

This action uses semantic versioning based on action API changes:

- Major: breaking changes to action inputs/outputs/behavior
- Minor: backward-compatible features
- Patch: fixes and internal improvements

Use `@v1` for stable major updates, or pin exact tags like `@v1.2.3`.
