# Files and directories that must stay out of Claude's reach no matter which tool asks for them.
#
# Single source for both halves of the policy (see #126): claude-sandbox.nix denies these to the
# sandboxed Bash subprocess via sandbox.filesystem.denyRead/denyWrite, and claude-code.nix denies
# them to the native Read/Edit tools via permissions.deny, which the sandbox never sees.
home: {
  # Directories: Read/Edit deny rules need a /** suffix to reach files nested inside.
  dirs = [
    "${home}/.aws"
    "${home}/.config/1Password"
    "${home}/.config/sops"
    "${home}/.gnupg"
  ];

  # Single files.
  files = [
    "${home}/.claude/.credentials.json"

    # Deny the credential file, never the config directory around it: denying ~/.config/gh stopped
    # gh starting at all, and ~/.config/opencode holds only config while opencode keeps its tokens
    # under ~/.local/share.
    "${home}/.local/share/opencode/auth.json"
    "${home}/.local/share/opencode/mcp-auth.json"
    "${home}/.docker/config.json"
    "${home}/.netrc"
    "${home}/.npmrc"
  ];
}
