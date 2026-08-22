# Design Tokens

Tokens are the only reason a design system holds. Components without tokens are just files; tokens without components still produce a coherent product.

## Name by role, not by appearance

The single most consequential naming decision.

| Bad | Good | Why |
|---|---|---|
| `--color-blue-500` | `--color-primary` | Survives a rebrand |
| `--color-red` | `--color-danger` | Says where it belongs |
| `--color-gray-100` | `--color-surface-muted` | Says what it is for |
| `--spacing-13px` | `--spacing-3` | Belongs to a scale |

Literal names guarantee a future where `--color-blue-500` is orange and nobody dares rename it because it appears in ninety files.

Two-layer naming is worth it once a brand has real color identity:

```css
@theme {
  /* Layer 1 — the raw palette. Referenced only by layer 2. */
  --brand-navy-600: oklch(0.42 0.11 255);
  --brand-navy-050: oklch(0.96 0.02 255);

  /* Layer 2 — semantic roles. This is what components use. */
  --color-primary:    var(--brand-navy-600);
  --color-primary-fg: oklch(0.99 0 0);
  --color-accent-bg:  var(--brand-navy-050);
}
```

Components reference layer 2 only. A rebrand then touches one block instead of the whole codebase.

## Constrain the scales

A scale with thirty-two steps is not a scale, it is a permission slip. Six to eight steps per axis forces decisions and makes drift visible — when only `--spacing-4` and `--spacing-6` exist, nobody produces the 22px gap that makes a page feel slightly off in a way nobody can name.

Recommended ceilings: spacing 7 steps, type 6, radius 3, shadow 3, font weight 3.

If a design genuinely needs a value outside the scale, extend the scale deliberately and name it. That is a decision. Reaching for `p-[22px]` is an accident.

## Color: use oklch

Tailwind v4 and modern CSS support it, and it behaves the way designers expect: lightness is perceptually uniform, so `oklch(0.55 0.18 255)` and `oklch(0.55 0.18 25)` are genuinely equally light. In HSL they are not, which is why HSL palettes have that one color that always looks wrong next to the others.

It also makes generating a consistent palette mechanical — hold lightness and chroma, rotate hue.

## Dark mode

Define it as a token override, never as conditional classes in components. `dark:bg-gray-800` scattered across components is the same drift problem wearing a different hat.

```css
@layer base {
  :root {
    --color-surface: oklch(1 0 0);
    --color-content: oklch(0.22 0.01 260);
  }
  .dark {
    --color-surface: oklch(0.18 0.01 260);
    --color-content: oklch(0.95 0.005 260);
  }
}
```

Components stay written as `bg-surface text-content` and dark mode works with no component changes. If dark mode requires editing components, the tokens are wrong.

Do not build dark mode unasked. It roughly doubles the visual surface to verify, and many products never need it.

## Typography

Set the type scale as tokens including line height — a font size without a paired line height is half a decision, and the missing half is where vertical rhythm falls apart.

```css
@theme {
  --text-sm: 0.875rem;
  --text-sm--line-height: 1.5;
  --text-base: 1rem;
  --text-base--line-height: 1.6;
  --text-2xl: 2rem;
  --text-2xl--line-height: 1.2;
}
```

Body text wants 1.5–1.65. Display text wants 1.05–1.25. A single global line height applied to both makes headings look loose and body text cramped simultaneously.

Cap measure at roughly 65–75 characters (`max-w-[65ch]` is the one arbitrary value worth allowing, or tokenize it as `--width-prose`).

## Extracting tokens from an existing codebase

When retrofitting, do not invent a scale and declare the existing UI wrong. Measure first:

```bash
# Every spacing value actually in use, by frequency
grep -rhoE '\b[pmg][xytrbl]?-(\[[^]]+\]|[0-9.]+)' resources/js --include='*.tsx' \
  | sort | uniq -c | sort -rn | head -30

# Every hex color in use
grep -rhoE '#[0-9a-fA-F]{3,8}\b' resources/js resources/css \
  | tr 'A-F' 'a-f' | sort | uniq -c | sort -rn
```

The output usually shows the design was mostly consistent already, with a long tail of near-duplicates: `#1e40af`, `#1e3fae`, `#1d40b0`. Cluster those into one token each. Frequency tells you which value wins.

This is faster and less disruptive than a redesign, and it produces a system the existing UI already mostly conforms to.

## The test

Open any component file. If it contains a hex code, an arbitrary pixel value, or a `dark:` class, the token layer is leaking. Every visual value should be a token reference, and a new designer should be able to restyle the entire product by editing one file.
