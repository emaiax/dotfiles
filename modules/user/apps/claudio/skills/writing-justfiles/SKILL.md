---
name: writing-justfiles
description: Use when creating, modifying, or refactoring justfiles, defining recipes, or automating tasks with the just command runner.
---

# Writing Justfiles

This guide establishes conventions, syntax rules, and patterns for authoring `justfile` automation with the `just` command runner.

## When to Use

- Creating a new `justfile` for a project or workspace.
- Adding, refactoring, or optimizing recipes, parameters, and dependencies.
- Standardizing project commands across development, CI, testing, and container workflows.
- Fixing argument splitting, environment propagation, or cross-platform recipe failures.

When NOT to use:
- Tracking file-to-file build dependencies where targets must rebuild only when source files change. Use a build system (`make`, `cargo`, `ninja`) instead.
- Simple single-purpose shell scripts without tasks or arguments. Use a plain shell script.

## Core Rules

| Situation | Action | Reason |
|---|---|---|
| Multi-line recipe logic | Use `[script('bash')]` with `set -euo pipefail` | Default linewise execution spawns a new subshell per line. State, variables, and directory changes do not persist across lines. |
| Parameter interpolation in shell | Wrap with `quote(param)`: `{{quote(param)}}` | Bare `{{param}}` injects unquoted text before shell tokenization, causing word splitting on spaces and quotes. |
| Variadic passthrough flags | Use bare `{{args}}` with `*args` | Unquoted variadic arguments allow the shell to split distinct flags like `--flag value`. |
| Multi-line comment block | Add `[doc("One-line description")]` | `just --list` reads only the last line of a comment block if `[doc]` is omitted. |
| Reversible helper recipe | Prefix name with `_` or add `[private]` | Keeps `just --list` output scannable and focused on user-facing tasks. |
| Destructive action | Add `[confirm]` attribute | Enforces user confirmation before execution. |
| Command executed in caller directory | Add `[no-cd]` attribute | By default `just` switches current directory to the justfile root. |
| Exit with expected non-zero code | Add `[no-exit-message]` | Suppresses just's default error banner when a script deliberately exits with non-zero status. |

## Quick Reference

### Command Line Flags

| Flag | Purpose |
|---|---|
| `just --list` or `just -l` | Lists available recipes with descriptions and groups. |
| `just --dump --dump-format json` | Dumps the full parsed AST (recipes, params, deps, settings) in JSON format for agent inspection. |
| `just --summary` | Outputs a flat, space-separated list of recipe names. |
| `just --evaluate` | Prints evaluated values of all justfile variables. |
| `just --dry-run recipe` | Previews commands without executing them. |
| `just --verbose recipe` | Prints each command before running it. |
| `just --fmt --check --unstable` | Verifies justfile formatting against canonical style without modifying files. |
| `just --fmt --unstable` | Re-formats justfile in place to canonical 4-space indentation. |

### Essential Attributes

| Attribute | Effect |
|---|---|
| `[doc("...")]` | Explicit description displayed in `just --list`. Overrides comment blocks. |
| `[private]` | Hides recipe from listings. Shorthand: prefix recipe name with `_`. |
| `[confirm]` | Prompts for confirmation before running destructive actions. |
| `[no-cd]` | Stays in the directory from which `just` was called instead of the justfile directory. |
| `[no-exit-message]` | Suppresses just's error report if recipe exits with non-zero status. |
| `[script('bash')]` | Executes the recipe body as a single script file using the specified interpreter. |
| `[group('name')]` | Clusters recipes under a named section in `just --list`. |
| `[parallel]` | Runs prerequisite dependencies concurrently. |
| `[linux]`, `[macos]`, `[windows]` | Restricts recipe to specific operating systems. |

Full catalog of attributes, functions, and settings lives in [references/builtins-and-settings.md](references/builtins-and-settings.md).

## Execution Models

`just` supports three distinct recipe execution models:

### 1. Linewise Recipes (Default)

Each line executes in its own subshell. Variables, exported state, and directory changes do not carry over to subsequent lines:

```just
build:
    cd src
    cargo build # Fails if cargo expects to run inside src: previous line ran in a separate subshell!
```

Use line continuations (`\`) or compound commands (`&&`) if you must stay in linewise mode:

```just
build:
    cd src && cargo build
```

### 2. Script Recipes (`[script]`)

The `[script]` attribute (introduced in v1.33.0) executes the entire body as a single script file. Variables, control flow, loops, and directory changes persist naturally across lines:

```just
[script('bash')]
deploy env="staging":
    set -euo pipefail
    target_dir="/var/deploy/{{env}}"
    mkdir -p "$target_dir"
    cd "$target_dir"
    ./bin/activate
```

Prefer `[script('bash')]` over shebang recipes. It avoids cross-platform shebang splitting issues (such as Linux requiring `-S` on `env` while macOS does not, or Windows `cygpath` friction).

To set bash as the default interpreter for bare `[script]` attributes:

```just
set script-interpreter := ["bash", "-euo", "pipefail"]
```

### 3. Shebang Recipes

Recipes starting with `#!` execute as a script via the specified interpreter:

```just
analyze:
    #!/usr/bin/env python3
    import json, sys
    print("Executing Python directly in recipe body")
```

## Parameters and Quoting Safety

### The Word-Splitting Trap

`just` interpolates `{{parameter}}` as raw text before passing the line to the shell. If the value contains spaces, quotes, or glob characters, the shell tokenizes it into multiple distinct arguments.

```just
# DANGEROUS: Splices unquoted text directly into shell command
test path:
    pytest {{path}} # If path is "tests/unit test.py", shell executes: pytest tests/unit test.py
```

### Quoting Rules

1. Wrap string or path arguments with the built-in `quote()` function:

```just
# SAFE: quote() adds single quotes and escapes embedded quotes
test path:
    pytest {{quote(path)}}
```

2. Keep variadic passthrough flags `*args` bare:

```just
# SAFE: Named parameter is safely quoted; flags remain space-separated for shell parsing
test path *args:
    pytest {{quote(path)}} {{args}}
```

3. Export parameters directly to the subshell environment with a `$` prefix:

```just
# SAFE: $target is exported into process environment; access as regular shell variable $target
deploy $target:
    ./scripts/deploy.sh "$target"
```

### Argument Forms

```just
# Required positional
run target:
    ./bin/{{quote(target)}}

# Optional parameter with default
server port="8080":
    ./bin/server --port {{quote(port)}}

# Variadic passthrough (zero or more arguments)
pytest *flags:
    uv run pytest {{flags}}

# Variadic required (one or more arguments)
compile +files:
    cc {{files}}
```

## Recipe Documentation and `--list` Rules

`just --list` renders a single description line per recipe. It applies these strict rules:

### 1. Comment Blocks vs `[doc]`

Without `[doc]`, `just --list` reads ONLY the last line of the comment block immediately above the recipe:

```just
# Runs the full linter test suite.
# Usage: just lint --fix
lint:
```

The listing displays `Usage: just lint --fix`, discarding the first line.

Add `[doc("...")]` whenever a recipe comment exceeds one line:

```just
# Extended documentation and examples go here in comments.
# Usage: just lint --fix
[doc("Run linter with optional auto-fix flag.")]
lint *flags:
```

### 2. Comment Adjacency

Comments bind to recipes strictly by adjacency. A blank line breaks the association.

```just
# Build the application
# (blank line below breaks binding!)

build:
    cargo build
```

The listing for `build` will show empty documentation.

### 3. Required Positionals Block `--help`

Recipes with required positional arguments fail immediately when invoked with `--help`:

```
$ just deploy --help
error: recipe `deploy` got 1 positional argument but takes at least 2
```

Do not expect `--help` forwarding on recipes with required parameters. Document arguments in `[doc]` or provide a dedicated `help` recipe.

## Modular Justfiles

Split large project automation across files to keep responsibilities separated:

### 1. Imports (`import`)

Incorporate recipes into the root namespace:

```just
import? '.just/build.just'
import? '.just/test.just'
import? '.just/deploy.just'
```

Use `?` after `import` to make the file optional (prevents hard errors if a local override file is missing).

### 2. Submodules (`mod`)

Organize recipes under explicit namespaced subcommands:

```just
mod db '.just/db.just'
mod docker '.just/docker.just'
```

Run recipes using submodule path syntax: `just db::migrate`, `just docker::up`. Note: `set fallback` does not propagate across module boundaries.

## Golden Justfile Template

Use this template as the standard baseline for repository automation:

```just
# Default task runner configuration
# Documentation: https://just.systems/man/en/

set dotenv-load := true
set script-interpreter := ["bash", "-euo", "pipefail"]

# Variables
root_dir := justfile_directory()

# Lists available recipes
[default]
default:
    @just --list

###############################################################################
# Development
###############################################################################

# Starts local development servers
[group('dev')]
dev:
    @echo "Starting development environment..."

###############################################################################
# Code Quality
###############################################################################

# Runs all read-only linters and formatting checks
[group('quality')]
check: format-check lint

# Checks formatting without modifying source files
[group('quality')]
format-check *args:
    @echo "Verifying code format..."

# Formats source code in place
[group('quality')]
format *args:
    @echo "Formatting code..."

# Runs static analysis linters
[group('quality')]
lint *args:
    @echo "Linting codebase..."

###############################################################################
# Testing
###############################################################################

# Runs test suite with optional arguments
[group('test')]
test *args:
    @echo "Running tests..."

###############################################################################
# Maintenance and Housekeeping
###############################################################################

# Cleans temporary build artifacts and caches
[group('maintenance'), confirm("Remove all build artifacts and caches?")]
clean:
    rm -rf dist/ build/ .cache/

# Internal initialization check
[private, no-exit-message, script('bash')]
_check-env:
    if [ ! -f "{{root_dir}}/.env" ]; then
        echo "Missing .env file. Copy .env.example first." >&2
        exit 1
    fi
```

## Common Mistakes and Fixes

| Mistake | Bad Example | Good Example |
|---|---|---|
| Unquoted path argument | `cat {{file}}` | `cat {{quote(file)}}` |
| Multi-line state loss | `cd dir`<br>`make` | `[script('bash')]`<br>`cd dir`<br>`make` |
| Comment truncated in `--list` | `# Overview line`<br>`# Flags: --json`<br>`run:` | `[doc("Overview line")]`<br>`# Flags: --json`<br>`run:` |
| Calling `--help` on required arg | `deploy env:`<br>`$ just deploy --help` (errors) | `[doc("Deploy to target (e.g. staging, prod)")]`<br>`deploy env="staging":` |
| Hardcoded path from caller cwd | `cat config.yml` | `cat "{{justfile_directory()}}/config.yml"` |
| Mixed tab and space indentation | `  echo 1`<br>`    echo 2` | Use consistent 4 spaces throughout. Run `just --fmt --unstable`. |

## Verification and Maintenance

Run these checks whenever creating or updating a justfile:

1. Validate canonical formatting:
```bash
just --fmt --check --unstable
```
If formatting fails, re-format using `just --fmt --unstable`.

2. Inspect the recipe catalog:
```bash
just --list
```
Verify every recipe displays a clear single-line description and expected grouping.

3. Verify variable evaluation:
```bash
just --evaluate
```

4. Dry-run key recipes:
```bash
just --dry-run <recipe>
```
