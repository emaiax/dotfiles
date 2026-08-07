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

## CI

- `.forgejo/workflows/fast-ci.yml` — self-hosted, cheap: `nix fmt`, `nix flake check`, an eval-only check of the aarch64-darwin closure. Runs on this Forgejo instance's `docker` runner label.
- `.github/workflows/build.yml` — the real aarch64-darwin build, on GitHub's `macos-15` hosted runner (this instance has no macOS runner and can't build Darwin outputs cross-platform). Triggered by the automatic push-mirror to `github.com/emaiax/dotfiles`, not by direct pushes here. Reports its result back to the Forgejo commit/PR via Forgejo's commit-status API (`FORGEJO_STATUS_TOKEN` GitHub secret).
- Dependency updates: Renovate, run cross-repo from `emaiax/dudumox`'s own scheduled workflow (autodiscovers any repo the `renovate-bot` account has collaborator access to) — not a workflow in this repo, just `renovate.json`.
- `fast-ci.yml` depends on infrastructure that lives outside this repo: the repo variable `CI_IMAGE_REGISTRY`, the `homelab/dudumox-ci:latest` image (built in `emaiax/dudumox`'s `homelab/images` sibling), and a persistent `/nix` store volume allow-listed for the `docker` runner label. See `docs/superpowers/specs/2026-08-03-ci-forgejo-cutover-design.md` (local, gitignored) for the full design.

## Conventions

- Conventional commits, imperative mood, no trailing period, no `Co-authored-by`.
- Scope commits by module path, e.g. `feat(user/apps/coding-agents): ...`.
