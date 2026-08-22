# Orchestration — Running the Build as a Team

A single agent building twelve slices in sequence is a competent solo developer. What this file describes is a delivery team: a lead that owns the plan, builders that work in parallel where the plan allows, reviewers that never see the builder's reasoning, and a QA pass that only trusts what it ran.

The point is not speed. It is that **independent verification catches what self-verification cannot.** A builder that reviews its own slice is checking the code against the same assumptions that produced it.

## Roles

| Role | Who | Owns |
|---|---|---|
| **Lead** | the main session — never delegated | spec, ERD, wave plan, integration, all conversation with the user |
| **Builder** | one subagent per slice | one slice, database to UI, in its own worktree |
| **Reviewer** | one subagent per completed slice | the diff, read cold — no access to the builder's reasoning |
| **QA** | one subagent per wave | `verify.sh --full`, browser journey, console errors |

The lead never delegates the ERD. Schema is the one artifact where a wrong decision propagates into every slice at once, and it is the one thing the user was asked to review.

## Wave planning

Parallelism is only safe between slices that cannot touch the same files. Before fanning out, build the dependency graph from `docs/plan.md`.

Two slices **conflict** if they share any of:

- a database table (including a pivot) — two migrations against one table is a merge conflict and a schema race
- a route file section or a shared layout
- a frontend primitive or pattern component
- an Action class or a model

Two slices are **independent** if they touch disjoint tables and disjoint components. That is rarer than it looks; check honestly rather than optimistically.

```
Wave 0  (serial, always)   auth + admin panel shell, design tokens, primitives
Wave 1  (serial)           the core entity, end to end — proves the vertical works
Wave 2  (parallel)         reference entities that hang off the core independently
Wave 3  (parallel)         remaining public pages
Wave 4  (serial)           cross-cutting: search, SEO, sitemap, 404
```

Wave 0 is serial and non-negotiable. If three builders each invent a `Button`, the result is exactly the drift `ui-design-system` exists to prevent — and it arrives before there is any system to retrofit onto. Primitives are built once, by one agent, before any fan-out.

Wave 1 is serial too. The first vertical slice is where the stack's real API surface gets discovered. Discovering it three times in parallel means three agents make the same wrong assumption independently.

## Isolation

Parallel builders writing into one working tree corrupt each other. Give each builder its own git worktree:

```
Agent(subagent_type: "laravel-slice-builder", isolation: "worktree", prompt: …)
```

Worktrees cost real setup time and disk, so use them only for the fan-out waves — a serial slice does not need one.

**Migration timestamps collide.** Two worktrees created in the same minute produce two migrations with adjacent timestamps and no shared ordering. Assign each builder an explicit ordering offset in its prompt, or have the lead rename migrations at integration time. Do not leave this to chance; a wrong migration order fails only on a fresh database, which is the machine you do not have in front of you.

## What each agent gets told

A builder prompt is not "build slice 3." It carries everything the agent cannot see:

- the slice's acceptance criterion, verbatim from `docs/plan.md`
- the tables it owns and — explicitly — **the tables it must not touch**
- the primitives that already exist, so it composes instead of inventing
- the architecture contract: Actions hold the logic, Filament resources and controllers are thin callers
- the instruction to run `verify.sh` before returning, and to return its output

A builder that returns "done" without having run the gate has returned nothing verifiable.

## Review is adversarial, and blind

The reviewer subagent gets the diff and the acceptance criterion. It does **not** get the builder's explanation of what it did. This is deliberate: a rationale is a frame, and a reviewer given the frame checks whether the code matches the story rather than whether the story was right.

Ask the reviewer to look for the specific failures this stack produces:

- business logic inside a Filament resource or an Inertia controller
- an Eloquent model passed straight through as an Inertia prop
- a method called on Filament or Inertia that does not exist in the installed version
- an N+1: a relationship touched inside a map or a `getStateUsing` closure
- a test that asserts nothing, or was weakened to pass
- a missing `focus-visible`, empty state, or error state

A reviewer that returns "looks good" on a real diff has almost certainly not read it. Require it to cite file and line for every finding, and to state explicitly when it found nothing after checking each item on the list.

## Integration

The lead merges, never the builders. Per wave:

1. Merge each worktree branch in wave order, not completion order — deterministic conflicts are easier to reason about than racy ones
2. Renumber migrations if timestamps interleaved wrongly
3. Run `bash "$SKILL_DIR/scripts/verify.sh" --full` on the merged tree
4. Run `bash "$SKILL_DIR/scripts/audit-ui.sh"` — fan-out is where duplicate components appear
5. Only then start the next wave

A green build in each worktree says nothing about the merged tree. The merged run is the only one that counts.

## When not to do any of this

Fan-out has real costs: N builders burn roughly N times the tokens, merges take time, and every parallel boundary is a place for two agents to solve the same problem differently. Stay serial when:

- fewer than three genuinely independent slices exist — coordination costs more than it saves
- the schema is still moving; parallel work against a shifting ERD is rework in advance
- the user is actively steering and wants to see each step
- the project is small enough that the whole build fits in one context

Serial is the default. Fan out when the plan shows a wave that is actually wide, and say so before doing it — the user is paying for those agents.

## Reporting

Parallel work produces confusing logs unless the lead imposes order. One line per slice, grouped by wave, emitted as results arrive:

```
Wave 2 (3 builders)
  ✓ Hotels        — 6 tests, verify green, review: 1 finding fixed (N+1 in table query)
  ✓ Destinations  — 4 tests, verify green, review: clean
  ✗ Muthowifs     — verify red: migration order, integrating manually
```

Never report a wave as complete while any slice in it is red. The whole reason to run a review and QA pass is to have something trustworthy to report; burying a failure in a parallel run throws that away.
