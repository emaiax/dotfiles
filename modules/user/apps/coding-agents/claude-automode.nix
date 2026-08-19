# Auto mode classifier config (see #121 for the full reasoning).
#
# Prose judged by a model, not enforcement: wording changes the outcome, and it only applies while the session is in auto mode. Anything that must hold regardless goes in `permissions.deny`.
#
# A profile's `autoMode.allow` can override a `soft_deny` from here, which is the only way a profile can loosen anything inherited.
{
  programs.claude-code.settings.autoMode = {
    # No hostnames, org names or topology: this repo mirrors publicly, and the built-in defaults already trust the working repo's own remotes. Repo-specific context goes in that repo's CLAUDE.md, which the classifier also reads.
    environment = [
      "$defaults"

      "Organization: personal single-developer setup, no company. Primary use of Claude Code: software development plus Nix-based infrastructure automation."

      "Internal package registry: none. Nix is the package manager, so its configured substituters are the expected download sources and flake inputs are fetched from their upstream forges."

      "Repository visibility: assume a repository is public unless something in the session shows otherwise, since several are mirrored publicly. Treat anything committed as published."

      "Additional context: this machine is a personal workstation, not a shared or production host."
    ];

    # Counterpart of gates.nix's denySoft. Phrase as a category, never as an absolute: "under any circumstances" makes it unoverridable and claudio-thebot needs to override this one. Do not mention that stating intent clears it, which reads as permission to ignore the rule.
    soft_deny = [
      "$defaults"

      "Anything that appears publicly under the operator's name on a code forge, including opening or closing pull requests, submitting reviews, creating or editing issues, and commenting on any of them, is theirs to initiate rather than the agent's. Do not do these unprompted."
    ];
  };
}
