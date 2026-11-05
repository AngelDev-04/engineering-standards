#!/usr/bin/env bash
# Deterministic check of a set of commits against the company baseline and
# the project standard (.ai/change-standard.md). No AI involved.
#
# Usage: check_change.sh [<base-ref>]
#   base-ref defaults to the upstream of the current branch, then origin/HEAD,
#   then HEAD~1.
# Env:
#   ES_SKIP_TESTS=1   do not run the unit command (format and file checks only)
set -uo pipefail

root="$(git rev-parse --show-toplevel)" || exit 1
cd "$root"
here="$(cd "$(dirname "$0")" && pwd)"
standard=".ai/change-standard.md"
fail=0
err()  { echo "  FAIL  $*"; fail=1; }
ok()   { echo "  ok    $*"; }
warn() { echo "  warn  $*"; }

base="${1:-}"
if [[ -z "$base" ]]; then
  base="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" ||
  base="$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null)" ||
  base="HEAD~1"
fi
range="$base..HEAD"
commits="$(git rev-list --no-merges "$range" 2>/dev/null)"
echo "change-standards check ($range)"
[[ -z "$commits" ]] && { ok "no new commits"; exit 0; }

# --- read project standard -------------------------------------------------
get() { # key -> value from the ```standard block
  [[ -f "$standard" ]] || return 0
  awk '/^```standard/{f=1;next} /^```/{f=0} f' "$standard" |
    sed -n "s/^$1:[[:space:]]*//p" | head -n1 | sed 's/[[:space:]]*$//'
}
if [[ ! -f "$standard" ]]; then
  warn "$standard missing: run the change-standards bootstrap (any agent: 'bootstrap the change standard')"
fi
src_paths="$(get source_paths)"; test_paths="$(get test_paths)"
changelog="$(get changelog)"; changelog="${changelog:-CHANGELOG.md}"
unit_cmd="$(get unit)"
[[ "$unit_cmd" == "<"* ]] && unit_cmd=""

# --- commit messages ------------------------------------------------------
needs_changes=0
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
for c in $commits; do
  git log -1 --format=%B "$c" > "$tmp"
  if out="$("$here/validate_commit_msg.sh" "$tmp" 2>&1)"; then
    ok "message $(git log -1 --format='%h %s' "$c")"
  else
    err "message $(git log -1 --format='%h' "$c"):"; echo "$out" | sed 's/^/        /'
  fi
  head -n1 "$tmp" | grep -qE '^(feat|fix)(\(|!|:)' && needs_changes=1
done

# --- changed files --------------------------------------------------------
changed="$(git diff --name-only "$range")"
is_test() { # path -> 0 if it is a test file
  local p="$1" t
  for t in $test_paths; do [[ "$p" == "$t"/* ]] && return 0; done
  [[ "$p" =~ (^|/)(tests?|__tests__|spec)/ || "$p" =~ (^|/)test_[^/]*\.py$ || "$p" =~ _test\.(py|go)$ || "$p" =~ \.(test|spec)\.[jt]sx?$ ]]
}
is_src() {
  local p="$1" s
  is_test "$p" && return 1
  if [[ -n "$src_paths" ]]; then
    for s in $src_paths; do [[ "$p" == "$s"/* || "$p" == "$s" ]] && return 0; done
    return 1
  fi
  [[ "$p" =~ \.(py|js|ts|tsx|jsx|go|java|kt|rb|php|cs)$ ]]
}
src_changed=0; tests_changed=0; changelog_changed=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  is_src "$f" && src_changed=1
  is_test "$f" && tests_changed=1
  [[ "$f" == "$changelog" ]] && changelog_changed=1
done <<<"$changed"

if (( src_changed && needs_changes )); then
  (( changelog_changed )) && ok "$changelog updated" || err "feat/fix changes source code but $changelog was not updated"
  (( tests_changed ))     && ok "tests added or changed" || err "feat/fix changes source code but no test file changed"
elif (( src_changed )); then
  ok "source changed by refactor/perf/chore: CHANGELOG and new tests not required"
fi
if (( changelog_changed )) && ! git show "HEAD:$changelog" 2>/dev/null | grep -q '^## \[Unreleased\]'; then
  err "$changelog has no '## [Unreleased]' section"
fi

# --- unit tests -----------------------------------------------------------
if (( src_changed || tests_changed )) && [[ "${ES_SKIP_TESTS:-0}" != 1 ]]; then
  if [[ -n "$unit_cmd" ]]; then
    echo "  run   $unit_cmd"
    if bash -c "$unit_cmd" > "$tmp" 2>&1; then ok "unit tests"; else err "unit tests failed:"; tail -n 20 "$tmp" | sed 's/^/        /'; fi
  else
    warn "no verified unit command in $standard; tests not run"
  fi
fi

(( fail )) && { echo "change-standards: FAILED (fix the items above; see .ai/change-standard.md)"; exit 1; }
echo "change-standards: OK"
