# Writes nix-darwin, Nix store, Homebrew and macOS update metrics for Alloy's textfile collector.
# Expects TEXTFILE_DIR and NIXPKGS_LAST_MODIFIED in the environment.

mkdir -p "$TEXTFILE_DIR"
out="$TEXTFILE_DIR/mac.prom"
tmp="$(mktemp "$TEXTFILE_DIR/.mac.prom.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

# Label values come from command output, so strip what would break the exposition format.
clean() { tr -d "\"\\\\" | tr '\n' ' ' | sed 's/ *$//'; }

{
  rev_json="$(darwin-version --json)"
  config_rev="$(jq -r '.configurationRevision // "unknown"' <<<"$rev_json")"
  darwin_rev="$(jq -r '.darwinRevision // "unknown"' <<<"$rev_json")"
  nixpkgs_rev="$(jq -r '.nixpkgsRevision // "unknown"' <<<"$rev_json")"
  nix_ver="$(nix --version | awk '{print $NF}')"
  macos_ver="$(sw_vers -productVersion)"

  echo "# HELP darwin_system_info nix-darwin revisions of the running system"
  echo "# TYPE darwin_system_info gauge"
  echo "darwin_system_info{configuration_revision=\"$config_rev\",darwin_revision=\"$darwin_rev\",nixpkgs_revision=\"$nixpkgs_rev\",nix_version=\"$nix_ver\",macos_version=\"$macos_ver\"} 1"

  echo "# HELP darwin_configuration_dirty 1 when the running system was built from a dotfiles tree with uncommitted changes"
  echo "# TYPE darwin_configuration_dirty gauge"
  if [[ "$config_rev" == *-dirty ]]; then echo "darwin_configuration_dirty 1"; else echo "darwin_configuration_dirty 0"; fi

  profiles=/nix/var/nix/profiles
  gen="$(readlink "$profiles/system" | sed -n 's/^system-\([0-9]*\)-link$/\1/p')"
  echo "# HELP darwin_current_generation Generation number of the active nix-darwin system profile"
  echo "# TYPE darwin_current_generation gauge"
  echo "darwin_current_generation ${gen:-0}"

  echo "# HELP darwin_generations nix-darwin system generations retained"
  echo "# TYPE darwin_generations gauge"
  echo "darwin_generations $(find "$profiles" -maxdepth 1 -name 'system-*-link' | wc -l | tr -d ' ')"

  echo "# HELP darwin_generation_timestamp_seconds When the active generation was switched to"
  echo "# TYPE darwin_generation_timestamp_seconds gauge"
  echo "darwin_generation_timestamp_seconds $(stat -f %m "$profiles/system-${gen}-link")"

  echo "# HELP darwin_closure_size_bytes Closure size of the running system"
  echo "# TYPE darwin_closure_size_bytes gauge"
  echo "darwin_closure_size_bytes $(nix path-info -S /run/current-system | awk '{print $2}')"

  echo "# HELP darwin_nixpkgs_last_modified_seconds Commit time of the nixpkgs the running system was built from"
  echo "# TYPE darwin_nixpkgs_last_modified_seconds gauge"
  echo "darwin_nixpkgs_last_modified_seconds $NIXPKGS_LAST_MODIFIED"

  echo "# HELP nix_store_paths Entries in /nix/store"
  echo "# TYPE nix_store_paths gauge"
  echo "nix_store_paths $(find /nix/store -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"

  # node-exporter cannot give this: statfs reports the shared APFS container, the same numbers for every volume.
  echo "# HELP nix_store_volume_used_bytes Space used by the /nix APFS volume"
  echo "# TYPE nix_store_volume_used_bytes gauge"
  echo "nix_store_volume_used_bytes $(diskutil info -plist /nix | plutil -extract CapacityInUse raw -)"

  echo "# HELP nix_store_dead_paths Store paths a garbage collection would delete"
  echo "# TYPE nix_store_dead_paths gauge"
  echo "nix_store_dead_paths $(nix-store --gc --print-dead 2>/dev/null | wc -l | tr -d ' ')"

  # brew outdated reads the local tap state, so refresh it first or the count only grows after a manual update.
  brew update --quiet >/dev/null 2>&1 || true
  outdated="$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --json=v2)"

  echo "# HELP brew_installed Installed Homebrew packages by kind"
  echo "# TYPE brew_installed gauge"
  echo "brew_installed{kind=\"formula\"} $(brew list --formula | wc -l | tr -d ' ')"
  echo "brew_installed{kind=\"cask\"} $(brew list --cask | wc -l | tr -d ' ')"

  echo "# HELP brew_outdated Homebrew packages with a newer version available"
  echo "# TYPE brew_outdated gauge"
  echo "brew_outdated{kind=\"formula\"} $(jq '.formulae | length' <<<"$outdated")"
  echo "brew_outdated{kind=\"cask\"} $(jq '.casks | length' <<<"$outdated")"

  echo "# HELP brew_outdated_info One series per outdated Homebrew package"
  echo "# TYPE brew_outdated_info gauge"
  jq -r '
    (.formulae[] | {kind: "formula", name, installed: .installed_versions[-1], current: .current_version}),
    (.casks[] | {kind: "cask", name, installed: .installed_versions[-1], current: .current_version})
    | "brew_outdated_info{kind=\"\(.kind)\",name=\"\(.name)\",installed=\"\(.installed)\",current=\"\(.current)\"} 1"
  ' <<<"$outdated"

  # softwareupdate prints "* Label: X" followed by a tab-indented "Title: ..., Action: restart," line per update.
  updates="$(softwareupdate --list 2>/dev/null || true)"

  echo "# HELP macos_updates_pending macOS software updates available"
  echo "# TYPE macos_updates_pending gauge"
  echo "macos_updates_pending $(grep -c '^\* Label:' <<<"$updates" || true)"

  echo "# HELP macos_update_info One series per available macOS software update"
  echo "# TYPE macos_update_info gauge"
  while IFS= read -r line; do
    case "$line" in
      "* Label: "*)
        label="$(clean <<<"${line#\* Label: }")"
        ;;
      *"Title: "*)
        title="$(sed -n 's/.*Title: \([^,]*\),.*/\1/p' <<<"$line" | clean)"
        restart=0
        [[ "$line" == *"Action: restart"* ]] && restart=1
        echo "macos_update_info{label=\"$label\",title=\"$title\",restart=\"$restart\"} 1"
        ;;
    esac
  done <<<"$updates"
} >"$tmp"

chmod 644 "$tmp"
mv "$tmp" "$out"
