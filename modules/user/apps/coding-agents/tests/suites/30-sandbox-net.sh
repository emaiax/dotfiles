#!/usr/bin/env bash
# Network enforcement probes: egress allowlist, nix daemon socket, TLS through Security.framework.
#
# net-nix-socket doubles as claudio's settings-merge canary — if --settings replaced the whole network object instead of merging, the base's nix socket grant would vanish exactly there.
#
# net-tls-sandboxed wraps gh in case.sh deliberately, since excludedCommands only matches top-level commands — a wrapped gh runs fully sandboxed, exercising the trustd fix on its own.

set -euo pipefail

net_cases() {
  cat <<'EOF'
net-allowed-domain
net-api-github
net-denied-domain
net-nix-socket
net-tls-sandboxed
EOF
}

net_run_case() {
  local case_id=$1 profile=$2
  case $case_id in
    net-allowed-domain)
      probe_script "$profile" "$case_id" 'curl -sSI --max-time 25 https://github.com >/dev/null'
      ;;
    net-api-github)
      probe_script "$profile" "$case_id" 'curl -sSI --max-time 25 https://api.github.com >/dev/null'
      ;;
    net-denied-domain)
      probe_script "$profile" "$case_id" 'curl -sSI --max-time 25 https://example.com >/dev/null'
      ;;
    net-nix-socket)
      probe_script "$profile" "$case_id" 'nix store ping'
      ;;
    net-tls-sandboxed)
      probe_script "$profile" "$case_id" 'gh api /rate_limit >/dev/null'
      ;;
    *)
      echo "30-sandbox-net: unknown case $case_id" >&2
      return 1
      ;;
  esac
}
