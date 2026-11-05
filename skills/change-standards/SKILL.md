---
name: change-standards
description: Engineering change standard for every code change. Use this skill whenever you modify, add or delete code, tests, configuration or dependencies in a repository, and before every commit or pull request, even if the user only asks for a "small fix" and never mentions commits, changelog or tests. It enforces one commit message format, a CHANGELOG entry, and unit plus integration tests that run with the project's real commands. If the repository has no .ai/change-standard.md yet, it bootstraps one first.
---

# Change standards

Every change ships with three things: tests that prove it, a CHANGELOG entry that explains it to whoever operates the service, and a commit message that explains why it was made. Reviewers (human and the PR review agent) check exactly these three, so doing them here saves a review round.

There are two kinds of rules:

- **Company baseline** (`references/baseline.md`): identical in every repository. Commit format, CHANGELOG format, which changes need which tests. Never relax it to fit a project.
- **Project standard** (`.ai/change-standard.md` in the repo): how the baseline is met *here*. Real test and lint commands, where each kind of test lives, known gaps. It is generated once per repository and versioned with it.

## Step 0: pick the mode

- `.ai/change-standard.md` does not exist → run **Bootstrap** (`references/bootstrap.md`), then continue with Apply if there is a pending change.
- It exists → run **Apply**.

## Apply (every change)

1. **Read** `.ai/change-standard.md` and `references/baseline.md`.
2. **Classify** the change with one commit type (`feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `ci`, `revert`). The type decides what is required:
   | Type | Tests required | CHANGELOG |
   |---|---|---|
   | `fix` | a test that fails without the fix | yes, `Fixed` |
   | `feat` | unit tests; integration test if it touches I/O | yes, `Added`/`Changed` |
   | `refactor`, `perf` | existing tests must pass; add tests if behaviour coverage is missing | only if behaviour or performance is visible to operators |
   | `test`, `docs`, `chore`, `ci` | none beyond keeping the suite green | no |
   "Touches I/O" means database, queue, cache, external HTTP API, file storage or an entry point (handler, command, endpoint).
3. **Write the tests** where the project standard says each kind goes, following the existing style of neighbouring tests (fixtures, naming, mocks). Unit tests mock every external dependency. Integration tests exercise the real boundary the project standard defines.
4. **Run** the `verified` commands from the project standard: unit tests, then lint, then integration if its prerequisites are available. If an integration command is `unverified` (needs DB, credentials), say so in the report instead of skipping silently.
5. **Update `CHANGELOG.md`** under `## [Unreleased]`, in the right section, one line per user-visible change, with the ticket. Write for the person operating the service, not a copy of the diff. Format in `references/baseline.md`.
6. **Write the commit message** with the exact format in `references/baseline.md`. One logical change per commit; a ticket may span several commits. Do not commit unless the user asked you to; if not, propose the message.
7. **Check**: run `.ai/skills/change-standards/scripts/check_change.sh <commit-before-your-change>` (it runs the message, CHANGELOG and test-file checks, the unit command and the lint command). Fix what it reports. It does not run integration tests; run those yourself in step 4.
8. **Report** to the user:
   ```
   Change standard
   - Commit:      OK | proposed | FAIL (<reason>)
   - CHANGELOG:   OK | n/a (<type>) | FAIL
   - Unit tests:  OK (<n> added, <command>) | FAIL
   - Integration: OK | n/a | not run (<missing prerequisite>)
   - Lint:        OK | FAIL
   - Gaps:        <open gaps from the project standard, if any>
   ```

## Keeping the project standard correct

The project standard is a living file. If during Apply a `verified` command no longer works, or the project adopted a new tool, fix the project standard, mark what you re-verified, and add a line to its `## Standard history`. You may tighten it; you may never weaken a baseline rule. Mention the update in your report so it gets reviewed in the PR.

## Hooks

The installer sets `core.hooksPath=.githooks`. That setting is local to each clone, so at the start of every Apply check `git config core.hooksPath`; if it is not `.githooks` and the folder exists, run `git config core.hooksPath .githooks` and mention it in the report. `commit-msg` rejects messages that break the format; `pre-push` runs `check_change.sh`. If a hook rejects your commit, fix the cause. Never use `--no-verify` unless the user explicitly asks.
