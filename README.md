# engineering-standards

One change standard for every service: commit message format, CHANGELOG entry, and unit plus integration tests that run with each project's real commands. Packaged as an agent skill (Claude Code, Kiro, Gemini CLI, Codex) plus deterministic git hooks.

## Install in a repository

```bash
cd your-service
curl -fsSL https://raw.githubusercontent.com/AngelDev-04/engineering-standards/main/install.sh | bash
# pin a version / choose the agent:
curl -fsSL https://raw.githubusercontent.com/AngelDev-04/engineering-standards/main/install.sh | bash -s -- --ref v0.1.0 --agent kiro
```

The installer:

1. Copies the `change-standards` skill to `.ai/skills`, `.claude/skills`, `.kiro/skills` and `.agents/skills` (Codex and Gemini read `.agents/skills`).
2. Installs `.githooks/commit-msg` and `.githooks/pre-push` and sets `git config core.hooksPath .githooks`.
3. Writes `.ai/standards.lock` with the installed version.
4. Bootstraps the project standard with an agent CLI it detects (`kiro-cli`, `claude`, `gemini`, `codex`). It asks first because it uses that agent's credits. `--agent none` skips it; any agent can do it later when asked to "bootstrap the change standard".

Commit everything it creates. Each repository then carries its own versioned copy; upgrading is re-running the installer with a new `--ref` and reviewing the diff.

Installation is per repository: run the command at the repository root; nothing is installed globally.

On a fresh clone of a repository that already has it, run the same `curl ... | bash`: it keeps the pinned version in `.ai/standards.lock`, changes no files and only enables the hooks (git does not clone `core.hooksPath`). Agents using the skill also re-enable them if missing. To change version: `... | bash -s -- --upgrade v0.2.0`.

## How it works

| Piece | Who | What |
|---|---|---|
| `references/baseline.md` | fixed for every repo | commit format, CHANGELOG format, test rules |
| `.ai/change-standard.md` | generated per repo by an agent, verified by running the commands | unit/integration/lint commands, where tests go, gaps |
| `scripts/detect_project.sh` | deterministic | evidence for the bootstrap (`file:line` facts, no conclusions) |
| `scripts/validate_commit_msg.sh` | deterministic, `commit-msg` hook | rejects non-compliant messages |
| `scripts/check_change.sh` | deterministic, `pre-push` hook | messages, CHANGELOG and tests changed for `feat`/`fix`, unit tests green |

The agent writes and verifies the project standard once; the scripts enforce it on every commit and push without AI. The skill tells agents to keep the project standard up to date when commands change, never relaxing the baseline.

## Commit format

```
fix(ABC-123): use the active invoice when reprocessing a payment

Why: ...
What: ...
Risk: ...
Tests: ...
```

Full rules: [`skills/change-standards/references/baseline.md`](skills/change-standards/references/baseline.md).

## Skipping

`git commit --no-verify` / `ES_SKIP_HOOKS=1 git push` exist for emergencies. The PR review agent and, later, the pipeline check the same rules.
