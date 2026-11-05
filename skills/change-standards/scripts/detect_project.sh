#!/usr/bin/env bash
# Read-only inventory of a repository. Prints evidence (facts with file:line),
# never conclusions. The agent turns this evidence into candidate commands and
# then verifies them by running them.
set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" || exit 1

section() { printf '\n## %s\n' "$1"; }
has() { [ -e "$1" ] && echo "- $1"; }
grep_ev() { # pattern files... -> file:line: text (max 15 lines)
  local pat="$1"; shift
  grep -HnIE "$pat" "$@" 2>/dev/null | grep -v '^\s*#' | head -15 | sed 's/^/- /'
}

echo "# Project inventory: $(basename "$(pwd)")"

section "Stack markers"
for f in pyproject.toml setup.py setup.cfg requirements*.txt Pipfile poetry.lock \
         package.json pnpm-lock.yaml yarn.lock go.mod Cargo.toml pom.xml \
         serverless.yml template.yaml Dockerfile docker-compose*.yml; do
  for m in $f; do has "$m"; done
done

section "Test runner config"
has pytest.ini; has tox.ini; has noxfile.py; has conftest.py
grep_ev '^\[tool\.pytest|^\[pytest\]|^\[tool:pytest\]|testpaths|markers|addopts' \
  pytest.ini pyproject.toml setup.cfg tox.ini
[ -f package.json ] && grep_ev '"(test|test:[a-z]+|lint|coverage)"\s*:' package.json

section "Test layout (dir: test files)"
for d in tests test __tests__ spec; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 2 -type d -not -path '*/__pycache__*' | sort | while read -r sub; do
    n=$(find "$sub" -maxdepth 1 -type f \( -name 'test_*.py' -o -name '*_test.py' \
        -o -name 'test_case_*.py' -o -name '*.test.*' -o -name '*.spec.*' \) | wc -l)
    echo "- $sub: $n"
  done
done

section "Integration signals (fixtures / real services in tests)"
grep_ev 'mongomock|moto|testcontainers|localstack|docker|responses|httpx_mock|requests_mock|@pytest\.mark\.integration|TestClient|pytest-asyncio' \
  $(find . -path ./venv -prune -o -path ./node_modules -prune -o \
        \( -name 'conftest.py' -o -name 'base_test.py' -o -name 'requirements*dev*.txt' \
           -o -name 'requirements*test*.txt' -o -name 'pyproject.toml' \) -print 2>/dev/null)

section "Commands found in automation"
for f in bitbucket-pipelines.yml Makefile pavement.py tox.ini run_test*.sh scripts/*.sh Scripts/*.sh; do
  [ -f "$f" ] || continue
  grep_ev 'pytest|unittest|coverage|flake8|ruff|pyright|mypy|black|npm (run )?(test|lint)|jest|vitest|go test|make [a-z]|paver' "$f"
done

section "Commands documented"
for f in README.md CONTRIBUTING.md CLAUDE.md AGENTS.md docs/*.md; do
  [ -f "$f" ] && grep_ev '(pytest|run_test|npm (run )?test|make test|tox|nox|docker compose .*test)' "$f"
done

section "Lint config"
has .flake8; has ruff.toml; has .ruff.toml; has .pre-commit-config.yaml; has .pylintrc
grep_ev '^\[tool\.(ruff|black|mypy|pyright)|^\[flake8\]' pyproject.toml setup.cfg tox.ini

section "Changelog and agent instructions"
ls -1 2>/dev/null | grep -iE '^changelog' | sed 's/^/- /'
for f in CLAUDE.md AGENTS.md GEMINI.md .kiro/steering .cursor/rules .ai/change-standard.md .githooks; do has "$f"; done

section "Pipeline steps"
if [ -f bitbucket-pipelines.yml ]; then
  grep_ev 'name:' bitbucket-pipelines.yml
  grep -qiE 'pytest|npm (run )?test|go test' bitbucket-pipelines.yml \
    && echo "- pipeline runs tests: yes" || echo "- pipeline runs tests: NO"
else
  echo "- no bitbucket-pipelines.yml"
fi
