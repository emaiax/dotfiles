{
  claudioPath,
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;
  claudioCfg = config.programs.claudio;

  # Shared with claude-code/default.nix. permission (including bash's dag-entry rendering) comes back fully
  # assembled, this file only wires it in.
  perms = import ../permissions.nix {
    inherit home lib;
    inherit (claudioCfg) permissions;
  };

  opencodeSettingsJson = (pkgs.formats.json { }).generate "opencode-settings.json" (
    config.programs.opencode.settings
  );

  # Secrets reach opencode as env vars set only on its own process, so they never land in settings.json or the shell.
  # opencode.json reads them back with {env:VAR}. https://opencode.ai/docs/config/#env-vars
  secretEnv = {
    ASANA_CLIENT_ID = config.sops.secrets.asana-client-id.path;
    ASANA_CLIENT_SECRET = config.sops.secrets.asana-client-secret.path;
  };

  opencodeWithSecrets = pkgs.symlinkJoin {
    inherit (pkgs.opencode) meta;
    name = "${lib.getName pkgs.opencode}-with-secrets-${lib.getVersion pkgs.opencode}";
    paths = [ pkgs.opencode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # sops-nix decrypts async at login, so a missing file leaves the var unset instead of failing the launch.
    postBuild = ''
      wrapProgram $out/bin/opencode ${
        lib.concatMapAttrsStringSep " " (
          name: path: "--run ${lib.escapeShellArg ''[[ -r "${path}" ]] && export ${name}="$(<"${path}")"''}"
        ) secretEnv
      }
    '';
  };
in
{
  sops.secrets = {
    asana-client-id = { };
    asana-client-secret = { };
  };

  # Same rule as claude-code/default.nix: nix always wins, a differing existing file is backed up to .bak first.
  home.activation.opencodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    existing="${claudioPath}/opencode/settings.json"

    if [[ -e "$existing" ]] && ! diff -q ${opencodeSettingsJson} "$existing" >/dev/null; then
      cp "$existing" "$existing.bak"
      echo "[opencode] settings.json changed, backed up previous content to $existing.bak" >&2
    fi

    install -Dm644 ${opencodeSettingsJson} "$existing"
  '';

  home.file."${config.xdg.configHome}/opencode/opencode.json" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/opencode/settings.json";
    force = true;
  };

  home.file."${config.xdg.configHome}/opencode/AGENTS.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/AGENTS.md";
    force = true;
  };

  home.file."${config.xdg.configHome}/opencode/docs" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/docs";
    force = true;
  };

  home.file."${config.xdg.configHome}/opencode/skills" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/skills";
    force = true;
  };

  programs.opencode = {
    enable = true;
    package = opencodeWithSecrets;

    # A separate option, not a settings.json key: the upstream module writes this to its own tui.json instead.
    tui.theme = "system"; # respect the system appearance setting on macOS.

    settings = {
      model = "anthropic/claude-sonnet-5";
      small_model = "anthropic/claude-haiku-4-5-20251001"; # cheap/routine tasks (title generation, etc.), skip the primary model

      autoupdate = "notify"; # managed by Nix, so this never auto-updates, it only checks and prints a notice instead
      share = "disabled"; # disable remote sharing by default
      shell = "zsh"; # match the shell configured in this repo
      snapshot = true; # per-turn undo of file edits (opencode default; explicit for clarity).
      compaction.auto = true;

      mcp.asana = {
        type = "remote";
        url = "https://mcp.asana.com/v2/mcp";
        enabled = true;
        oauth = {
          clientId = "{env:ASANA_CLIENT_ID}";
          clientSecret = "{env:ASANA_CLIENT_SECRET}";
          redirectUri = "http://127.0.0.1:19876/mcp/oauth/callback";
        };
      };

      # Plugins loaded at startup. superpowers: brainstorming, planning, and execution workflow skills.
      # supermemory: persistent cross-session memory (requires `bunx opencode-supermemory@latest login`).
      plugin = [
        "superpowers@git+https://github.com/obra/superpowers.git"
        "opencode-supermemory"
      ];

      permission = perms.opencode.permission;
    };
  };
}
