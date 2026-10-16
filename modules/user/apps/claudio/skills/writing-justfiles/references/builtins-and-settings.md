# Just Built-ins, Settings, and Attributes Reference

Comprehensive reference for settings, built-in functions, attributes, and variables available in the `just` command runner. Source: [Just Programmer's Manual](https://just.systems/man/en/).

## Settings

Declare settings at the top of the justfile before recipe declarations.

| Setting | Type | Default | Description |
|---|---|---|---|
| `set dotenv-load := true` | bool | `false` | Automatically loads variables from `.env` in the justfile directory or parent directories into recipe environments. |
| `set dotenv-filename := ".env.local"` | string | `".env"` | Specifies the dotenv filename to load. |
| `set dotenv-path := "path/to/.env"` | string | unset | Specifies explicit path to the dotenv file. |
| `set export := true` | bool | `false` | Automatically exports all justfile variables and recipe parameters into child process environments. |
| `set positional-arguments := true` | bool | `false` | Passes recipe arguments as positional arguments (`$1`, `$2`, `$@`) to the execution shell. |
| `set fallback := true` | bool | `false` | If a requested recipe is not found in the current justfile, searches parent directories recursively until found. |
| `set quiet := true` | bool | `false` | Suppresses echoing recipe command lines to stderr before executing them. |
| `set shell := ["bash", "-cu"]` | list | `["sh", "-cu"]` | Sets the shell and arguments used to execute each line in linewise recipes. |
| `set script-interpreter := ["bash", "-euo", "pipefail"]` | list | `["sh", "-eu"]` | Sets the default interpreter for recipes marked with the `[script]` attribute without arguments. |
| `set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]` | list | unset | Sets the execution shell on Windows platforms. Has precedence over `set shell`. |
| `set tempdir := "/tmp/just"` | string | system temp | Sets the directory where temporary scripts for shebang and script recipes are generated. |
| `set ignore-comments := true` | bool | `false` | Ignores comment lines above recipes so they are not captured as recipe descriptions in `just --list`. |

## Recipe Attributes

Apply attributes directly above a recipe definition inside brackets `[...]`. Multiple attributes can be separated by commas: `[private, no-cd]`.

| Attribute | Syntax | Description |
|---|---|---|
| `doc` | `[doc("Description text")]` | Sets the documentation string displayed in `just --list`. Overrides comment blocks. |
| `private` | `[private]` | Hides the recipe from `just --list`. Recipes starting with `_` are private by default. |
| `confirm` | `[confirm("Prompt text")]` or `[confirm]` | Prompts user for interactive confirmation before running the recipe. Aborts if denied. |
| `no-cd` | `[no-cd]` | Executes the recipe in the directory where `just` was invoked instead of the justfile directory. |
| `no-exit-message` | `[no-exit-message]` | Suppresses the default `error: Recipe failed with exit code N` message if the recipe fails. |
| `script` | `[script]` or `[script('bash')]` | Runs the entire recipe body as a single script file with the given interpreter. |
| `group` | `[group("build")]` | Categorizes recipes under a section header in `just --list`. |
| `parallel` | `[parallel]` | Runs the recipe's dependencies concurrently rather than sequentially. |
| `macos` | `[macos]` | Restricts recipe to macOS systems. |
| `linux` | `[linux]` | Restricts recipe to Linux systems. |
| `windows` | `[windows]` | Restricts recipe to Windows systems. |
| `unix` | `[unix]` | Restricts recipe to Unix-like systems (Linux, macOS, BSD). |

## Built-in Functions

All functions are evaluated by `just` before recipes execute.

### Filesystem and Paths

| Function | Signature | Description |
|---|---|---|
| `justfile()` | `justfile() -> string` | Returns the absolute path to the current justfile. |
| `justfile_directory()` | `justfile_directory() -> string` | Returns the absolute directory containing the current justfile. |
| `invocation_directory()` | `invocation_directory() -> string` | Returns the absolute directory where `just` was invoked. |
| `path_exists(path)` | `path_exists(path) -> string` | Returns `"true"` if the path exists, `"false"` otherwise. |
| `file_name(path)` | `file_name(path) -> string` | Returns the final component of a path. |
| `parent_directory(path)` | `parent_directory(path) -> string` | Returns the parent directory of a path. |
| `extension(path)` | `extension(path) -> string` | Returns the file extension without the leading dot. |
| `clean(path)` | `clean(path) -> string` | Returns the canonical normalized representation of a path without resolving symlinks. |
| `canonicalize(path)` | `canonicalize(path) -> string` | Resolves all symlinks and returns the canonical absolute path. |
| `without_extension(path)` | `without_extension(path) -> string` | Returns the path with the extension removed. |

### Environment and System

| Function | Signature | Description |
|---|---|---|
| `env(key, default)` | `env(key, default) -> string` | Returns the value of environment variable `key`, or `default` if unset. |
| `env_var(key)` | `env_var(key) -> string` | Returns the value of environment variable `key`. Errors if unset. |
| `env_var_or_default(key, default)` | `env_var_or_default(key, default) -> string` | Returns the value of environment variable `key`, or `default` if unset. |
| `os()` | `os() -> string` | Returns the operating system identifier: `"linux"`, `"macos"`, `"windows"`, `"freebsd"`, etc. |
| `os_family()` | `os_family() -> string` | Returns the operating system family: `"unix"` or `"windows"`. |
| `arch()` | `arch() -> string` | Returns the machine architecture: `"x86_64"`, `"aarch64"`, `"arm"`, etc. |
| `num_cpus()` | `num_cpus() -> string` | Returns the number of logical CPU cores. |

### Strings and Formatting

| Function | Signature | Description |
|---|---|---|
| `quote(string)` | `quote(string) -> string` | Wraps a string in single quotes and escapes embedded quotes for safe shell evaluation. |
| `trim(string)` | `trim(string) -> string` | Strips leading and trailing whitespace. |
| `trim_start(string)` | `trim_start(string) -> string` | Strips leading whitespace. |
| `trim_end(string)` | `trim_end(string) -> string` | Strips trailing whitespace. |
| `replace(string, from, to)` | `replace(string, from, to) -> string` | Replaces occurrences of `from` with `to`. |
| `replace_regex(string, regex, to)` | `replace_regex(string, regex, to) -> string` | Replaces matches of regular expression `regex` with `to`. |
| `lowercase(string)` | `lowercase(string) -> string` | Converts string to lowercase. |
| `uppercase(string)` | `uppercase(string) -> string` | Converts string to uppercase. |
| `kebabcase(string)` | `kebabcase(string) -> string` | Converts string to kebab-case. |
| `snakecase(string)` | `snakecase(string) -> string` | Converts string to snake_case. |
| `split(string, delimiter)` | `split(string, delimiter) -> list` | Splits string into an array by delimiter. |
| `join(list, separator)` | `join(list, separator) -> string` | Joins a list into a string using the separator. |
| `uuid()` | `uuid() -> string` | Generates a random UUID v4 string. |
| `datetime(format)` | `datetime(format) -> string` | Returns current UTC timestamp formatted using chrono strftime specifiers. |
