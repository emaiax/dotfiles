#!/usr/bin/env bash
set -euo pipefail

POLICY_JSON="${1:-}"

PAYLOAD=$(cat)

TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.toolCall.name // empty')

# 1. Inspect file access operations
if [[ "$TOOL_NAME" =~ ^(view_file|read_file|write_to_file|replace_file_content)$ ]]; then
  PATH_ARG=$(echo "$PAYLOAD" | jq -r '.toolCall.args.AbsolutePath // .toolCall.args.TargetFile // empty')

  if [[ -n "$PATH_ARG" && -f "$POLICY_JSON" ]]; then
    IS_CRED_DENIED=$(jq -r --arg path "$PATH_ARG" '
      (.filesystem.credentials.dirs | any(. as $dir | ($path == $dir or ($path | startswith($dir + "/")))))
      or
      (.filesystem.credentials.files | any(. as $file | ($path == $file or ($path | startswith($file)))))
    ' "$POLICY_JSON")

    if [[ "$IS_CRED_DENIED" == "true" ]]; then
      echo '{"decision":"deny","reason":"Credential path blocked by claudio policy"}'
      exit 0
    fi
  fi
fi

# 2. Inspect shell commands
if [[ "$TOOL_NAME" == "run_command" ]]; then
  CMD=$(echo "$PAYLOAD" | jq -r '.toolCall.args.CommandLine // empty')

  if [[ -n "$CMD" && -f "$POLICY_JSON" ]]; then
    # Check if command directly touches any credential dir/file
    IS_CRED_IN_CMD=$(jq -r --arg cmd "$CMD" '
      (.filesystem.credentials.dirs | any(. as $dir | ($cmd | contains($dir))))
      or
      (.filesystem.credentials.files | any(. as $file | ($cmd | contains($file))))
    ' "$POLICY_JSON")

    if [[ "$IS_CRED_IN_CMD" == "true" ]]; then
      echo '{"decision":"deny","reason":"Credential path blocked by claudio policy"}'
      exit 0
    fi

    # Strip leading rtk prefix if present
    BARE_CMD="${CMD#rtk }"

    # Check hard denials
    IS_DENY_HARD=$(jq -r --arg cmd "$BARE_CMD" '
      .commands.denyHard |
      any(. as $entry | ($cmd == $entry or ($cmd | startswith($entry + " "))))
    ' "$POLICY_JSON")

    if [[ "$IS_DENY_HARD" == "true" ]]; then
      echo '{"decision":"deny","reason":"Command is hard denied by claudio policy"}'
      exit 0
    fi

    # Check ask list (commands that require confirmation)
    # If CLAUDIO_DANGEROUSLY_SKIP_PERMISSIONS=1 is set, auto-allow
    if [[ -z "${CLAUDIO_DANGEROUSLY_SKIP_PERMISSIONS:-}" ]]; then
      IS_ASK=$(jq -r --arg cmd "$BARE_CMD" '
        (.commands.ask | any(. as $entry | ($cmd == $entry or ($cmd | startswith($entry + " ")))))
        or
        (.commands.askExact | any(. as $entry | ($cmd == $entry)))
      ' "$POLICY_JSON")

      if [[ "$IS_ASK" == "true" ]]; then
        echo '{"decision":"ask","reason":"Command requires explicit confirmation per claudio policy"}'
        exit 0
      fi
    fi
  fi

  # Attempt RTK rewrite for allowed commands
  if command -v rtk >/dev/null 2>&1; then
    REWRITTEN=$(rtk rewrite "$CMD" 2>/dev/null || true)
    if [[ -n "$REWRITTEN" && "$REWRITTEN" != "$CMD" ]]; then
      jq -n --arg cmd "$REWRITTEN" '{"decision":"allow","overwrite":{"CommandLine":$cmd}}'
      exit 0
    fi
  fi
fi

echo '{"decision":"allow"}'
