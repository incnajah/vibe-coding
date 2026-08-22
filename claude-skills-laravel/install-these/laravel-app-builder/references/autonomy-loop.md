# The Build Loop

What makes autonomous building work is not persistence. It is having a **real signal for "done"** and an honest stop condition for "stuck."

## Per-slice loop

```
for each slice in docs/plan.md:
    implement (migration → model → Action → tests → Filament → Inertia)
    attempt = 0
    while attempt < 6:
        run: bash scripts/verify.sh
        if pass: commit; break
        read the FIRST failure only
        diagnose and fix
        attempt++
    if attempt == 6:
        STOP. Report to the user. Do not continue to the next slice.
```

## Fix the first failure only

Verification failures cascade. A migration error produces route errors produces test errors produces build errors. Reading all four and "fixing" all four means three speculative changes to code that was never broken.

Read the first failure. Fix that. Re-run. The other three often disappear.

## Diagnose from output, never from assumption

The strongest temptation in an autonomous loop is to guess a fix and re-run, hoping. That converts a five-minute debug into forty minutes of thrash.

When something fails, get the actual error before editing anything:

```bash
tail -50 storage/logs/laravel.log
php artisan tinker --execute="dd(App\Models\Package::first())"
vendor/bin/pest --filter=PackageTest -v
```

With `laravel-boost` available, use its tools — live schema, model list, routes, tinker, browser logs — instead of inferring the app's state from source files. The gap between what the code says and what the running app does is where these bugs live.

Two consecutive failures with the same error mean the diagnosis is wrong, not that the fix needs another variation. Change what is being investigated, not the patch.

## Stop conditions — report, do not push through

Stop and surface the problem when:

- 6 consecutive verify failures on one slice
- The same error text appears 3 times despite different fixes
- A fix would require deleting a passing test, weakening an assertion, or removing a feature from the spec
- The fix requires a credential, external API key, or paid service the user has not provided
- The slice needs a decision the ERD does not settle and guessing wrong would be expensive

Report format:

```
STUCK: <slice name>, attempt 6

Error:
<exact error text>

Tried:
1. <what> → <result>
2. <what> → <result>

Suspected cause: <hypothesis>
Need from you: <specific thing>

Slices 1-4 are complete and passing. This does not block them.
```

Never make a test pass by weakening it. A green suite that asserts nothing is worse than a red one, because it removes the only signal the loop has.

## Commit rhythm

```bash
git add -A && git commit -m "feat(packages): admin CRUD + public listing"
```

One commit per passing slice. This is what makes autonomous building safe to permit — the user can inspect or revert any slice without unpicking a single enormous diff.

## Browser verification

Tests confirm the server. They say nothing about whether the page renders. With `playwright` registered, after each frontend slice:

1. Navigate to the page
2. Read the console — any error is a failure, including React key warnings and 404s on assets
3. Exercise the main interaction (submit the form, apply the filter)
4. Check the 375px viewport

Without Playwright, `curl` the route and confirm the JSON in its `data-page="app"` script tag carries the props the page needs. Weaker than a browser — it proves the server answered, not that React rendered — so say which one you actually did.

## Context management on long builds

A full build will exceed a single context window. Keep durable state on disk, not in the conversation:

- `docs/plan.md` — mark slices `[x]` as they pass
- `docs/decisions.md` — one line per non-obvious choice and its reason
- `docs/backlog.md` — good ideas that surfaced mid-build and were deliberately deferred
- git log — the actual record of what shipped

When context is running low, write current state to `docs/plan.md` before continuing. A resumed session should be able to read those three files plus the git log and know exactly where it is.

## Progress reporting

One line per slice, not a narration of every file write:

```
✓ Slice 3/8 — Packages: migration, model, 4 Actions, 11 tests, Filament resource, /paket + detail page
▸ Slice 4/8 — Hotels & destinations
```

The user should be able to follow along without reading everything. Volume of output is not evidence of progress.

## What "done" means

Done is not "all slices implemented." Done is:

- `bash scripts/verify.sh --full` exits 0
- Demo data seeded so the app is not an empty shell
- The primary user journey walked end to end in a browser
- `README.md` written with setup steps and credentials
- Known gaps listed explicitly in the handover

If any of those is missing, say which one. Reporting an app as complete when verify is red is the single worst failure mode available to an autonomous builder — it destroys the user's ability to trust any future report.
