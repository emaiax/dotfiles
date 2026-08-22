# 🏡 dotfiles

- Declarative macOS configuration built on Nix flakes: nix-darwin + home-manager + nix-homebrew
- This file documents the repo itself
- User-level preferences live separately: published to `~/.claude/CLAUDE.md`, and to OpenCode's global context from `modules/user/apps/claudio/AGENTS.md`

## Writing

- Never use AI-slop characters: no em dashes, no smart/curly quotes, no other telltale AI punctuation. Use a comma, a colon, or a period instead
- Be succinct: direct, low density, no filler. Bullets don't need a trailing period
- Hard-wrap comments in code at 120 columns, you should always write in prose

## Layout

- `flake.nix`: entrypoint. Builds `darwinConfigurations` from `nix/inventory.nix` (per-host and per-user settings). No `devShell`, no `nix develop` here
- `nix/hosts/`: per-Mac settings. `dudumini` (Intel), `dudupro` (Apple Silicon)
- `nix/profiles/`: per-user settings. `emaiax.nix` for packages/config that follow the user across hosts, `brew.nix` for Homebrew casks per host
- `modules/`: the actual configuration, split by scope
  - `core/`: baseline shared by everything else
  - `system/`: OS-level config. `common/` is OS-agnostic, `darwin/` is macOS-specific (nix-darwin)
  - `pkgs/`: custom packages not in nixpkgs
  - `user/`: home-manager config, scoped to the user's home. `apps/` (one entry per app), `cli/`, `git/`, `shell/`, `packages/` (general CLI tools)

## Working in this repo

- Consider `main` branch as read-only, always `worktree` first if you need to create or change anything
- Never push without asking, unless there's already an open PR for the branch, then pushing to keep it current is fine
- Change things through a home-manager module, not by hand-editing files under `$HOME`
- Activation backs up a pre-existing real file to `*.bak` instead of refusing (`home-manager.backupFileExtension = "bak"`)
- Format Nix with `nix fmt` before committing
- Moved a module? Fix its relative `import`/`source` paths too, they resolve from the file's own location, not from wherever it used to live

## Check and Apply the changes

- Runs `git add .` first to stage everything for Nix, that's staging, not a commit
- `just build`: build without applying, to check it's valid
- `just switch`: apply and activates the config. Needs sudo, leave that for the user unless told otherwise
- `just update`: update the flake's pinned dependency versions

## How to test your changes

- Run `nix fmt`, then `just build` (or `darwin-rebuild build --flake .#dudupro` or other host) to validate without activating
- New or moved files must be `git add`ed first, this is a git flake, untracked files are invisible to Nix and silently break relative imports
- `nix flake check` mirrors `fast-ci.yml`: format check, full flake check, evaluation-only build of the aarch64-darwin config
- Touched `modules/user/apps/claudio/profiles/`? Run its `tests/run.sh`, it probes actual sandbox/permission behavior for the coding-agent profiles
- Never claim a change works without having watched one of the above pass this session
