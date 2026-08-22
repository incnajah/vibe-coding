# States and Accessibility

The reason a UI "feels unfinished" is almost never layout. It is that only the happy path was built. Everything below is baseline, not polish.

## Interactive component states

Every interactive component covers all of these before it is done:

| State | Requirement |
|---|---|
| Default | Resting appearance |
| Hover | Visible change, pointer devices only |
| Focus-visible | **Never removed.** Ring with offset, keyboard-only |
| Active | Pressed feedback |
| Disabled | Reduced opacity, `pointer-events-none`, real `disabled` attribute |
| Loading | Spinner, disabled, label persists so width does not jump |
| Error | For inputs — border, message, `aria-invalid` |

`focus:outline-none` without a replacement ring is the most common accessibility failure in AI-generated UI, and it makes the app unusable by keyboard. Use `focus-visible:` so mouse users do not see rings while keyboard users do.

Loading buttons that swap the label for a spinner cause layout shift. Keep the label, add the spinner:

```tsx
<Button disabled={processing}>
  {processing && <Loader2 className="size-4 animate-spin" aria-hidden />}
  Save changes
</Button>
```

## Data view states

Every list, table, and data-driven page handles four states. Skipping any produces a screen that looks broken at exactly the wrong moment.

**Loading** — skeletons matching the real content's shape, not a centered spinner. A spinner tells the user nothing; a skeleton tells them what is arriving.

**Empty** — the state most often skipped, and the one a new user sees first. It needs: what this screen is for, why it is empty, and the action that fills it.

```tsx
<EmptyState
  icon={PackageIcon}
  title="Belum ada paket"
  description="Paket yang kamu buat akan muncul di sini."
  action={<Button onClick={onCreate}>Buat paket pertama</Button>}
/>
```

Distinguish "no data yet" from "no results for this filter" — they need different copy and different actions. Showing "create your first package" to someone who just typed a search term reads as broken.

**Error** — say what failed and what to do. Never a bare "Something went wrong."

**Populated** — the happy path.

## Accessibility floor

Not aspirational. These are cheap when built in and expensive to retrofit.

- **Semantic elements.** A `<div onClick>` is not a button: no keyboard access, no role, no focus. If it navigates it is an `<a>`; if it acts it is a `<button>`.
- **Labels on every input.** `<FormField>` handles this; nothing should bypass it.
- **Color is never the only signal.** Errors get an icon or text, not just red. Roughly one in twelve men cannot reliably distinguish it.
- **Contrast** — 4.5:1 for body text, 3:1 for large text and UI boundaries. Muted-gray-on-white placeholder text usually fails; check before shipping it.
- **Touch targets** at least 44×44px. An icon button that is visually 20px needs padding to reach it.
- **Keyboard traps** — modals trap focus while open and return it to the trigger on close.
- **`alt` on every image.** Decorative images get `alt=""`, not a missing attribute.
- **Reduced motion respected:**

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Motion

Motion communicates or it is noise. Useful: confirming a state change, showing where something came from, masking a wait. Not useful: entrance animations on every card in a grid, which delays content and reads as AI-generated.

Durations: 100–150ms for hover and small state changes, 200–300ms for panels and modals, above 400ms only for something deliberately theatrical. Ease-out for entering, ease-in for leaving.

## Responsive

Mobile first, and verify at 375px specifically — it is where real breakage appears and where most Indonesian traffic actually is.

Common failures worth checking every time: tables that overflow (wrap in `overflow-x-auto` or switch to cards below `md`), fixed widths that force horizontal scroll, modals taller than the viewport with no internal scroll, touch targets that shrink below 44px on small screens.

## Verification pass per screen

- Tab through the whole screen. Every interactive element reachable, focus always visible, order logical.
- Force each of the four data states and look at all four.
- Resize to 375px.
- Zoom to 200% — text should reflow, not clip.
- Browser console clean, including React key warnings.
