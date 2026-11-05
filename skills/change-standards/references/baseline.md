# Company baseline

These rules are the same in every repository. Project standards decide *how* to meet them, never *whether*.

## Commit message

```
<type>(<TICKET>): <subject>

Why: <the problem or motivation and its impact>
What: <the technical decision; discarded alternatives if relevant>
Risk: <migrations, new env vars, compatibility, rollout notes, or "none">
Tests: <tests added or changed and how the change was validated>
```

- `type`: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `ci`, `revert`.
- `TICKET`: the issue key in upper case, e.g. `ABC-123`. Required for `feat`, `fix`, `refactor`, `perf`, `revert`. Optional for `test`, `docs`, `chore`, `ci`: then use `<type>: <subject>`. A repository with no issue tracker writes the literal `NO-TICKET` scope (`feat(NO-TICKET): ...`); the body is still required.
- `subject`: imperative mood ("add", "fix", not "added", "fixes"), lower case first word, no trailing period, header at most 72 characters.
- Body: required for `feat`, `fix`, `refactor`, `perf`, `revert`, with the four labels above in that order. Wrap at 72 characters. Explain why; the diff already shows what changed line by line.
- Breaking change: add `!` after the scope (`feat(ABC-123)!: ...`) and a `BREAKING CHANGE: <what callers must do>` line at the end.
- One logical change per commit; a ticket may span several commits. Unrelated cleanups go in their own commit.
- Trailers such as `Co-Authored-By:` go after the body, separated by a blank line.

Good:
```
fix(ABC-123): use the active invoice when reprocessing a payment

Why: reprocessing a payment with a cancelled invoice reused its number,
so the new invoice was rejected as a duplicate.
What: the lookup now prefers the active invoice and only falls back to
a cancelled one when the payment has no active invoice.
Risk: none; behaviour for payments with a single invoice is unchanged.
Tests: added unit test for the fallback order; existing suite green.
```

Bad: `ABC-123`, `fix stuff`, `ABC-123 Added methods`, `feat: Update file.py.`

## CHANGELOG

`CHANGELOG.md` at the repository root (for a monorepo, one per deployable service, as the project standard says), in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format:

```markdown
# Changelog

All notable changes to this service are documented here.

## [Unreleased]

### Added
- CSV export of monthly orders report (ABC-120).

### Fixed
- Reprocessing a payment no longer reuses a cancelled invoice number (ABC-123).

## [1.4.0] - 2026-10-01
...
```

- Sections, in this order, only when used: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.
- One line per change, past-tense outcome for the operator, ending with the ticket in parentheses.
- Mention operational impact explicitly: new env vars, migrations, changed queues or endpoints.
- New entries go under `[Unreleased]`. Releasing (moving them under a version and date) is part of the release process, not of every change.
- If the file does not exist, create it with the header above and an empty `[Unreleased]`. Do not reconstruct past history.

## Tests

- Unit tests: fast, deterministic, no network, no real database. Mock external dependencies.
- Integration tests: exercise a real boundary (database, queue, HTTP client against a fake server or container, the service's entry point). They may need prerequisites; the project standard lists them.
- Every `fix` adds a test that fails without the fix.
- Every `feat` adds unit tests, and an integration test when it touches I/O.
- A missing harness is not a reason to skip an integration test. Build the smallest real boundary that fits: a local fake HTTP server, SQLite or a temp directory, a container already used by the project. Only prerequisites you cannot create locally (shared databases, credentials) justify `not run`, and the report must say which.
- Tests live in the locations the project standard defines and follow the existing conventions of the repository. For Python, if unit and integration tests can share a file name (`tests/unit/test_client.py` and `tests/integration/test_client.py`), the test folders need `__init__.py` or pytest aborts on the duplicate module name.
- The pipeline must run unit and integration tests. If it does not yet, the project standard records it as a gap; do not change the pipeline unless asked.
