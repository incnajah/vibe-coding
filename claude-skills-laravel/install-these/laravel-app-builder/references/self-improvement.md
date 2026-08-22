# Learning From Failures

A skill that never changes repeats the same wrong assumption on every project. A skill that rewrites itself unattended accumulates noise until its guidance is worse than none. This file describes the middle path: **record automatically, promote deliberately.**

Two storage locations, two very different permission levels:

| Where | Scope | Written | Reviewed |
|---|---|---|---|
| `docs/lessons.md` (in the project) | this project only | automatically, during the build | no |
| `references/learned.md` (in the skill) | every future project | only by `learn.sh --apply` | **yes, by the user** |

Writing to the skill directory changes behaviour for every project you will ever build. That is not a step to take silently, and no amount of confidence about a lesson justifies skipping the review.

## What counts as a lesson

Record when the loop **was wrong about something it believed**, not merely when something failed.

Worth recording:

- An API that was called because it looked plausible and does not exist in the installed version
- A fix that only worked on the third attempt, where the first two came from the same wrong diagnosis
- A verify failure whose real cause was somewhere other than where the error pointed
- A user correction at the ERD gate that reveals a domain assumption the inference rules got wrong
- A generated pattern the user rejected the same way twice

Not worth recording:

- A typo, a missing import, anything fixed on the first attempt
- Anything specific to one project's domain (`umroh packages need a muthowif` is not a lesson, it is a requirement)
- A transient environment failure — a network timeout, a locked file, a port already bound
- "Remember to run the tests." Guidance already in the skill does not need re-learning; if it was skipped, the problem is compliance, not knowledge

The test: **would this have helped on a different project, in a different domain?** If no, it belongs in the project's `docs/decisions.md`, not here.

## Recording during the build

Append to `docs/lessons.md` as it happens — at the moment the fix lands, while the error text is still in context. Reconstructing it later produces a vague summary of a specific problem, which is the least useful form.

```markdown
## 2026-08-23 — Filament v4 Schema API

**Believed:** `Forms\Components\TextInput` still lives under `Filament\Forms`.
**Actually:** v4 unified forms and infolists into `Filament\Schemas`; the v3 namespace
resolves but the component is rejected by the new schema builder.
**Cost:** 3 verify cycles, error pointed at the resource, not the import.
**Generalises:** yes — any v3 snippet for forms or infolists.
**Signal:** confirm the namespace against Boost docs search before the first resource,
not after the first failure.
```

Five fields. `Believed` and `Actually` are the pair that makes the entry useful — an entry that only records the fix teaches nothing about the reasoning that produced the bug.

## Promotion

At handover, or when `docs/lessons.md` passes about ten entries:

```bash
bash "$SKILL_DIR/scripts/learn.sh"            # dry run — prints what would change
bash "$SKILL_DIR/scripts/learn.sh" --apply    # writes, after the user has seen the diff
```

A lesson is promoted only if **all** of these hold:

1. **Generalises.** Not domain-specific, not project-specific.
2. **Recurred, or was expensive.** Seen in two separate projects, or cost three or more fix cycles in one.
3. **Not already covered.** If the existing references say it and it was missed anyway, promoting a second copy fixes nothing.
4. **Not version noise.** "Filament v4 moved X" is durable. "This exact patch release has a bug" is not — that expires, and expired guidance is worse than absent guidance because it is trusted.

Everything else stays in the project. Most lessons should stay in the project.

## Keeping it from rotting

`references/learned.md` is loaded into context alongside everything else, so it competes with the guidance that is already known to be good. Left ungoverned it grows until it crowds out the skill.

- **Cap it.** Around forty entries. Past that, promoting a new lesson means retiring a weak one, not appending.
- **Date and tag every entry** with the versions it applies to. `learn.sh` flags entries whose versions no longer match the installed stack.
- **Retire, do not accumulate.** A lesson contradicted by a newer framework version gets deleted, not annotated. Two entries disagreeing about the same API is worse than neither.
- **Promote into the right file.** A durable architectural rule belongs in `architecture.md` or `filament.md`, where it sits with related guidance. `learned.md` is a staging area, not the permanent home for everything.

## What this mechanism cannot do

It cannot make the skill notice a failure it did not recognise as one. If a build produces subtly wrong behaviour that passes every check, nothing here catches it — the loop believed it succeeded, so there is no lesson to record. That gap closes with better verification (a real browser journey, a reviewer that reads the diff cold), not with better learning.

It also cannot substitute for the user saying "you keep doing X and I keep fixing it." That sentence is the highest-quality lesson available, and it only arrives if the handover report is honest enough that the user bothers to give it.
