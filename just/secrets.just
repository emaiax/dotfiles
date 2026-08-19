sops_file := "secrets/secrets.enc.yaml"

# Rename a key in the encrypted secrets file, keeping its value.
secrets-rename old new:
    #!/usr/bin/env bash
    set -euo pipefail
    val="$(sops decrypt --extract '["{{ old }}"]' {{ sops_file }})"
    sops --set "[\"{{ new }}\"] $(printf '%s' "$val" | jq -R .)" {{ sops_file }}
    sops unset {{ sops_file }} '["{{ old }}"]'
    echo "renamed {{ old }} -> {{ new }}"
