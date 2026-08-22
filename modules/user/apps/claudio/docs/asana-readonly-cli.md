# Asana read-only CLI: investigation and design

## Problem

Query the Asana API for reads only (tasks, projects, workspaces, etc) from within Claude Code
sessions in this dotfiles-managed environment. The hard requirement is privacy: Asana should learn
as little as possible about the requester, and specifically should not be able to tell an AI agent
is making the calls.

## Investigation: options considered

- **Official REST API, PAT auth.** Simplest, but the token inherits every permission on the
  account. Read-only is a convention, not a guarantee: nothing stops a write call from reusing the
  same token.
- **Official REST API, OAuth2.** Asana supports granular scopes (`tasks:read`, `projects:read`,
  etc), so a token can be read-only for real. Costs an app registration, an authorization flow, and
  refresh-token handling.
- **Official MCP server** (`mcp.asana.com/v2/mcp`, OAuth2, Streamable HTTP). Asana's own docs say
  any authorization can reach every tool, read or write; there is no way to scope the server itself
  to read-only. It is also Asana's own hosted AI-usage product, so it sees more about the fact an
  agent is involved than a plain API call would. Ruled out on both counts.
- **Third-party MCP server** (`roychri/mcp-server-asana`). Has a real `READ_ONLY_MODE=true` gate,
  the only option researched with a technical (not just conventional) read-only enforcement. Still
  an opaque third-party code layer between us and the Asana API, with its own request shaping and
  potential telemetry we don't control.
- **Official SDKs** (`asana` on npm / PyPI). Full read-write access; read-only would again be by
  discipline only, not enforced. Useful only as a base to hand-roll something narrower.
- **Other paths.** No public Asana GraphQL API exists. No official Asana CLI exists. Zapier/Make/n8n
  don't fit a local, on-demand agent query.

**Decision:** skip MCP entirely, official or third-party. Ship a small hand-rolled script that talks
to the plain REST API, authenticated with a Personal Access Token, with read-only enforced by
construction rather than by flag or convention.

## Secondary investigation: where should the script live?

`modules/pkgs/` is the directory CLAUDE.md's Layout section calls out for "custom packages not in
nixpkgs," so that's where a new CLI script should go by that description. Checking it turned up a
separate, pre-existing issue: `modules/pkgs/default.nix`'s `custom-bins` derivation, which bundles
everything under `modules/pkgs/bin/` (`event-logger.swift`, `macos-send-event.swift`,
`macos-settings-diff.sh`, `set-accent-color.swift`) into one `$out/bin`, is never referenced from
`home.packages`, `environment.systemPackages`, or any overlay anywhere in the repo. It builds
cleanly but nothing installs it — those four scripts are effectively dead code today.

The pattern that does work elsewhere in the repo is a single-purpose derivation kept beside its one
consumer and wired directly into that consumer's `home.packages`/`environment.systemPackages`:
`send-ui-events.nix` lives in `system/darwin/appearance/` next to its only caller, and `rtk.nix`
lives in `claude-code/` next to its only caller. Neither goes through a shared bundle.

Filed as a separate finding: see the linked issue on the pull request that carries this doc.

## Chosen path

Fix the `custom-bins` wiring rather than route around it: add `asana-ro` to `modules/pkgs/bin/`, and
wire the existing `custom-bins` derivation into `home.packages` in
`modules/user/packages/default.nix`, which the repo's Layout docs already designate for general CLI
tools. This activates the other four scripts in `modules/pkgs/bin/` as a side effect; see Risks.

## Design

### `asana-ro` script (`modules/pkgs/bin/asana-ro`)

- Bash, no new dependencies: `curl` and `jq` are already in `home.packages`
  (`modules/user/packages/default.nix`), `security` is a macOS builtin.
- Read-only is enforced by construction: a single internal `get()` helper is the only place that
  calls the network, and it is hard-coded to `curl -X GET`. No code path in the script can issue
  POST/PUT/DELETE, so there's no flag to leave off or convention to violate.
- Auth: a Personal Access Token read from the macOS Keychain via
  `security find-generic-password -a "$USER" -s asana-ro-pat -w`. Setup is documented in the
  script's own `--help` text (`security add-generic-password -a "$USER" -s asana-ro-pat -w <PAT>`);
  the script itself never writes to the Keychain or anywhere else, so its only side effect is the
  Asana HTTP GET.
- Subcommands: `me`, `workspaces`, `projects --workspace <gid>`, `tasks --project <gid>`,
  `task <gid>`, and a `raw <path> [query=val ...]` escape hatch for any other Asana v1.0 GET
  endpoint (tags, custom fields, portfolios, goals, ...) without editing the script per new query
  shape. `raw` still routes through `get()`, so it stays GET-only.
- Every call sets an explicit `opt_fields` to keep response payloads, and the implicit "how much did
  you just ask for" signal, minimal.

### Wiring fix (`modules/pkgs`)

- `modules/pkgs/default.nix` itself is unchanged; it already copies `bin/*` into `$out/bin`.
- Add the derivation to `modules/user/packages/default.nix`'s `home.packages`.
- No filesystem/network sandbox changes are needed for the Keychain read: `~/Library/Keychains` is
  already in `toolchainReads` (readable) and in the sandbox's write allowlist.

### `permissions.nix`

- Add `"app.asana.com"` to `allowedDomains`, with a comment tying it to the read-only CLI and
  recording why no MCP/OAuth path was chosen, so a future reader isn't tempted to wire the official
  MCP server in here instead.

### Explicitly out of scope

- Any MCP server for Asana, official or third-party.
- Registering an OAuth app with Asana.
- Smoke-testing or fixing the other four `modules/pkgs/bin/` scripts beyond confirming the build
  still succeeds once wired in.
- Provisioning the user's actual PAT in the Keychain (manual, one-time, documented in `--help`).

## Risks

- Activating `custom-bins` installs `event-logger.swift`, `macos-send-event.swift`,
  `macos-settings-diff.sh`, and `set-accent-color.swift` for the first time as a side effect of
  fixing the wiring bug. They carry working shebangs (`#!/usr/bin/env swift`, `#!/usr/bin/env bash`)
  so they run as copied without a compile step, but they've never been exercised via this path and
  may carry their own bitrot that only shows up in real use.

## Testing plan (for the follow-up implementation PR)

- `nix fmt`
- `just build` (or `darwin-rebuild build --flake .#dudupro`)
- `modules/user/apps/claudio/profiles/tests/run.sh`, since `permissions.nix`'s `allowedDomains`
  changes
- Manual, user-run: after `just switch`,
  `security add-generic-password -a "$USER" -s asana-ro-pat -w <PAT>` once, then `asana-ro me` with
  a real token

## Open questions

- OK with the other `modules/pkgs/bin/` scripts going live as a side effect of this fix, or should
  the wiring be scoped to install `asana-ro` alone and leave the rest dormant for now?
- Keep `raw` as a general GET escape hatch, or trim the surface to only the named subcommands?
