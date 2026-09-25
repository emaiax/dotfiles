# 🤖 Claudio

Claudio is an agentic pair-programming and development orchestration system configured declaratively via Nix for macOS.

While underlying AI CLI tools (such as Claude Code, Google Antigravity CLI, or OpenCode) provide raw model execution and basic tool hooks, Claudio layers persona, voice, approval discipline, multi-profile isolation, security gating, and token optimization across all of them in a runtime-agnostic architecture.

---

## 🎯 What is Claudio?

Claudio is designed as a persistent, disciplined software development assistant specialized in:
- **Software Development**: Declarative infrastructure (Nix flakes, nix-darwin, home-manager), full-stack services, shell scripts, and system automation.
- **Homelab & Networking**: Managing Proxmox, local DNS, WireGuard, and self-hosted instances (`*.emx.casa`, `*.local`).
- **Knowledge & Notes**: Obsidian vault integration and personal knowledge management.

### Key Tenets
- **Persona & Voice**: Communicates interactively in Portuguese (`pt-BR`), while authoring all repository code, documentation, and commit messages in English. Employs concise, factual reasoning without flattery or rhetorical flourishes.
- **Strict Approval Discipline**: Irreversible or public-facing actions (git commits, pushes, pull requests, issue creation, and destructive filesystem operations) require explicit turn-by-turn user confirmation.
- **Kaizen Loop**: Retains an active feedback cycle documented in [`docs/kaizen.md`](docs/kaizen.md) where mistakes, unexpected tool behaviors, or ambiguous rules are recorded and systematically addressed.

---

## 🏗️ Architecture

Claudio separates system prompt persona, declarative security policies, and tool execution into distinct, modular layers:

```
claudio/
├── AGENTS.md                  # Core system prompt, persona, voice, and rules
├── docs/                      # Contextual procedures (kaizen, development, writing, etc.)
├── skills/                    # Progressive on-demand skills (e.g., nixpkgs PR checklist)
├── permissions.nix            # Security policy defined as pure data
├── permissions.tsv            # Policy consumers, backend matrix, and rule comparison
├── options.nix                # Nix options (programs.claudio: backend, permissions, rtk)
├── antigravity/               # Antigravity CLI adapter (config links and hooks.json)
├── claude-code/               # Claude Code adapter (Seatbelt sandbox and settings.json)
├── opencode/                  # OpenCode adapter (permission schema)
├── hooks/                     # Tool interception hooks (antigravity-hook.sh, rtk-hook.sh)
├── profiles/                  # Wrapper binaries (claudio, claude-yolo, claudio-thebot)
└── profiles/tests/            # Static & dynamic test suite
```

### Decoupled Core
- **Prompts & Instructions**: [`AGENTS.md`](AGENTS.md), [`docs/`](docs/), and [`skills/`](skills/) follow standard conventions discovered natively by both Antigravity CLI (`agy`) and Claude Code (`~/.claude/`).
- **Security Policy as Data**: [`permissions.nix`](permissions.nix) defines raw lists of commands (`ask`, `denyHard`, `denySoft`), credential paths, and network targets independently of any specific agent implementation.

---

## 👥 Execution Profiles

Claudio provides three distinct operational profiles tailored for different workflows:

### 1. `claudio` (Interactive Pair Programmer)
- **Purpose**: Primary interactive workflow.
- **Security**: Full protection. Prompts for destructive commands (`git push`, `rm -rf`, `git reset --hard`), hard-blocks dangerous forge operations (`gh pr merge`, `fj pr merge`), and prevents access to sensitive credentials.
- **Integration**: Supports Obsidian vault access via `.obsidian-cli.sock`.

### 2. `claude-yolo` (Unattended / Fast Prototyping)
- **Purpose**: High-velocity or unattended single-session tasks where interactive approval prompts are bypassed.
- **Security**: Bypasses confirmation prompts (`--dangerously-skip-permissions`), but strictly retains credential protection (`~/.ssh`, `~/.aws`, `~/.sops`, `1Password`).

### 3. `claudio-thebot` (Autonomous Worker & Bot Identity)
- **Purpose**: Autonomous workflows, CI jobs, or automated maintenance scripts.
- **Identity Isolation**: Injects dedicated wrapper binaries for `git`, `gh`, and `fj` under a sandboxed `identity-bin` directory:
  - Custom git committer identity (`claudio-thebot`) and SSH commit signing keys (`claudio-codes.pub`).
  - Automated Forgejo (`fj`) and GitHub (`gh`) authentication using decrypted SOPS tokens.
  - Passes `--add-dir` for workspace context and enforces unattended execution.

---

## 🔄 Multi-Runtime CLI Dispatcher

All profiles feature a unified CLI dispatcher supporting multiple execution backends:

```bash
# Default backend (configured via Nix programs.claudio.backend or CLAUDIO_BACKEND)
claudio "inspect recent commits"

# Explicit runtime selection
claudio --backend agy
claudio --backend claude-code
claudio --backend opencode
claudio -b agy

# Quick sugar flags
claudio --agy
claudio --claude
claudio --opencode

# Pass-through arguments forwarded intact to the backend
claudio --agy --model gemini-2.5-pro -p "run review"
claudio --claude --dangerously-skip-permissions
```

### Precedence Hierarchy
1. **CLI Flag**: `--agy`, `--claude`, `--backend <name>` (highest priority).
2. **Environment Variable**: `CLAUDIO_BACKEND=agy`.
3. **Declarative Nix Default**: `programs.claudio.backend = "claude-code";` (or `"agy"`).

### Declarative Configuration (`programs.claudio`)

Declarative options configured under `programs.claudio` propagate across all agent runtimes automatically:

```nix
programs.claudio = {
  enable = true;
  backend = "claude-code"; # "claude-code" | "agy" | "opencode"

  permissions = {
    commands = {
      extraAllow = [
        "cargo *"
        "pnpm *"
        "just build *"
        "watchexec *"
      ];
      extraAsk = [
        "darwin-rebuild switch *"
        "just switch *"
        "brew install *"
        "kubectl apply *"
      ];
      extraDenyHard = [
        "sudo nix-collect-garbage *"
        "sops decrypt *"
        "op item delete *"
        "terraform destroy *"
      ];
    };
    network = {
      extraAllowedDomains = [ "api.linear.app" ];
    };
    filesystem = {
      extraCredentials = [ "\${config.home.homeDirectory}/.kube/config" ];
      extraToolchainPaths = [ "\${config.home.homeDirectory}/work" ];
    };
  };

  rtk.enable = true;
};
```

---

## 🛡️ Permission & Safety Matrix

Full policy definitions are documented in [`permissions.tsv`](permissions.tsv).

### Backend & Profile Overview

| Backend | Profile | Mode | Credentials Protection | Destructive Command Gate | Hard Deny (Merge/Release) | RTK Rewrites | Sandbox Layer |
| :--- | :--- | :--- | :--- | :--- | :---: | :--- | :--- |
| **agy** | `claudio` | `default` | 🛑 (file tools + cmd inspection) | 🟡 (interactive prompt) | 🛑 | ⚡ (`rtk rewrite`) | Terminal restrictions (`--sandbox` optional) |
| **agy** | `claudio-yolo` | `bypass` | 🛑 (file tools + cmd inspection) | 🟢 (`CLAUDIO_DANGEROUSLY_SKIP_PERMISSIONS=1`) | 🛑 | ⚡ (`rtk rewrite`) | ⚪ None |
| **agy** | `claudio-thebot` | `bypass` | 🛑 (file tools + cmd inspection) | 🟢 (`CLAUDIO_DANGEROUSLY_SKIP_PERMISSIONS=1`) | 🛑 | ⚡ (`rtk rewrite`) | ⚪ None (`identity-bin` PATH injection) |
| **claude-code** | `claudio` | `auto` | 🛑 (Read/Edit tool rules) | 🟡 (interactive prompt) | 🛑 | ⚡ (`rtk hook claude`) | Seatbelt network allowlist (filesystem disabled) |
| **claude-code** | `claudio-yolo` | `bypass` | 🛑 (`credentialDenyOnly`) | 🟢 (`--dangerously-skip-permissions`) | 🟢 | ⚡ (`rtk hook claude`) | ⚪ None (`sandbox.enabled = false`) |
| **claude-code** | `claudio-thebot` | `bypass` | 🟢 (clean `identity-bin` environment) | 🟢 (`--dangerously-skip-permissions`) | 🟢 | ⚡ (`rtk hook claude`) | ⚪ None (`sandbox.enabled = false`) |
| **opencode** | `claudio` | `default` | 🛑 (`*.env` patterns) | 🟢 (flat bash allow, `external_directory` = 🟡) | 🟢 | ⚪ None | ⚪ None |
| **opencode** | `claudio-yolo` | `auto` | 🛑 (`*.env` patterns) | 🟢 (`--auto`) | 🟢 | ⚪ None | ⚪ None |
| **opencode** | `claudio-thebot` | `auto` | 🛑 (`*.env` patterns) | 🟢 (`--auto`) | 🟢 | ⚪ None | ⚪ None |

### Detailed Command & Target Comparison

| Rule Type | Target | Claude: claudio | Claude: claudio-yolo | Claude: claudio-thebot | AGY: claudio | AGY: claudio-yolo | AGY: claudio-thebot | OpenCode |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Command** | `fj pr create` | 🟠 | 🟢 | 🟢 | 🟠 | 🟠 | 🟠 | 🟢 |
| **Command** | `fj pr merge` | 🛑 | 🟢 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **Command** | `fj release` | 🛑 | 🟢 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **Command** | `gh pr create` | 🟠 | 🟢 | 🟢 | 🟠 | 🟠 | 🟠 | 🟢 |
| **Command** | `gh pr merge` | 🛑 | 🟢 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **Command** | `gh release` | 🛑 | 🟢 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **Command** | `git checkout .` | 🟡 | 🟢 | 🟢 | 🟡 | 🟢 | 🟢 | 🟢 |
| **Command** | `git checkout --` | 🟡 | 🟢 | 🟢 | 🟡 | 🟢 | 🟢 | 🟢 |
| **Command** | `git clean` | 🟡 | 🟢 | 🟢 | 🟡 | 🟢 | 🟢 | 🟢 |
| **Command** | `git push` | 🟡 | 🟢 | 🟢 | 🟡 | 🟢 | 🟢 | 🟢 |
| **Command** | `git rebase` | 🟡 | 🟢 | 🟢 | 🟡 | 🟢 | 🟢 | 🟢 |
| **Command** | `git reset --hard` | 🟡 | 🟢 | 🟢 | 🟡 | 🟢 | 🟢 | 🟢 |
| **Command** | `git restore` | 🟡 | 🟢 | 🟢 | 🟡 | 🟢 | 🟢 | 🟢 |
| **Command** | `rm -rf` | 🟡 | 🟢 | 🟢 | 🟡 | 🟢 | 🟢 | 🟢 |
| **Directory** | `~/.aws` | 🛑 | 🛑 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **Directory** | `~/.config/1Password` | 🛑 | 🛑 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **Directory** | `~/.config/sops` | 🛑 | 🛑 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **Directory** | `~/.gnupg` | 🛑 | 🛑 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **Directory** | `~/.ssh` | 🛑 | 🛑 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **File** | `~/.claude/.credentials.json` | 🛑 | 🛑 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **File** | `~/.local/share/opencode/auth.json` | 🛑 | 🛑 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **File** | `~/.netrc` | 🛑 | 🛑 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **File** | `~/.npmrc` | 🛑 | 🛑 | 🟢 | 🛑 | 🛑 | 🛑 | 🟢 |
| **Pattern** | `*.env` | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🛑 |
| **Rewrite** | `git log / status / diff` | ⚡ | ⚡ | ⚡ | ⚡ | ⚡ | ⚡ | ⚪ |
| **Rewrite** | `grep / rg / ls / find` | ⚡ | ⚡ | ⚡ | ⚡ | ⚡ | ⚡ | ⚪ |

### Legend

| Symbol | Action | Description |
| :---: | :--- | :--- |
| 🟢 | **Allow** | Automatically permitted without interactive confirmation |
| 🟡 | **Ask** | Prompts for interactive user approval before execution |
| 🟠 | **Soft Deny** | Discouraged via agent instructions (`AGENTS.md` / Claude prompt) |
| 🛑 | **Deny** | Hard blocked by security hook or permission rules (fails immediately) |
| ⚡ | **RTK Rewrite** | Command intercepted and compressed via RTK to optimize tokens |
| ⚪ | **None** | No restriction or interception layer applied |

### Antigravity Settings & Activation Lifecycle

While Claude Code and OpenCode link settings via out-of-store symlinks, `agy` atomically replaces `~/.gemini/antigravity-cli/settings.json` on save with a standalone file (`0600`), unlinking symlinks. To handle this cleanly via `just switch`:
- **Nix Declarations**: Configured via `programs.antigravity-cli.settings` and `programs.antigravity-cli.permissions.allow` (populated by Claudio's `permissions.nix`).
- **Activation Merge**: During `just switch`, home-manager performs a non-destructive `jq` merge:
  1. Base settings (`colorScheme`, `enableTelemetry`, `verbosity`) are enforced.
  2. Live `trustedWorkspaces` are preserved intact.
  3. Pre-approved commands from Nix and ad-hoc interactive approvals are unioned (`unique(live + nix)`).
  4. Tracked seed files (`antigravity-cli/settings.json` and `claudio/antigravity/settings.json`) are synchronized with the declarative state.

---

## ⚡ Token Optimization (RTK)

Claudio integrates [RTK (`rtk-ai/rtk`)](https://github.com/rtk-ai/rtk) to intercept CLI tool calls and compress verbose output (e.g. `git diff`, `git log`, `grep`, test runners) before token consumption:
- **Claude Code**: Intercepted via `hooks.PreToolUse` running `bash "${claudioPath}/hooks/rtk-hook.sh"`.
- **Antigravity CLI**: Intercepted via `~/.gemini/config/hooks.json` running `bash "${claudioPath}/hooks/antigravity-hook.sh"` with `rtk rewrite`.

---

## 🧪 Testing

The test suite in [`profiles/tests/`](profiles/tests/) validates configuration artifacts, CLI resolution, and boundary enforcement:

```bash
# Run static assertions and CLI dispatch tests (free, no token cost)
modules/user/apps/claudio/profiles/tests/run.sh --static-only

# Run full probe suite including dynamic headless sessions
modules/user/apps/claudio/profiles/tests/run.sh
```
