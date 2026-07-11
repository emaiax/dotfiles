# Agent rules

Hard rules are absolute — violating one is a failure, not a judgment call. Everything under Defaults you may override only when I say so, in the moment.

## Never

- Never touch `main` — it's READ-ONLY. Worktree + branch before any change.
- Never commit, push, or post anything external (PR, GitHub comment, review result) until I approve that exact action, this turn.
- Never run a destructive or irreversible command (`rm`, `git reset --hard`, force-push, dropping data) without that same explicit, this-turn approval.
- Approval is per-action and per-turn — it never carries forward, and silence, an emoji, or an earlier "looks good" is not consent. When in doubt, ask before acting.
- Never sign your output — no footer, signature, or `Co-authored-by`, anywhere (commits, PRs, comments).
- Never hard-wrap prose you generate — no column width, ever, unless I ask:
  - Prose (one raw line per paragraph, no matter the length; let the renderer wrap it): commit message bodies, PR/issue descriptions, doc paragraphs, multi-sentence code comments, chat responses.
  - Not prose — line breaks are structural and always fine: markdown headers, list items (one item = one line), table rows, code/YAML/JSON blocks, blockquote lines.
- Never `brew install` or `apt` — ephemeral tools go through `nix shell nixpkgs#<tool>`.
- Never hand-edit dotfiles under `$HOME/` when a home-manager module can do it.
- Never claim something works without having watched it pass this session.
- Never assert a factual claim or assumption without an external reference link — with no source, label it unverified instead of stating it as fact.

## Defaults

- Reply in pt-BR when I write pt-BR; keep code, commits, PRs, and docs in English.
- Be direct: give the why, skip basics and pleasantries, and offer two or three options instead of a survey.
- Plan non-trivial work in phases with a confirmation gate between steps; one logical commit per unit; test-driven.
- Read the actual CI log before proposing a fix; separate rebase/formatter noise from a real regression.
- Run project commands inside `nix develop` when the project provides one.

## Context

- macOS locally, Linux (NixOS) on homelab servers — never cross their tooling assumptions.
- Stack: nix-darwin + home-manager (flakes), nix-homebrew for casks.
