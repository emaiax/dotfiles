{
  config,
  lib,
  pkgs,
  ...
}:

let
  agentCatalog = import ./agents.nix;
  profiles = config.programs.agent-jail.profiles;
  profileNames = builtins.attrNames profiles;

  image = "docker.io/library/node:22";
  secretsPath = config.sops.secrets."agent-jail-profiles".path;

  # cached across runs so only the first `docker run` per host pays for the download
  nvimCacheVolume = "agent-jail-apt-cache";
  # the `vi` symlink is what actually fixes agents that shell out to a literal `vi`
  #
  # the node:22 image has no apt-utils, so the very first `apt-get install` in
  # any container always logs "debconf: delaying package configuration, since
  # apt-utils is not installed" — harmless (verified: real apt errors still
  # surface through the filter), but noisy on every launch, so it's dropped.
  nvimSetupCmd = "{ apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get -qq install -y --no-install-recommends neovim >/dev/null; } 2> >(grep -v \"^debconf: delaying package configuration\" >&2) && ln -sf \"$(command -v nvim)\" /usr/local/bin/vi";

  mkAgentMount = { host, container }: ''--volume "${host}:${container}"'';
  mkAgentMountArgs =
    agent: lib.concatStringsSep " \\\n              " (map mkAgentMount agent.mounts);
  mkAgentCmd = agent: lib.concatStringsSep " " agent.cmd;

  mkCwdRwArg =
    profileName:
    let
      cwd = profiles.${profileName}.cwd;
    in
    if cwd == null then
      ""
    else if cwd.rw then
      "true"
    else
      "false";

  # docker run doesn't inherit the host shell's environment — without these,
  # the container sees no TERM/COLORTERM/TERM_PROGRAM at all, which is why
  # TUIs (Claude Code, opencode) lose color and terminal-capability-gated
  # input handling like Shift+Enter for newlines.
  #
  # LANG/LC_ALL are hardcoded to C.UTF-8 rather than forwarded from the host:
  # the host's locale (e.g. en_US.UTF-8) isn't generated in the node:22 image,
  # which only ships C, C.utf8 and POSIX (verified via `locale -a`), so
  # forwarding it makes bash/perl warn and fall back to C anyway.
  termEnvArgs = lib.concatStringsSep " \\\n          " [
    ''-e TERM="$TERM"''
    ''-e COLORTERM="$COLORTERM"''
    ''-e TERM_PROGRAM="$TERM_PROGRAM"''
    "-e LANG=C.UTF-8"
    "-e LC_ALL=C.UTF-8"
    "-e EDITOR=nvim"
    "-e VISUAL=nvim"
  ];

  mkAssistantArm =
    profileName: agentName:
    let
      agent = agentCatalog.${agentName};
    in
    ''
      ${agentName})
        shift
        build_mount_args "${profileName}" "${mkCwdRwArg profileName}"
        ensure_docker
        docker volume create ${agent.cacheVolume} >/dev/null 2>&1 || true
        docker volume create ${nvimCacheVolume} >/dev/null 2>&1 || true
        exec docker run -it --rm \
          --name ${agentName}-agent-jail \
          ${termEnvArgs} \
          "''${mount_args[@]}" \
          ${mkAgentMountArgs agent} \
          --volume ${agent.cacheVolume}:/root/.npm \
          --volume ${nvimCacheVolume}:/var/cache/apt/archives \
          --workdir "/jail/$workdir" \
          ${image} \
          bash -lc '${nvimSetupCmd} || echo "agent-jail: nvim setup failed, continuing without it" >&2; exec ${mkAgentCmd agent} "$@"' bash "$@"
        ;;
    '';

  mkProfileArm =
    profileName:
    let
      profile = profiles.${profileName};
      assistantArms = lib.concatStringsSep "\n" (map (mkAssistantArm profileName) profile.agents);
      allowed = lib.concatStringsSep ", " (
        profile.agents
        ++ [
          "shell"
          "mounts"
        ]
      );
    in
    ''
        ${profileName})
          shift
          case "''${1:-}" in
      ${assistantArms}
            shell)
              build_mount_args "${profileName}" "${mkCwdRwArg profileName}"
              ensure_docker
              docker volume create ${nvimCacheVolume} >/dev/null 2>&1 || true
              exec docker run -it --rm \
                --name agent-jail \
                ${termEnvArgs} \
                "''${mount_args[@]}" \
                --volume ${nvimCacheVolume}:/var/cache/apt/archives \
                --workdir "/jail/$workdir" \
                ${image} \
                bash -lc '${nvimSetupCmd} || echo "agent-jail: nvim setup failed, continuing without it" >&2; exec bash' bash
              ;;
            mounts)
              build_mount_args "${profileName}" "${mkCwdRwArg profileName}"
              echo "profile: ${profileName} (image: ${image})"
              printf '%s\n' "''${mount_args[@]}"
              ;;
            *)
              echo "error: unknown assistant for profile '${profileName}' (allowed: ${allowed})" >&2
              exit 1
              ;;
          esac
          ;;
    '';

  profileArms = lib.concatStringsSep "\n" (map mkProfileArm profileNames);

  mkAgentFunction = agentName: ''
    ${agentName}-jail() {
      if [ $# -eq 0 ]; then
        echo "usage: ${agentName}-jail <profile> [args...]" >&2
        return 1
      fi
      local profile="$1"
      shift
      agent-jail "$profile" ${agentName} "$@"
    }
  '';

  agentFunctions = lib.concatStringsSep "\n" (map mkAgentFunction (builtins.attrNames agentCatalog));
in
{
  programs.zsh.initContent = agentFunctions;

  home.packages = [
    (pkgs.writeShellApplication {
      name = "agent-jail";
      runtimeInputs = [ pkgs.jq ];
      text = ''
        usage() {
          echo "agent-jail — run AI agents that only see a profile's allowlisted directories"
          echo ""
          echo "  agent-jail <profile> <assistant>   launch that assistant inside the profile's jail"
          echo "  agent-jail <profile> shell         bash inside the jail (see the world as the agent does)"
          echo "  agent-jail <profile> mounts        print that profile's active allowlist"
          echo ""
          echo "profiles: ${lib.concatStringsSep ", " profileNames}"
        }

        ensure_docker() {
          if ! command -v docker >/dev/null 2>&1; then
            echo "error: Docker not installed (should be provisioned via nix-homebrew — check nix/profiles/brew.nix)" >&2
            exit 1
          fi

          if ! docker info >/dev/null 2>&1; then
            echo "agent-jail: starting Docker Desktop..." >&2
            open --background -a Docker
            for _ in $(seq 1 30); do
              docker info >/dev/null 2>&1 && break
              sleep 1
            done
            if ! docker info >/dev/null 2>&1; then
              echo "error: Docker Desktop did not become ready in time" >&2
              exit 1
            fi
          fi
        }

        build_mount_args() {
          local profile="$1"
          local cwd_rw="$2"
          local data
          data="$(jq -e --arg p "$profile" '.[$p] // empty' "${secretsPath}")" || data=""
          if [ -z "$data" ]; then
            echo "error: profile '$profile' not found in decrypted secrets — check secrets/agent-jail-profiles.enc.json" >&2
            exit 1
          fi
          local root m path rw pwd_base
          root="$(jq -r '.root' <<<"$data")"
          workdir="$(jq -r '.workingDir // "."' <<<"$data")"
          mount_args=()
          while IFS= read -r m; do
            path="$(jq -r '.path' <<<"$m")"
            rw="$(jq -r '.rw' <<<"$m")"
            if [ "$rw" = "true" ]; then
              mount_args+=(--volume "$root/$path:/jail/$path")
            else
              mount_args+=(--mount "type=bind,source=$root/$path,target=/jail/$path,readonly")
            fi
          done < <(jq -c '.mounts[]' <<<"$data")
          if [ -n "$cwd_rw" ]; then
            if [ "$PWD" = "$HOME" ] || [ "$PWD" = "/" ]; then
              echo "error: refusing to mount \$PWD ('$PWD') into the jail — too broad" >&2
              exit 1
            fi
            pwd_base="$(basename "$PWD")"
            for m in "''${mount_args[@]}"; do
              case "$m" in
                *":/jail/$pwd_base"|*",target=/jail/$pwd_base,"*)
                  echo "error: cwd mount '/jail/$pwd_base' collides with an existing mount in profile '$profile'" >&2
                  exit 1
                  ;;
              esac
            done
            if [ "$cwd_rw" = "true" ]; then
              mount_args+=(--volume "$PWD:/jail/$pwd_base")
            else
              mount_args+=(--mount "type=bind,source=$PWD,target=/jail/$pwd_base,readonly")
            fi
          fi
        }

        case "''${1:-}" in
          -h|--help|help)
            usage
            exit 0
            ;;
          "")
            usage >&2
            exit 1
            ;;
        esac

        workdir="."
        mount_args=()

        case "$1" in
        ${profileArms}
          *)
            echo "error: unknown profile '$1' (known: ${lib.concatStringsSep ", " profileNames})" >&2
            exit 1
            ;;
        esac
      '';
    })
  ];
}
