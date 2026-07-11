#!/usr/bin/env bash
# TDD fixtures for check-hardwrap.sh, per issue #83: a prose paragraph must be
# one raw line, while structural markdown (headers, lists, tables, code
# blocks, blockquotes) may keep its own line breaks.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checker="$dir/check-hardwrap.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0

# Case 1: a prose paragraph hard-wrapped at ~80 cols (the PR-body scenario
# described in the issue) must be flagged as a violation.
cat > "$tmp/hardwrapped.md" <<'EOF'
## Problem

Writing a PR description, paragraphs got wrapped at the traditional 80-col
commit-body width. Headers, bullet list items, and table rows were correctly
left alone, but the paragraphs above them got the same column-wrap treatment
prose should never get.

- one
- two
EOF

if "$checker" "$tmp/hardwrapped.md" >/dev/null 2>&1; then
	echo "FAIL: expected hardwrapped.md to be flagged as a violation"
	fail=1
else
	echo "PASS: hardwrapped.md correctly flagged"
fi

# Case 2: the same prose as a single raw line, with structural elements
# (header, list) kept multi-line, must pass untouched.
cat > "$tmp/softwrapped.md" <<'EOF'
## Problem

Writing a PR description, paragraphs got wrapped at the traditional 80-col commit-body width. Headers, bullet list items, and table rows were correctly left alone, but the paragraphs above them got the same column-wrap treatment prose should never get.

- one
- two
EOF

if "$checker" "$tmp/softwrapped.md" >/dev/null 2>&1; then
	echo "PASS: softwrapped.md correctly accepted"
else
	echo "FAIL: expected softwrapped.md to pass"
	fail=1
fi

exit "$fail"
