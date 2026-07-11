#!/usr/bin/env bash
# Flags prose paragraphs split across multiple raw lines. See AGENTS.md:
# "Never hard-wrap prose you generate ... Soft-wrap everything." Headers,
# list items, table rows, blockquotes, and code blocks are structural and
# may keep their own line breaks.
#
# Usage: check-hardwrap.sh <file>
set -euo pipefail

file="$1"
violations=0
block=()
has_fence=0
in_fence=0

is_structural_line() {
	local line="$1"
	[[ "$line" =~ ^#+[[:space:]] ]] && return 0
	[[ "$line" =~ ^[-*][[:space:]] ]] && return 0
	[[ "$line" =~ ^[0-9]+\.[[:space:]] ]] && return 0
	[[ "$line" =~ ^\| ]] && return 0
	[[ "$line" =~ ^\> ]] && return 0
	return 1
}

flush_block() {
	if [[ ${#block[@]} -gt 1 && "$has_fence" -eq 0 ]]; then
		local structural=1
		for line in "${block[@]}"; do
			is_structural_line "$line" || { structural=0; break; }
		done
		if [[ "$structural" -eq 0 ]]; then
			violations=$((violations + 1))
			printf 'hard-wrapped prose paragraph:\n' >&2
			printf '  %s\n' "${block[@]}" >&2
		fi
	fi
	block=()
	has_fence=0
}

while IFS= read -r line || [[ -n "$line" ]]; do
	if [[ "$line" =~ ^'```' ]]; then
		in_fence=$((1 - in_fence))
		has_fence=1
		block+=("$line")
		continue
	fi
	if [[ "$in_fence" -eq 1 ]]; then
		block+=("$line")
		continue
	fi
	if [[ -z "$line" ]]; then
		flush_block
	else
		block+=("$line")
	fi
done < "$file"
flush_block

exit "$((violations > 0 ? 1 : 0))"
