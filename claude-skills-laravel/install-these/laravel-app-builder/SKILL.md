---
name: laravel-app-builder
description: Autonomously build a complete, working Laravel application — Filament admin panel plus Inertia + React (shadcn/ui) frontend — from a plain-language description of features. Use this skill whenever the user describes an app or website they want built and mentions Laravel, Filament, Inertia, React, or asks for a web app with an admin panel, even if they only give a rough feature list. It handles requirements analysis, ERD design, migrations, models, Actions, admin resources, frontend pages, tests, and an automated build-verify-fix loop that runs until the app actually works. Also use it when the user asks to add a major feature to an existing Laravel + Filament project, or says things like "buatkan aplikasi", "build me an app", "bikin website dengan fitur X".
---

# Laravel App Builder

Turn a feature description into a running application, with as few round trips to the user as possible.

The philosophy: **do not ask the user questions they cannot answer better than you can decide.** Most people describing an app know the features, not the schema. Design the schema yourself, show it once, then build. Every question asked is a round trip that could have been an inference.

## Environment check — read this first

This skill needs a real filesystem, a terminal, and the ability to run long loops. That means **Claude Code or Cowork**.

If running in the claude.ai chat interface, say so immediately and honestly:

> This needs a terminal and a persistent project directory to actually build and verify the app. In chat I can produce the full plan, ERD, and code files, but I can't run migrations, execute tests, or run the fix loop. To get the one-prompt build, run this in Claude Code inside an empty project directory.

Then offer the plan + ERD + generated files as the useful fallback. Do not pretend to run a build loop that is not running.

## Phase 0 — Setup (automated)

**Script paths.** The scripts live inside this skill's directory, not in the user's project. The working directory during a build is the *project*, so `bash scripts/bootstrap.sh` will not resolve. Resolve the skill directory once and use it for every script call:

```bash
SKILL_DIR=~/.claude/skills/laravel-app-builder   # or the project-local .claude/skills/... path
bash "$SKILL_DIR/scripts/bootstrap.sh" <project-name>
```

If that path does not exist, locate the skill before continuing rather than guessing:

```bash
ls -d ~/.claude/skills/laravel-app-builder .claude/skills/laravel-app-builder 2>/dev/null
```

`bootstrap.sh` cannot change the caller's working directory. Its last line is `PROJECT_ROOT=<path>` — **`cd` there before anything else.** Every later command, including `verify.sh`, runs from the project root.

It performs, idempotently:
- `composer create-project laravel/laravel` (or detects an existing project and skips)
- SQLite configured and the database file created, so the loop never blocks on DB credentials
- Filament panel; `spatie/laravel-medialibrary` with its migrations published; `tightenco/ziggy` for the `route()` helper the frontend uses
- Inertia wired end to end: `HandleInertiaRequests` generated *and registered in `bootstrap/app.php`*, `resources/views/app.blade.php`, `resources/js/app.tsx`, `vite.config.js` with the React and Tailwind v4 plugins, `resources/css/app.css`, `tsconfig.json`
- `laravel/boost` (dev) — this is the important one
- `pestphp/pest` **plus `pest --init`** so `vendor/bin/pest` actually runs, `larastan/larastan` with a `phpstan.neon`, `barryvdh/laravel-debugbar`
- `git init` and one initial commit, so the per-slice commits in Phase 3 have somewhere to land
- MCP registration for Claude Code

It deliberately does **not** run `npx shadcn@latest init` — that prompt is interactive and would hang an autonomous run. The script prints the command; run it once at the start of Phase 3, before generating any component.

**About MCP servers.** A skill cannot silently install MCP servers into a user's account — MCP registration is a change to their machine or their Claude configuration, so it goes through an explicit command. What the script does is run those commands for them, and report what it registered:

| Server | Why it is needed | Registration |
|---|---|---|
| `laravel-boost` | The single highest-value one. Gives live access to the app's schema, models, routes, config, artisan, tinker, browser logs, and a semantic search over Laravel ecosystem docs. Without it, code is written blind against assumed APIs. | Auto-registered by `php artisan boost:install`; fallback `claude mcp add -s local -t stdio laravel-boost php artisan boost:mcp` |
| `playwright` | Closes the verification loop. Lets the build loop actually open pages, click through flows, and read console errors instead of assuming the UI works. | `claude mcp add playwright npx @playwright/mcp@latest` |

If a registration command fails (no `claude` CLI, sandboxed environment, Windows npx quirks), continue the build without it and tell the user which capability is degraded. Losing Playwright means the loop verifies via tests only, not the real browser. Losing Boost means API details must be verified from docs instead of the live app — slower and more error-prone, but not fatal.

**About "auto-installing other skills."** Skills do not install other skills. This one is self-contained: everything it needs lives in `references/`. Separately, `boost:install` publishes its own Laravel ecosystem guidelines and skills into the project — that is the real mechanism, and the bootstrap script uses it.

## Phase 1 — Requirements to specification (no questions yet)

Read `references/requirements-to-erd.md` before this phase.

From the user's description, produce and write to `docs/`:

1. `docs/spec.md` — actors and roles, entity list, feature list broken into vertical slices, explicit out-of-scope list.
2. `docs/erd.md` — Mermaid ER diagram with every table, column, type, nullability, and relationship.
3. `docs/plan.md` — ordered build slices, each with its acceptance criteria.

Infer aggressively. If the user says "travel umroh with packages, hotels, and WhatsApp booking," you already know there is a `packages` table, a `hotels` table, a pivot or itinerary relation, media for galleries, and no payment system unless stated. Do not ask about soft deletes, timestamps, slug fields, or seeders — decide them.

**Ask only about things that are genuinely unrecoverable later**, and ask them all at once, maximum three:
- Money and multi-currency (retrofitting is expensive)
- Multi-tenancy (retrofitting is very expensive)
- Authentication for end users: does the public side need accounts at all?

If the user's description already answers one, do not ask it.

## Phase 2 — The single gate

Show the ERD and the slice plan. Ask one question:

> Ini rencananya. Ada yang salah atau kurang sebelum aku bangun?

This gate exists because a wrong ERD costs hours of rework, while reviewing one costs two minutes. It is the only mandatory stop.

If the user has said "langsung saja", "jangan tanya-tanya", "one shot", or similar, skip the gate — write the ERD to disk, state that you are proceeding on it, and build. Their instruction to skip review is theirs to make.

## Phase 3 — Build loop

Read `references/autonomy-loop.md` for the full loop mechanics, and `references/architecture.md` for the layering rules that are non-negotiable during generation.

Before the first component, initialise shadcn/ui once (bootstrap skips it because its prompt is interactive):

```bash
npx shadcn@latest init
npx shadcn@latest add button card dialog form input select
```

Build **slice by slice**, not layer by layer. A slice is one feature complete from database to UI. Finishing slices means the app is always in a demonstrable state; finishing layers means nothing works until the end.

Per slice:

1. Migration + model + factory + seeder
2. Action classes with business logic
3. Pest tests against the Actions — **write these before the UI**
4. Filament resource
5. Inertia controller + React page
6. `bash "$SKILL_DIR/scripts/verify.sh"` — from the project root
7. If verify fails: read the actual error output, fix, re-run. Do not proceed to the next slice with a red build.

Loop budget: up to **6 fix attempts per slice**. On the 6th consecutive failure, stop and report — the error text, what was tried, and what is suspected. Silently looping on an unsolvable problem burns the user's tokens and time. A stuck loop is information, not a failure to hide.

Between slices, commit: `git add -A && git commit -m "feat: <slice>"`. Frequent commits give the user a rollback point, which is what makes autonomous building safe to allow.

## Phase 4 — Integration verification

After the last slice:

```bash
bash "$SKILL_DIR/scripts/verify.sh" --full
```

Then, if Playwright is available, walk the primary user journey in a real browser: load the homepage, navigate to a detail page, submit the main form, log into `/admin`, create a record, confirm it appears on the frontend. Read the browser console. Console errors that no test catches are exactly what this step is for.

Seed demo data so the app is not an empty shell when the user opens it.

## Phase 5 — Handover

Write `README.md` with setup steps, admin credentials, and the seeded demo accounts. Then report to the user:

- What was built, by slice
- What was deliberately left out and why
- Anything that failed verification and remains broken — state this first and plainly, never bury it
- The next three things worth doing

**Never report an app as complete when the verify script is red.** An honest "8 of 10 slices work, checkout is failing on X" is far more useful than a green summary the user discovers is false when they open the browser.

## Constraints that survive autonomy

Autonomous does not mean unconstrained. These hold regardless of what the loop is doing:

- **No destructive commands without asking**: no `migrate:fresh` on a database with real data, no `rm -rf`, no force-push, no writing outside the project directory.
- **No secrets in code or commits.** Generate `.env.example`; never commit `.env`.
- **No fabricated APIs.** If unsure whether a Filament or Inertia method exists in the installed version, check via Boost's docs search or the real docs. Inventing a plausible-looking method call is the most common way an autonomous build produces code that looks right and does not run.
- **No scope creep.** Build what is in `docs/spec.md`. If a good idea surfaces mid-build, append it to `docs/backlog.md` and keep going.

## Reference files

| File | Read when |
|---|---|
| `references/requirements-to-erd.md` | Phase 1 — turning prose into schema |
| `references/architecture.md` | Before generating any code — the layering contract |
| `references/filament.md` | Building admin resources |
| `references/inertia-react.md` | Building frontend pages |
| `references/autonomy-loop.md` | Phase 3 — loop mechanics, failure handling, stop conditions |

## Communication

Respond in the language the user writes in. During long autonomous stretches, emit short progress lines per slice rather than narrating every file write — enough for the user to follow, not so much that the signal drowns.
