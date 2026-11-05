#!/usr/bin/env bash
# engineering-standards installer.
#
#   curl -fsSL https://raw.githubusercontent.com/AngelDev-04/engineering-standards/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --ref v0.1.0 --agent kiro
#
# Options:
#   --ref <tag|branch>   version to install (default: main; in an installed repo, the pinned one)
#   --upgrade <tag>      reinstall an already installed repo at another version
#   --agent <name>       bootstrap agent: auto (ask), kiro, claude, gemini, codex, opencode, none
#   --source <dir>       install from a local checkout instead of downloading
#   --yes                do not ask; use the first detected agent (or --agent)
# Env: ES_REPO (default AngelDev-04/engineering-standards), ES_MODEL (bootstrap model override)
set -euo pipefail

REPO="${ES_REPO:-AngelDev-04/engineering-standards}"
REF=""; AGENT="auto"; SOURCE=""; YES=0
while (( $# )); do
  case "$1" in
    --ref) REF="$2"; shift 2 ;;
    --upgrade) REF="${2:-main}"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) sed -n "2,14p" "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "run this inside a git repository" >&2; exit 1; }
cd "$root"

enable_hooks() {
  local current
  current="$(git config --get core.hooksPath || true)"
  if [[ -n "$current" && "$current" != ".githooks" ]]; then
    echo "  core.hooksPath is '$current'; not changed. Point it to .githooks or chain the hooks." >&2
  else
    git config core.hooksPath .githooks
  fi
}

# Already installed and no explicit version: this is a fresh clone (or a
# re-run). Keep the pinned version, only activate the hooks.
locked="$(sed -n 's/^version: //p' .ai/standards.lock 2>/dev/null || true)"
if [[ -z "$REF" && -z "$SOURCE" && -n "$locked" && -d .githooks ]]; then
  enable_hooks
  say "engineering-standards $locked already installed; hooks enabled (core.hooksPath=.githooks)"
  [[ -f .ai/change-standard.md ]] || say "project standard missing: ask any agent to 'bootstrap the change standard'"
  say "to upgrade: ... | bash -s -- --upgrade <tag>"
  exit 0
fi
REF="${REF:-main}"

# --- 1. fetch ---------------------------------------------------------------
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
if [[ -n "$SOURCE" ]]; then
  src="$(cd "$SOURCE" && pwd)"
  version="local:$(git -C "$src" describe --tags --always --dirty 2>/dev/null || echo unknown)"
else
  say "downloading $REPO@$REF"
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | tar -xz -C "$tmp"
  src="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  version="$REF"
fi
[[ -f "$src/skills/change-standards/SKILL.md" ]] || { echo "invalid source: $src" >&2; exit 1; }

# --- 2. deterministic install ----------------------------------------------
say "installing skill and hooks ($version)"
for dest in .ai/skills .claude/skills .kiro/skills .agents/skills .opencode/skills; do
  mkdir -p "$dest"
  rm -rf "$dest/change-standards"
  cp -R "$src/skills/change-standards" "$dest/change-standards"
done
chmod +x .ai/skills/change-standards/scripts/*.sh
mkdir -p .githooks
for h in commit-msg pre-push; do
  if [[ -f ".githooks/$h" ]] && ! grep -q change-standards ".githooks/$h"; then
    echo "  .githooks/$h exists and is not ours; leaving it. Call .ai/skills/change-standards hooks from it manually." >&2
    continue
  fi
  cp "$src/hooks/$h" ".githooks/$h"; chmod +x ".githooks/$h"
done
enable_hooks
cat > .ai/standards.lock <<EOF
repo: $REPO
version: $version
installed: $(date +%F)
EOF
say "installed: .ai/skills, .claude/skills, .kiro/skills, .agents/skills, .opencode/skills, .githooks, .ai/standards.lock"

# --- 3. bootstrap with an agent ---------------------------------------------
if [[ -f .ai/change-standard.md ]]; then
  say ".ai/change-standard.md already exists; skipping bootstrap"
  exit 0
fi

PROMPT='Use the change-standards skill installed at .ai/skills/change-standards (read its SKILL.md first). The file .ai/change-standard.md does not exist, so run the Bootstrap described in .ai/skills/change-standards/references/bootstrap.md for this repository: collect evidence with the detect script, propose and actually run the commands, iterate on failures, and write the project standard, CHANGELOG.md if missing, and the agent pointer files. Do not modify application code, tests, the pipeline or dependencies. Do not commit. End with the bootstrap report.'

detected=()
command -v kiro-cli >/dev/null && detected+=(kiro)
command -v claude   >/dev/null && detected+=(claude)
command -v gemini   >/dev/null && detected+=(gemini)
command -v codex    >/dev/null && detected+=(codex)
command -v opencode >/dev/null && detected+=(opencode)

if [[ "$AGENT" == "auto" ]]; then
  if (( ${#detected[@]} == 0 )); then
    AGENT=none
  elif (( YES )) || [[ ! -r /dev/tty ]]; then
    AGENT="${detected[0]}"
  else
    echo "Detected agents: ${detected[*]}"
    echo "The bootstrap runs one agent headless: it reads the repo, runs the test/lint commands and writes .ai/change-standard.md. It uses that agent's credits."
    read -r -p "Agent for bootstrap [${detected[*]} none] (default ${detected[0]}): " ans </dev/tty || ans=""
    AGENT="${ans:-${detected[0]}}"
  fi
fi

model="${ES_MODEL:-}"
case "$AGENT" in
  kiro)   cmd=(kiro-cli chat --no-interactive --trust-all-tools ${model:+--model "$model"} "$PROMPT") ;;
  claude) cmd=(claude -p "$PROMPT" --permission-mode acceptEdits --allowedTools "Bash Read Write Edit Glob Grep" ${model:+--model "$model"}) ;;
  gemini) cmd=(gemini --approval-mode yolo ${model:+--model "$model"} -p "$PROMPT") ;;
  codex)  cmd=(codex exec --full-auto ${model:+--model "$model"} "$PROMPT") ;;
  opencode) cmd=(opencode run --auto ${model:+-m "$model"} "$PROMPT") ;;
  none)
    say "bootstrap pending. Open any agent in this repo and ask: \"bootstrap the change standard\""
    exit 0 ;;
  *) echo "unknown agent: $AGENT" >&2; exit 2 ;;
esac

say "bootstrap with $AGENT (this can take a few minutes)"
if "${cmd[@]}"; then
  [[ -f .ai/change-standard.md ]] && say "done. Review with: git status && git diff" \
    || say "agent finished but .ai/change-standard.md was not created; ask an agent to 'bootstrap the change standard'"
else
  say "bootstrap failed (exit $?). Retry later: ask any agent to 'bootstrap the change standard'"
fi
