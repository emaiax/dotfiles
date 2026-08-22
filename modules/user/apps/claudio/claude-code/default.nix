# Claude Code: settings generation, the Seatbelt sandbox (see #121, #126), and the auto-mode classifier config,
# all in one file since nothing else contributes to programs.claude-code.settings. Background/investigation
# notes on the sandbox specifically: ../docs/sandbox-notes.md.
{
  claudioPath,
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;

  # Shared with opencode/default.nix. ask/deny and the sandbox's filesystem/network both come back fully
  # rendered to Claude's native shape, this file only wires perms.claudeCode in.
  perms = import ../permissions.nix { inherit home lib; };

  # Point at the live checkout, not $HOME/.claude, so the hooks don't depend on the symlinks below landing
  # correctly. `bash "path"`, not direct exec: the scripts are tracked 100644 and a non-executable hook fails
  # silently.
  rtkHook = {
    matcher = "Bash";
    hooks = [
      {
        type = "command";
        command = ''bash "${claudioPath}/hooks/rtk-hook.sh"'';
        statusMessage = "Applying RTK token-reduction filter";
      }
    ];
  };

  claudeSettingsJson = (pkgs.formats.json { }).generate "claude-code-settings.json" (
    config.programs.claude-code.settings
  );
in
{
  home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -e "${claudioPath}/claude-code/settings.json" ]]; then
      install -Dm644 ${claudeSettingsJson} "${claudioPath}/claude-code/settings.json"
    fi
  '';

  home.file."${config.programs.claude-code.configDir}/settings.json" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/claude-code/settings.json";
    force = true;
  };

  home.file."${config.programs.claude-code.configDir}/CLAUDE.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/AGENTS.md";
    force = true;
  };

  home.file."${config.programs.claude-code.configDir}/hooks" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/hooks";
    force = true;
  };

  home.file."${config.programs.claude-code.configDir}/skills" = {
    source = config.lib.file.mkOutOfStoreSymlink "${claudioPath}/skills";
    force = true;
  };

  programs.claude-code = {
    enable = true;

    settings = {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";

      model = "sonnet";

      includeCoAuthoredBy = false;
      theme = "dark";

      hooks.PreToolUse = [ rtkHook ];

      extraKnownMarketplaces = {
        obsidian-skills = {
          source = {
            source = "github";
            repo = "kepano/obsidian-skills";
          };
        };
        thedotmack = {
          source = {
            source = "github";
            repo = "thedotmack/claude-mem";
          };
        };
      };

      enabledPlugins = {
        "claude-mem@thedotmack" = true; # semantic memory across sessions
        "obsidian@obsidian-skills" = true; # obsidian markdown, bases, JSON Canvas and `obsidian` CLI
        "superpowers@claude-plugins-official" = true; # superpowers: code analysis, refactoring, and generation
      };

      # ask/deny hold in every mode, unlike allow and autoMode.
      permissions = perms.claudeCode.permissions // {
        defaultMode = "auto";
      };

      # Two ways to write a sandbox rule that silently does nothing: a trailing slash voids the entry on 2.1.222
      # (fixed in 2.1.224), and a glob like `$HOME/*` matches nothing and fails open.
      sandbox = {
        enabled = true;

        # Without both, the boundary is advisory: Claude may retry a blocked command unsandboxed, or continue if
        # Seatbelt is unavailable.
        allowUnsandboxedCommands = false;
        failIfUnavailable = true;

        autoAllowBashIfSandboxed = true;

        # docker/gh/fj policy: permissions.nix's claudeCode.sandbox.excludedCommands.
        inherit (perms.claudeCode.sandbox) excludedCommands;

        # Without this, `open -a <App>` fails with kLSUnknownErr: launching another app's process needs a
        # mach-lookup to RunningBoard/launchservicesd that the sandbox blocks.
        allowAppleEvents = true;

        network = perms.claudeCode.sandbox.network;
        filesystem = perms.claudeCode.sandbox.filesystem;
      };

      # Prose judged by a model, not enforcement: wording changes the outcome, and it only applies while the
      # session is in auto mode. Anything that must hold regardless goes in `permissions` above instead. A
      # profile's `autoMode.allow` can override a `soft_deny` from here, which is the only way a profile can
      # loosen anything inherited.
      autoMode = {
        # No hostnames, org names or topology: this repo mirrors publicly, and the built-in defaults already
        # trust the working repo's own remotes. Repo-specific context goes in that repo's CLAUDE.md, which the
        # classifier also reads.
        environment = [
          "$defaults"

          "Organization: personal single-developer setup, no company. Primary use of Claude Code: software development plus Nix-based infrastructure automation."

          "Internal package registry: none. Nix is the package manager, so its configured substituters are the expected download sources and flake inputs are fetched from their upstream forges."

          "Repository visibility: assume a repository is public unless something in the session shows otherwise, since several are mirrored publicly. Treat anything committed as published."

          "Additional context: this machine is a personal workstation, not a shared or production host."
        ];

        # Counterpart of permissions.nix's denySoft. Phrase as a category, never as an absolute: "under any
        # circumstances" makes it unoverridable and claudio-thebot needs to override this one. Do not mention
        # that stating intent clears it, which reads as permission to ignore the rule.
        soft_deny = [
          "$defaults"

          "Anything that appears publicly under the operator's name on a code forge, including opening or closing pull requests, submitting reviews, creating or editing issues, and commenting on any of them, is theirs to initiate rather than the agent's. Do not do these unprompted."
        ];
      };
    };
  };
}
