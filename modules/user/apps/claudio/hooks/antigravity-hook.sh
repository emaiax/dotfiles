#!/usr/bin/env bash
# PreToolUse Lifecycle Hook for Google Antigravity CLI (agy).
#
# Protocol:
#   - Input (stdin): JSON payload from agy: `{"toolCall": {"name": "<tool>", "args": { ... }}}`
#   - Argument ($1): Path to `claudio-policy.json` (compiled from permissions.nix)
#   - Output (stdout): JSON decision:
#       {"decision":"deny","reason":"..."}                     -> Abort tool call immediately
#       {"decision":"ask","reason":"..."}                      -> Prompt user interactively in TUI
#       {"decision":"allow"}                                   -> Execute tool as-is
#       {"decision":"allow","overwrite":{"CommandLine":"..."}} -> Execute rewritten command (e.g. RTK)
#
# This script enforces the unified Claudio security policy and token optimization on Antigravity CLI.
set -euo pipefail

POLICY_JSON="${1:-}"

PAYLOAD=$(cat)

TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.toolCall.name // empty')

# -----------------------------------------------------------------------------
# 1. Inspect file access operations
#
# What:
#   Intercepts direct filesystem tool calls (viewing, reading, creating, editing).
#
# Why:
#   Unlike Claude Code, Antigravity CLI does not have macOS Seatbelt sandbox filesystem
#   isolation. Without this check, an agent could read private keys or credentials and
#   leak their plaintext contents into the LLM conversation context.
#
# Examples:
#   - BLOCKED: view_file(AbsolutePath="~/.ssh/id_ed25519")
#              -> {"decision":"deny","reason":"Credential path blocked by claudio policy"}
#   - BLOCKED: replace_file_content(TargetFile="~/.aws/credentials")
#              -> {"decision":"deny","reason":"Credential path blocked by claudio policy"}
#   - ALLOWED: view_file(AbsolutePath="~/code/dotfiles/README.md")
#              -> continues to next checks / allow
# -----------------------------------------------------------------------------
if [[ "$TOOL_NAME" =~ ^(view_file|read_file|write_to_file|replace_file_content)$ ]]; then
  PATH_ARG=$(echo "$PAYLOAD" | jq -r '.toolCall.args.AbsolutePath // .toolCall.args.TargetFile // empty')

  if [[ -n "$PATH_ARG" && -f "$POLICY_JSON" ]]; then
    NORMALIZED_PATH="${PATH_ARG/#\~/${HOME:-}}"

    IS_CRED_DENIED=$(jq -r --arg path "$NORMALIZED_PATH" '
      (
        ((.filesystem.credentials.dirs + (.filesystem.credentials.extra // [])) |
        any(. as $dir | ($path == $dir or ($path | startswith($dir + "/")))))
      )
      or
      (
        ((.filesystem.credentials.files + (.filesystem.credentials.extra // [])) |
        any(. as $file | ($path == $file or ($path | startswith($file)))))
      )
    ' "$POLICY_JSON")

    if [[ "$IS_CRED_DENIED" == "true" ]]; then
      echo '{"decision":"deny","reason":"Credential path blocked by claudio policy"}'
      exit 0
    fi
  fi
fi

# -----------------------------------------------------------------------------
# 2. Inspect shell commands (run_command)
#
# What:
#   Inspects the command line string of shell tool calls before execution.
#
# Why:
#   Enforces credential leak protection, hard blocks on irreversible operations,
#   interactive confirmation gates on destructive commands, and RTK token compression.
# -----------------------------------------------------------------------------
if [[ "$TOOL_NAME" == "run_command" ]]; then
  CMD=$(echo "$PAYLOAD" | jq -r '.toolCall.args.CommandLine // empty')

  if [[ -n "$CMD" && -f "$POLICY_JSON" ]]; then
    # ---------------------------------------------------------------------------
    # 2.1. Credential leakage prevention in command strings
    #
    # What:
    #   Checks if the shell command references any protected credential file or dir.
    #
    # Why:
    #   Even if file tools are blocked, an agent could run `cat ~/.ssh/id_ed25519`
    #   or `grep token ~/.config/sops/keys.txt` to print secrets to stdout.
    #
    # Examples:
    #   - BLOCKED: run_command(CommandLine="cat ~/.ssh/id_ed25519")
    #              -> {"decision":"deny","reason":"Credential path blocked by claudio policy"}
    #   - BLOCKED: run_command(CommandLine="grep token ~/.config/sops/secrets.yaml")
    #              -> {"decision":"deny","reason":"Credential path blocked by claudio policy"}
    # ---------------------------------------------------------------------------
    HOME_DIR="${HOME:-$(jq -r '.filesystem.home // empty' "$POLICY_JSON")}"

    IS_CRED_IN_CMD=$(jq -r --arg cmd "$CMD" --arg home "$HOME_DIR" '
      def variants($h):
        . as $p |
        if ($h != "" and ($p | startswith($h))) then
          ($p | ltrimstr($h)) as $rel |
          [$p, "~" + $rel, "$HOME" + $rel, "${HOME}" + $rel]
        elif ($h != "" and ($p | startswith("~/"))) then
          ($p | ltrimstr("~")) as $rel |
          [$p, $h + $rel, "$HOME" + $rel, "${HOME}" + $rel]
        else
          [$p]
        end;

      (
        ((.filesystem.credentials.dirs + (.filesystem.credentials.extra // [])) |
        any(variants($home)[] as $v | ($cmd | contains($v))))
      )
      or
      (
        ((.filesystem.credentials.files + (.filesystem.credentials.extra // [])) |
        any(variants($home)[] as $v | ($cmd | contains($v))))
      )
    ' "$POLICY_JSON")

    if [[ "$IS_CRED_IN_CMD" == "true" ]]; then
      echo '{"decision":"deny","reason":"Credential path blocked by claudio policy"}'
      exit 0
    fi

    # Strip leading rtk prefix if present (e.g. `rtk git push` -> `git push`)
    BARE_CMD="${CMD#rtk }"

    # ---------------------------------------------------------------------------
    # 2.2. Hard denials (Irreversible repository operations)
    #
    # What:
    #   Strictly blocks irreversible forge commands (PR merging, release publishing).
    #
    # Why:
    #   Autonomous or pair-programming agents should never merge pull requests or
    #   publish releases without human presence and verification.
    #
    # Examples:
    #   - BLOCKED: run_command(CommandLine="gh pr merge 123 --auto")
    #              -> {"decision":"deny","reason":"Command is hard denied by claudio policy"}
    #   - BLOCKED: run_command(CommandLine="fj release create v1.0.0")
    #              -> {"decision":"deny","reason":"Command is hard denied by claudio policy"}
    # ---------------------------------------------------------------------------
    IS_DENIED=$(jq -r --arg cmd "$BARE_CMD" '
      ((.commands.deny // []) + (.commands.extraDeny // [])) |
      any(. as $entry |
        ($entry | rtrimstr(" *") | rtrimstr("*")) as $clean |
        ($cmd == $clean or ($cmd | startswith($clean + " ")))
      )
    ' "$POLICY_JSON")

    if [[ "$IS_DENIED" == "true" ]]; then
      echo '{"decision":"deny","reason":"Command is denied by claudio policy"}'
      exit 0
    fi

    # ---------------------------------------------------------------------------
    # 2.3. Destructive command gate (Interactive confirmation / Ask)
    #
    # What:
    #   Intercepts destructive git or filesystem commands and requires confirmation.
    #
    # Why:
    #   Commands like `git push`, `rm -rf`, or `git reset --hard` can cause irreversible
    #   data or history loss. In the standard `claudio` profile, the user must approve them.
    #   In YOLO mode (`CLAUDIO_DANGEROUSLY_SKIP_PERMISSIONS=1`), this prompt is bypassed.
    #
    # Examples:
    #   - PROMPT (claudio):      run_command(CommandLine="git push origin main")
    #                            -> {"decision":"ask","reason":"Command requires explicit confirmation per claudio policy"}
    #   - PROMPT (claudio):      run_command(CommandLine="rm -rf ./build")
    #                            -> {"decision":"ask","reason":"Command requires explicit confirmation per claudio policy"}
    #   - AUTO-ALLOW (claude-yolo): run_command(CommandLine="git push origin main")
    #                            -> continues to RTK rewrite / allow
    # ---------------------------------------------------------------------------
    if [[ -z "${CLAUDIO_DANGEROUSLY_SKIP_PERMISSIONS:-}" ]]; then
      IS_ASK=$(jq -r --arg cmd "$BARE_CMD" '
        (
          ((.commands.ask // []) + (.commands.extraAsk // [])) | any(. as $entry |
            ($entry | rtrimstr(" *") | rtrimstr("*")) as $clean |
            ($cmd == $clean or ($cmd | startswith($clean + " ")))
          )
        )
        or
        (
          ((.commands.askExact // []) | any(. as $entry | ($cmd == $entry)))
        )
      ' "$POLICY_JSON")

      if [[ "$IS_ASK" == "true" ]]; then
        echo '{"decision":"ask","reason":"Command requires explicit confirmation per claudio policy"}'
        exit 0
      fi
    fi
  fi

  # ---------------------------------------------------------------------------
  # 2.4. Token optimization via RTK rewrite
  #
  # What:
  #   Rewrites verbose commands through `rtk` (e.g. `git diff`, `git log`, `grep`).
  #
  # Why:
  #   Commands with high output volume consume excessive LLM context tokens.
  #   RTK compresses CLI tool outputs by up to 80-90% before the model reads them.
  #
  # Examples:
  #   - REWRITTEN: run_command(CommandLine="git log -n 5")
  #                -> {"decision":"allow","overwrite":{"CommandLine":"rtk git log -n 5"}}
  #   - REWRITTEN: run_command(CommandLine="grep -rn pattern .")
  #                -> {"decision":"allow","overwrite":{"CommandLine":"rtk grep -rn pattern ."}}
  #   - UNMODIFIED: run_command(CommandLine="echo hello")
  #                -> {"decision":"allow"}
  # ---------------------------------------------------------------------------
  if command -v rtk >/dev/null 2>&1; then
    REWRITTEN=$(rtk rewrite "$CMD" 2>/dev/null || true)
    if [[ -n "$REWRITTEN" && "$REWRITTEN" != "$CMD" ]]; then
      jq -n --arg cmd "$REWRITTEN" '{"decision":"allow","overwrite":{"CommandLine":$cmd}}'
      exit 0
    fi
  fi
fi

# -----------------------------------------------------------------------------
# 3. Default decision: Allow
#
# Safe, non-credential, non-destructive operations proceed without interruption.
# -----------------------------------------------------------------------------
echo '{"decision":"allow"}'
