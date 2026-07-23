# dotfiles — project context

Declarative macOS configuration built on Nix flakes: nix-darwin + home-manager + nix-homebrew. This file documents the repo itself. Personal / user-level preferences are configured separately (published to `~/.claude/CLAUDE.md` and OpenCode's global context from `modules/user/apps/coding-agents/AGENTS.md`).

## Layout

- `flake.nix` — entrypoint. The only output is `darwinConfigurations`, built from `nix/inventory.nix` (per-host and per-user variables). No devShell.
- `nix/hosts/` — per-host overrides: `dudumini` (Intel), `dudupro` (Apple Silicon).
- `nix/profiles/` — user bundles (`emaiax.nix`) and host Homebrew (`brew.nix`).
- `modules/` — `core/`, `system/` (`common` + `darwin`), `pkgs/`, and `user/` (home-manager: `apps/`, `cli/`, `git/`, `shell/`, `packages/`).
- `modules/user/apps/coding-agents/` — Claude Code, OpenCode, and the shared agent `skills/`.
- `modules/user/apps/agent-jail/` — generic multi-profile Docker jail for running coding agents against an allowlisted directory (profile structure is public; real paths live in an encrypted secret).

## Working in this repo

- Apply: `just switch` (`git add . && sudo darwin-rebuild switch --flake .`). Validate without activating: `just build`. Update inputs: `just update`.
- `just switch` / `just build` stage everything with `git add .` — that is not a commit. Never commit or push without explicit confirmation; always branch first.
- Configure via a home-manager module rather than editing files under `~` directly.
- `home-manager.backupFileExtension = "bak"` — on activation, pre-existing real files are backed up to `*.bak` instead of blocking the switch.
- Format Nix with `nix fmt`. When moving a module, fix its relative `import` / `source` paths (they resolve from the file's own directory).

## Conventions

- Conventional commits, imperative mood, no trailing period, no `Co-authored-by`.
- Scope commits by module path, e.g. `feat(user/apps/coding-agents): ...`.
