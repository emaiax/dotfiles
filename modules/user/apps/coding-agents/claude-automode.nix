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
#
# Everything here applies to every session — this is the user layer — but ONLY
# while that session is in auto mode. Outside it the classifier is never
# consulted and the whole block stops applying: verified by running the same
# command under both modes, blocked in `auto` and straight through under
# `bypassPermissions`. `permissions.deny` has no such condition, which is the
# other reason merge and release live there rather than here.
{
  programs.claude-code.settings.autoMode = {
    # Without this the classifier trusts only the working directory and the
    # current repo's remotes — everything else reads as a potential exfiltration
    # target. The Forgejo instance is the sharp edge here: it is LAN-only, so
    # a push there looks like an unknown external host rather than the primary
    # remote it actually is.
    # Kept deliberately free of hostnames, org names and network topology. This
    # repository mirrors to a public one, and an environment block is a
    # standing inventory of infrastructure — exactly the thing not to accumulate
    # somewhere world-readable. Anything identifying belongs in the encrypted
    # secret, the way agent-jail already handles its paths.
    #
    # Little is lost by omitting it. The built-in defaults already trust "the
    # repository the agent started in and its configured remotes", so the
    # common case needs no naming at all, and the classifier reads each
    # project's CLAUDE.md — which is where repo-specific context (this one's
    # push-mirror and CI topology, for instance) already lives and belongs.
    environment = [
      "$defaults"

      "Organization: personal single-developer setup, no company. Primary use of Claude Code: software development plus Nix-based infrastructure automation."

      "Internal package registry: none. Nix is the package manager, so its configured substituters are the expected download sources and flake inputs are fetched from their upstream forges."

      "Repository visibility: assume a repository is public unless something in the session shows otherwise — several of these are mirrored publicly, so treat anything committed as published."

      "Additional context: this machine is a personal workstation, not a shared or production host."
    ];

    # The counterpart of gates.nix's `denySoft`. Two things about the wording:
    #
    # Phrase it as a category, not an absolute. A rule saying "under any
    # circumstances" was honoured as absolute and no allow entry could clear
    # it — and claudio-thebot exists precisely to clear this one.
    #
    # Do not describe the escape hatch inside the rule. An earlier version
    # ended by explaining that asking directly was enough to clear it, which is
    # an instruction to the classifier to be permissive. That behaviour is
    # already part of what a soft deny means; spelling it out only argues
    # against the rule.
    #
    # Merging and releasing are deliberately absent — those stay in
    # permissions.deny, where nothing overrides them.
    soft_deny = [
      "$defaults"

      "Anything that appears publicly under the operator's name on a code forge — opening or closing pull requests, submitting reviews, creating or editing issues, and commenting on any of them — is theirs to initiate, not the agent's. Do not do these unprompted."
    ];
  };
}
