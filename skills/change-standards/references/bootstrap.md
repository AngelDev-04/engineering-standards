# Bootstrap: generate the project standard

Goal: produce `.ai/change-standard.md` whose commands have actually been run in this repository. A standard with guessed commands is worse than none, because hooks and reviewers will trust it.

## 1. Collect evidence

Run `.ai/skills/change-standards/scripts/detect_project.sh`. It prints facts with `file:line` references: stack markers, test runner config, test layout with file counts, commands found in pipeline/Makefile/scripts, commands in README/CLAUDE.md, lint config, changelog, pipeline steps. It draws no conclusions.

Then open the files it cites when the evidence is ambiguous (a `run_test.sh`, a `conftest.py`, a README section). Read; do not explore the whole codebase.

## 2. Propose candidates

For each slot decide a candidate command and the evidence for it:

- `unit`: fast tests with no external services.
- `integration`: tests that hit a real boundary. Look for fixtures that connect to DB/queues, flags like `--clean-db`, docker compose services, markers.
- `lint`: prefer the exact command the pipeline runs.
- `format` (optional): only if the project already uses a formatter.

Prefer, in order: what the pipeline runs > scripts the team uses > documented commands > tool defaults. Respect the project's environment manager (`uv run`, `poetry run`, `npm run`, a virtualenv in `venv/`).

Also decide: where unit and integration tests live (paths and file naming), the CHANGELOG path, and the gaps against `baseline.md`.

## 3. Verify (iterate, at most 3 attempts per command)

Run each candidate. Use a timeout (e.g. 300 s) and do not install global packages.

- Passes, or fails only because of genuine test failures → `verified`. Record pre-existing failing tests as a gap; do not fix unrelated tests.
- Fails because the command is wrong (wrong path, missing marker, wrong runner, missing env manager) → fix the candidate and retry.
- Fails because a prerequisite is missing (database, credentials, a product/tenant argument, network) → stop retrying and mark `unverified: <prerequisite>`. Never invent credentials or edit `.env`.
- No tests exist for a slot → mark `missing`, but still write the command the slot will use (e.g. `pytest tests/unit`, following the runner config) with status `missing`, so the first change that adds tests can run and verify it. Update the status to `verified` in that change and add a line to `Standard history`.

## 4. Write the files

1. `.ai/change-standard.md` using `references/project-standard.template.md`. Every command has a status and the evidence that justified it.
2. `CHANGELOG.md`: create it if missing (header + empty `[Unreleased]`, see `baseline.md`). Do not touch existing entries.
3. Agent pointers: ensure `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` and `.kiro/steering/change-standards.md` each contain the pointer block below. Create the files if missing; append if they exist; do not duplicate.

```markdown
<!-- change-standards:begin -->
## Change standards
Every code change follows the `change-standards` skill: commit format, CHANGELOG entry and tests.
Project commands and test locations: `.ai/change-standard.md`. Company rules: the skill's `references/baseline.md`.
<!-- change-standards:end -->
```

## 5. Limits

- Do not modify application code, tests, the pipeline or dependencies during bootstrap. Gaps are recorded, not fixed.
- Do not commit unless the user asked you to. If you do, commit the bootstrap alone as `chore: bootstrap change standard`, before any task change.
- Finish with a short report: commands and their status, gaps, files created or changed.
