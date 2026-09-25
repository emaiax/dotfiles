{
  claudioPath,
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;
  perms = import ../permissions.nix { inherit home lib; };

  policyJson = (pkgs.formats.json { }).generate "claudio-policy.json" perms.policy;

  hooksConfig = {
    claudio-safety-and-rtk = {
      PreToolUse = [
        {
          matcher = "run_command";
          hooks = [
            {
              type = "command";
              command = ''bash "${claudioPath}/hooks/antigravity-hook.sh" "${policyJson}"'';
            }
          ];
        }
        {
          matcher = "view_file|read_file|write_to_file|replace_file_content";
          hooks = [
            {
              type = "command";
              command = ''bash "${claudioPath}/hooks/antigravity-hook.sh" "${policyJson}"'';
            }
          ];
        }
      ];
    };
  };

  hooksJson = (pkgs.formats.json { }).generate "antigravity-hooks.json" hooksConfig;
in
{
  programs.antigravity-cli.permissions.allow = perms.antigravity.permissions.allow;

  home.file.".gemini/config/AGENTS.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/AGENTS.md";
    force = true;
  };

  home.file.".gemini/config/docs" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/docs";
    force = true;
  };

  home.file.".gemini/config/skills" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/skills";
    force = true;
  };

  home.file.".gemini/config/hooks.json" = {
    source = hooksJson;
    force = true;
  };

  # Keep claudio's local antigravity/settings.json copy in sync with antigravity-cli/settings.json
  home.activation.claudioAntigravitySettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    existing="${claudioPath}/antigravity/settings.json"
    tracked="${config.home.homeDirectory}/code/dotfiles/modules/user/apps/antigravity-cli/settings.json"
    if [[ -d "$(dirname "$existing")" && -f "$tracked" ]] && ! cmp -s "$tracked" "$existing" 2>/dev/null; then
      install -Dm644 "$tracked" "$existing"
    fi
  '';
}
