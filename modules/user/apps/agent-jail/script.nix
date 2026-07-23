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

  mkAgentMount = { host, container }: ''--volume "${host}:${container}"'';
  mkAgentMountArgs =
    agent: lib.concatStringsSep " \\\n              " (map mkAgentMount agent.mounts);
  mkAgentCmd = agent: lib.concatStringsSep " " agent.cmd;

  mkAssistantArm =
    profileName: agentName:
    let
      agent = agentCatalog.${agentName};
    in
    ''
      ${agentName})
        shift
        docker volume create ${agent.cacheVolume} >/dev/null 2>&1 || true
        build_mount_args "${profileName}"
        exec docker run -it --rm \
          "''${mount_args[@]}" \
          ${mkAgentMountArgs agent} \
          --volume ${agent.cacheVolume}:/root/.npm \
          --workdir "/jail/$workdir" \
          ${image} \
          ${mkAgentCmd agent} "$@"
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
              build_mount_args "${profileName}"
              exec docker run -it --rm \
                "''${mount_args[@]}" \
                --workdir "/jail/$workdir" \
                ${image} \
                bash
              ;;
            mounts)
              build_mount_args "${profileName}"
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

  mkAlias = profileName: agentName: {
    name = "${profileName}-${agentName}";
    value = "agent-jail ${profileName} ${agentName}";
  };

  aliases = lib.listToAttrs (
    lib.concatMap (profileName: map (mkAlias profileName) profiles.${profileName}.agents) profileNames
  );
in
{
  programs.zsh.shellAliases = aliases;

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

        build_mount_args() {
          local profile="$1"
          local data
          data="$(jq -e --arg p "$profile" '.[$p] // empty' "${secretsPath}")" || data=""
          if [ -z "$data" ]; then
            echo "error: profile '$profile' not found in decrypted secrets — check secrets/agent-jail-profiles.enc.json" >&2
            exit 1
          fi
          local root m path rw
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
        }

        case "''${1:-}" in
          -h|--help|help|"")
            usage
            exit 0
            ;;
        esac

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
