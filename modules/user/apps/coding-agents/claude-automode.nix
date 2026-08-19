# Auto mode classifier configuration (see issue #121).
#
# `permissions` and `autoMode` are two different gates and it matters which one
# a rule belongs in:
#
#   permissions.allow/ask/deny  — command patterns, evaluated BEFORE the
#                                 classifier. Rigid: a higher-precedence layer
#                                 cannot loosen a lower one, so anything here
#                                 binds every profile equally.
#   autoMode.*                  — prose, read BY the classifier. A profile's
#                                 `allow` can override a `soft_deny` from this
#                                 layer, which is the only per-profile
#                                 loosening mechanism available.
#
# Being prose judged by a model, these are steering rather than enforcement:
# wording changes the outcome. A rule phrased "under any circumstances" was
# honoured as absolute and could not be overridden by an allow exception, while
# the same rule phrased as a category with a narrow exception could. Anything
# that must hold regardless belongs in `permissions.deny`, not here.
#
# Note the classifier deliberately does NOT read autoMode from a repo's
# .claude/settings.json, so a checked-in repo cannot widen its own trust.
{
  programs.claude-code.settings.autoMode = {
    # Without this the classifier trusts only the working directory and the
    # current repo's remotes — everything else reads as a potential exfiltration
    # target. The Forgejo instance is the sharp edge here: it is LAN-only, so
    # a push there looks like an unknown external host rather than the primary
    # remote it actually is.
    environment = [
      "$defaults"

      "Organization: personal single-operator setup, no company. Primary use of Claude Code: software development plus NixOS and nix-darwin infrastructure automation for a home lab."

      "Source control: self-hosted Forgejo at forgejo.emx.casa, LAN-only and not reachable from the public internet, hosting the emaiax/* repositories — this is the primary remote, not an external destination. Also GitHub, for emaiax/*, claudio-thebot/* and boagrana/*."

      "Trusted internal domains: *.emx.casa — the home lab's own network, including the Forgejo instance and the services it runs."

      "Key internal services: forgejo.emx.casa hosts both the git remotes and the CI runners. The dotfiles repository push-mirrors from there to github.com/emaiax/dotfiles so that GitHub's hosted macOS runners can build the aarch64-darwin closure, which the LAN-only instance cannot do itself. Traffic in that direction is expected and routine."

      "Internal package registry: none. Nix is the package manager; substituters such as cache.nixos.org and nix-community.cachix.org are the expected download sources, and flake inputs are fetched from GitHub."

      "Repository visibility: this dotfiles repository is public — it push-mirrors to github.com/emaiax/dotfiles, which is a public repository, so anything committed here is published. Treat it as public regardless of which remote the push targets. Contributions to nixpkgs and home-manager are public too. Visibility of the other Forgejo-hosted repositories is not stated here; assume private unless their remote says otherwise."

      "Additional context: this machine is a personal workstation, not a shared or production host. Home lab servers run NixOS and are reached over Tailscale or the LAN."
    ];
  };
}
