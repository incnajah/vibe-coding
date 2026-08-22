# Component Tiers

Four tiers, each with an unambiguous membership test. Unambiguous is the whole point — a boundary people have to debate is a boundary that will be applied inconsistently.

```
resources/js/
├── components/
│   ├── ui/          # Tier 1 — primitives (shadcn lives here)
│   ├── patterns/    # Tier 2 — composed, still domain-free
│   └── <feature>/   # Tier 3 — domain-aware
├── Layouts/         # Tier 4 — page shells
└── Pages/           # Inertia route targets
```

## Tier 1 — Primitives

**Test: could this be pasted into a completely unrelated project and still make sense?**

`Button`, `Input`, `Select`, `Checkbox`, `Card`, `Badge`, `Dialog`, `Tooltip`, `Skeleton`.

Rules:
- No business logic, no data fetching, no domain vocabulary
- Every visual value comes from a token
- Variants via `cva`, not boolean props
- Forward refs and spread `...props` so consumers can extend without forking
- All interaction states covered (see `accessibility-and-states.md`)

This is where shadcn/ui components land. They are copied into the repo, so they are project code — edit them to use your tokens rather than layering overrides on top. A shadcn component still carrying default styling is the single clearest tell of an AI-generated app, because everyone gets the same one.

## Tier 2 — Patterns

**Test: composes primitives, still knows nothing about the domain.**

`FormField` (label + control + description + error), `DataTable`, `EmptyState`, `PageHeader`, `ConfirmDialog`, `Pagination`, `FilterBar`.

This tier is where most real consistency comes from, and it is the tier most projects skip. Without a `FormField`, every form re-invents label placement and error styling, and thirty forms drift thirty different ways.

```tsx
export function FormField({ label, error, description, required, children }: FormFieldProps) {
  const id = useId()
  return (
    <div className="space-y-2">
      <label htmlFor={id} className="text-sm font-medium text-content">
        {label}
        {required && <span className="text-danger ml-1" aria-hidden>*</span>}
      </label>
      {cloneElement(children, { id, "aria-invalid": !!error,
        "aria-describedby": error ? `${id}-error` : undefined })}
      {description && !error && (
        <p className="text-sm text-content-muted">{description}</p>
      )}
      {error && (
        <p id={`${id}-error`} role="alert" className="text-sm text-danger">{error}</p>
      )}
    </div>
  )
}
```

Label association, error announcement, and required marking are solved once here instead of forgotten thirty times.

## Tier 3 — Features

**Test: does it know what a Package is?**

`PackageCard`, `DepartureSelector`, `BookingSummary`, `MuthowifProfile`.

Rules:
- Composes patterns and primitives; never re-implements them
- Domain logic stays in hooks or server props, not in JSX
- Not shared across features — if two features need the same thing, it belongs in Tier 2, generalized

A feature component reaching for a raw `<button className="...">` instead of `<Button>` is the moment the system starts failing. That is the line to watch during review.

## Tier 4 — Layouts and pages

Layouts are shells: header, footer, sidebar, container widths. Pages compose features and hold almost no markup of their own.

A page component with fifty lines of JSX is doing feature work. Extract it — pages should read as an outline of the screen.

## Where new components go

```
Does it know the domain?           → yes: features/<domain>/
Does it compose other components?  → yes: patterns/
Otherwise                          → ui/
```

Three questions, deterministic answer. No taxonomy debate.

## Preventing duplicates

Before creating a component, check whether one exists that a variant would cover:

```bash
ls resources/js/components/ui resources/js/components/patterns
grep -rl "className=\"[^\"]*rounded" resources/js/components | head
```

`Button` + `IconButton` + `LinkButton` should be one `Button` with `size="icon"` and `asChild`. Three implementations means three places to fix a focus ring, and the third one always gets missed.

Legitimate reasons for a second component: genuinely different semantics (a `Link` is an anchor, a `Button` is a button — that distinction is real and matters for accessibility), or a different interaction model entirely.

## Composition over configuration

When a component accumulates props, it is asking to be split.

```tsx
// Fights you at prop 8
<Card title="..." subtitle="..." image="..." actions={[...]} footer="..." badge="..." />

// Extends without modification
<Card>
  <Card.Header>
    <Card.Title>...</Card.Title>
    <Badge>New</Badge>
  </Card.Header>
  <Card.Content>...</Card.Content>
  <Card.Footer><Button>Book</Button></Card.Footer>
</Card>
```

The rule of thumb: past six props, or the first prop named `showX`, reach for composition instead.

## Documentation that stays true

Skip a separate style guide document — it goes stale within a month and then actively misleads. Instead keep a single route, `/design-system`, rendering every primitive in every variant and state. It cannot go stale, because it renders the real components. It is also the fastest way to spot that two buttons no longer match.
