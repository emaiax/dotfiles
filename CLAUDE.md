# Global Preferences

## Communication

- Explain reasoning briefly — why, not just what
- Be direct, skip pleasantries
- Assume familiarity with Linux/Nix internals — skip basics

## Workflow

- Never auto-commit without explicit confirmation
- Commit messages: conventional format (feat:, fix:, chore:, etc.)
- Ask before large refactors or structural changes
- Run tests before suggesting PRs

## Environment

- macOS (primary) and NixOS
- Shell: zsh
- Never suggest `apt` or `brew install` on NixOS
- Prefer `nix shell nixpkgs#<tool>` for ephemeral tooling needs
- For system/dotfile config changes: suggest home-manager modules first, not manual edits

## Project context

- Code style, imports, and framework conventions live in each project's CLAUDE.md
