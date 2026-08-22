---
name: ui-design-system
description: Build and enforce a component-based design system so UI stays consistent as an app grows — design tokens, a tiered component architecture (primitives → patterns → features), state coverage, and an automated drift audit. Use this skill whenever building or refactoring UI in React, Tailwind, or shadcn/ui, when the user mentions atomic design, design systems, component libraries, style guides, UI consistency, or says their UI looks messy, inconsistent, or "different on every page". Also use it when building an app that has both a Filament admin panel and a React frontend, since keeping those two visually coherent is a specific problem this skill solves.
---

# UI Design System

Consistency in a UI is not produced by having components. It is produced by **making inconsistency hard to express.** A codebase with fifty components and no constraints drifts exactly as fast as one with none — it just drifts in more places.

This skill is about the system: tokens, tiers, states, enforcement. It is not about taste. For aesthetic direction — palette personality, typographic voice, what makes a page memorable rather than templated — use a design skill such as `frontend-design` if one is installed in the current environment; otherwise settle the visual direction with the user first. The two concerns compose: the aesthetic decision says what the product should look like, this skill makes that decision hold across two hundred files.

## Read this before implementing atomic design as specified

Brad Frost's five tiers (atoms → molecules → organisms → templates → pages) are useful as an idea and expensive as a taxonomy. The predictable failure: teams spend real time arguing whether a search field with a button is a molecule or an organism, the boundary stays contested, files get filed inconsistently, and the classification delivers zero user-visible value. The part that actually produces consistency is composition from a constrained primitive set — not the five-way split.

Use four tiers instead. They map cleanly onto how React and shadcn/ui actually work, and each boundary has an unambiguous test:

| Tier | Test | Example |
|---|---|---|
| **Tokens** | Not a component. A value. | `--color-primary`, `--space-4`, `--radius-md` |
| **Primitives** | Zero business knowledge. Reusable in any app. | `Button`, `Input`, `Card`, `Badge` |
| **Patterns** | Composes primitives. Still no domain knowledge. | `FormField`, `DataTable`, `EmptyState`, `PageHeader` |
| **Features** | Knows the domain. Not reusable elsewhere. | `PackageCard`, `DepartureSelector`, `BookingForm` |

"Does this know what a Package is?" separates features from everything above it. "Could I paste this into an unrelated project?" separates primitives and patterns. Both questions have one right answer, which is exactly what the atoms/molecules boundary lacks.

If the user explicitly wants the five-tier naming, use it — but say once, briefly, that the atom/molecule line tends to cost more than it returns.

## Step 1 — Tokens first, always

This is the actual mechanism. Everything else is downstream.

Read `references/tokens.md` before writing any token file.

The rule: **every visual value in the app resolves to a token.** No arbitrary Tailwind values (`p-[13px]`, `text-[#3b82f6]`), no raw hex in components, no inline style colors. Not as a style preference — as the thing that makes drift impossible rather than merely discouraged.

Tailwind v4 defines them in CSS:

```css
@import "tailwindcss";

@theme {
  /* Semantic color roles, not literal names.
     --color-blue-500 tells you nothing about where to use it. */
  --color-surface:        oklch(1 0 0);
  --color-surface-muted:  oklch(0.97 0.005 260);
  --color-border:         oklch(0.92 0.006 260);
  --color-content:        oklch(0.22 0.01 260);
  --color-content-muted:  oklch(0.55 0.015 260);
  --color-primary:        oklch(0.55 0.18 255);
  --color-primary-fg:     oklch(0.99 0 0);
  --color-danger:         oklch(0.58 0.20 25);

  /* Constrained scales. Six steps, not thirty-two.
     A scale wide enough to express anything expresses nothing. */
  --spacing-1: 0.25rem;
  --spacing-2: 0.5rem;
  --spacing-3: 0.75rem;
  --spacing-4: 1rem;
  --spacing-6: 1.5rem;
  --spacing-8: 2rem;
  --spacing-12: 3rem;

  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;

  --text-xs: 0.75rem;
  --text-sm: 0.875rem;
  --text-base: 1rem;
  --text-lg: 1.125rem;
  --text-xl: 1.5rem;
  --text-2xl: 2rem;
}
```

Semantic names over literal ones. `--color-danger` survives a rebrand; `--color-red-500` becomes a lie the moment the brand shifts, and nobody renames it.

## Step 2 — Primitives with variants, not prop soup

One component per role. Variants through `cva`, never through booleans that combine into nonsense.

```tsx
const button = cva(
  "inline-flex items-center justify-center gap-2 rounded-md font-medium " +
  "transition-colors focus-visible:outline-none focus-visible:ring-2 " +
  "focus-visible:ring-primary focus-visible:ring-offset-2 " +
  "disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        primary:   "bg-primary text-primary-fg hover:bg-primary/90",
        secondary: "bg-surface-muted text-content hover:bg-border",
        ghost:     "text-content hover:bg-surface-muted",
        danger:    "bg-danger text-primary-fg hover:bg-danger/90",
      },
      size: { sm: "h-8 px-3 text-sm", md: "h-10 px-4", lg: "h-12 px-6 text-lg" },
    },
    defaultVariants: { variant: "primary", size: "md" },
  }
)
```

`<Button primary large outlined danger>` is four booleans producing sixteen combinations, most meaningless. `variant` and `size` produce twelve valid ones and no invalid ones.

**Two components with the same job is the failure mode to watch for.** `Button` plus `SubmitButton` plus `ActionButton` means three places to fix a focus ring. If a variant would cover it, it is a variant. The audit script flags this.

Read `references/component-tiers.md` for the full tier rules and file layout.

## Step 3 — States are not optional

The most common source of a UI that "feels unfinished" is not layout. It is that only the happy path was built.

Every interactive component ships with: default, hover, focus-visible, active, disabled, and where relevant loading and error. Every data view ships with: loading, empty, error, and populated.

Empty and error states are design work, not fallbacks. An empty screen is an invitation to act; a vague error is a dead end. Read `references/accessibility-and-states.md`.

## Step 4 — Admin and frontend must share tokens

In a Laravel app with a Filament panel and a React frontend, the two will look like two different products unless tokens are shared deliberately. Filament compiles its own assets with its own theme; React compiles its own. They cannot share a stylesheet, but they can share the same token values.

Read `references/filament-parity.md`. This matters more than it sounds: the admin is what the client sees every day, and a panel that looks unrelated to their own site reads as unfinished work regardless of how good the public pages are.

## Step 5 — Enforce, or it decays

A design system without enforcement lasts about three weeks. The decay is always the same: one deadline, one `p-[13px]`, and the constraint is gone because it was never a constraint, only an intention.

The script lives in this skill's directory, not in the project, so resolve that path rather than assuming a relative one:

```bash
SKILL_DIR=~/.claude/skills/ui-design-system   # or the project-local .claude/skills/... path
bash "$SKILL_DIR/scripts/audit-ui.sh"                              # defaults: resources/js resources/css
bash "$SKILL_DIR/scripts/audit-ui.sh" src/components src/styles    # or pass both explicitly
```

It reports arbitrary Tailwind values, raw hex outside the token file, inline style colors, hardcoded px font sizes, interactive elements missing focus states, `<img>` without `alt`, and likely duplicate components. It exits 1 on any HIGH finding, so it can gate CI directly. Run it after every UI slice and before every commit.

Findings are not all equal — arbitrary spacing on one marketing page is minor, a second Button implementation is not. Fix by severity, and say which is which rather than dumping the whole list.

## Working order

1. Aesthetic direction first — palette, type, signature (the `frontend-design` skill if available)
2. Encode that direction as tokens (this skill, Step 1)
3. Build primitives against the tokens
4. Build patterns from primitives
5. Build features from patterns
6. `audit-ui.sh` before every commit

Building features before primitives exist is how the drift starts. The first feature invents a button, the second invents a slightly different one, and by the fifth there is no system to retrofit onto.

## Retrofitting an existing messy UI

Do not rewrite everything. It stalls, and the half-migrated state is worse than either end.

1. Run `audit-ui.sh` to get the actual damage, not the impression of it (pass the real source and CSS directories if they are not `resources/js` and `resources/css`)
2. Extract tokens from what already exists — cluster the real values in use, pick the nearest sane scale
3. Fix the single most-reused primitive first (usually Button), which alone removes a surprising share of the visible inconsistency
4. Add the audit to CI so new code stops adding to the pile
5. Migrate remaining components opportunistically, when they are being touched anyway

Step 4 is the one that matters. Stopping the bleeding beats cleaning the floor.

## When the same violation keeps coming back

A finding that appears once is a mistake. The same finding across three slices is a **gap in the system**, and fixing the instances again is treating the symptom.

Ask which of these it is:

- **The primitive is missing.** Three features wrote a raw `<button>` because no `Button` variant covered their case. Add the variant; the instances then fix themselves.
- **The token is missing.** `p-[13px]` keeps appearing because the scale genuinely has no step there. Either extend the scale deliberately and name it, or the design needs to snap to the existing one. Both are decisions; `p-[13px]` is an accident.
- **The audit cannot see it.** A real drift pattern that `audit-ui.sh` does not detect will keep recurring silently. Add the check to the script — that is the only fix that scales.

If `laravel-app-builder` is also installed, record the lesson through its mechanism: append to `docs/lessons.md` while it is fresh, and promote it at handover with `scripts/learn.sh` once it has recurred. Read that skill's `references/self-improvement.md` for what qualifies. Without it, put the rule where it will be read again — a new check in `audit-ui.sh` beats a note nobody opens.

## Reference files

| File | Read when |
|---|---|
| `references/tokens.md` | Defining or extracting tokens |
| `references/component-tiers.md` | Deciding where a component belongs, file layout |
| `references/accessibility-and-states.md` | Building any interactive or data component |
| `references/filament-parity.md` | The app has both a Filament panel and a React frontend |

## Communication

Respond in the language the user writes in. When shown UI code that violates the system, name the specific violation and its cost — "three Button implementations means three places to fix a focus ring" lands; "this is inconsistent" does not.
