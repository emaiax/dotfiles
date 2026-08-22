# dotfiles — project context

Declarative macOS configuration built on Nix flakes: nix-darwin + home-manager + nix-homebrew. This file documents the repo itself. Personal / user-level preferences are configured separately (published to `~/.claude/CLAUDE.md` and OpenCode's global context from `modules/user/apps/agent-shared/AGENTS.md`).

## Layout

- `flake.nix` — entrypoint. The only output is `darwinConfigurations`, built from `nix/inventory.nix` (per-host and per-user variables). No devShell.
- `nix/hosts/` — per-host overrides: `dudumini` (Intel), `dudupro` (Apple Silicon).
- `nix/profiles/` — user bundles (`emaiax.nix`) and host Homebrew (`brew.nix`).
- `modules/` — `core/`, `system/` (`common` + `darwin`), `pkgs/`, and `user/` (home-manager: `apps/`, `cli/`, `git/`, `shell/`, `packages/`).
- `modules/user/apps/claude-code/`, `modules/user/apps/opencode/` — generic Claude Code and OpenCode wiring, no dependency on `claudio/`. `modules/user/apps/agent-shared/` — AGENTS.md, command gates, and `skills/`, shared between the two. `modules/user/apps/claudio/` — the opinionated profile layer on top (`claudio`, `claudio-yolo`, `claudio-bot`, plus their test harness).
- `modules/user/apps/agent-jail/` — generic multi-profile Docker jail for running coding agents against an allowlisted directory (profile structure is public; real paths live in an encrypted secret).

## Working in this repo

- Apply: `just switch` (`git add . && sudo darwin-rebuild switch --flake .`). Validate without activating: `just build`. Update inputs: `just update`.
- `just switch` / `just build` stage everything with `git add .` — that is not a commit. Never commit or push without explicit confirmation; always branch first.
- Configure via a home-manager module rather than editing files under `~` directly.
- `home-manager.backupFileExtension = "bak"` — on activation, pre-existing real files are backed up to `*.bak` instead of blocking the switch.
- Format Nix with `nix fmt`. When moving a module, fix its relative `import` / `source` paths (they resolve from the file's own directory).

## CI

- `.forgejo/workflows/fast-ci.yml` — self-hosted, cheap: `nix fmt`, `nix flake check`, an eval-only check of the aarch64-darwin closure. Runs on this Forgejo instance's `docker` runner label.
- `.github/workflows/build.yml` — the real aarch64-darwin build, on GitHub's `macos-15` hosted runner (this instance has no macOS runner and can't build Darwin outputs cross-platform). Triggered by the automatic push-mirror to `github.com/emaiax/dotfiles`, not by direct pushes here.
- `.forgejo/workflows/gh-build-status.yml` — relays `build.yml`'s result onto this repo's commit status, from the Forgejo side. `forgejo.emx.casa` is LAN-only, so GitHub's runner has no path back here (a prior attempt at reporting status directly from GitHub always timed out); this self-hosted `docker` runner has both outbound internet, to poll the run via GitHub's public Actions API, and local access to post the result via this instance's own API using its automatic per-job token.
- Dependency updates: Renovate, run cross-repo from `emaiax/dudumox`'s own scheduled workflow (autodiscovers any repo the `renovate-bot` account has collaborator access to) — not a workflow in this repo, just `renovate.json`.
- `fast-ci.yml` depends on infrastructure that lives outside this repo: the repo variable `CI_IMAGE_REGISTRY`, the `homelab/dudumox-ci:latest` image (built in `emaiax/dudumox`'s `homelab/images` sibling), and a persistent `/nix` store volume allow-listed for the `docker` runner label. See `docs/superpowers/specs/2026-08-03-ci-forgejo-cutover-design.md` (local, gitignored) for the full design.

## Conventions

- Conventional commits, imperative mood, no trailing period, no `Co-authored-by`.
- Scope commits by module path, e.g. `feat(user/apps/claude-code): ...`.
