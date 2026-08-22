# Filament ↔ React Visual Parity

In a Laravel app with a Filament panel and an Inertia/React frontend, the two will look like two different products unless tokens are shared deliberately. This matters more than it sounds: the admin is what the client opens every day, and a panel that looks unrelated to their own site reads as unfinished regardless of how good the public pages are.

## The constraint

Filament compiles its own CSS with its own Tailwind build. The React frontend compiles its own. **They cannot share a stylesheet** — merging them produces preset conflicts and broken styling in both. What they can share is the *values*.

## Single source of truth

Put the raw palette in one CSS file that both builds import:

```css
/* resources/css/tokens.css — the only place brand values are defined */
:root {
  --brand-primary-50:  oklch(0.96 0.02 255);
  --brand-primary-500: oklch(0.55 0.18 255);
  --brand-primary-600: oklch(0.48 0.17 255);
  --brand-primary-950: oklch(0.24 0.09 255);
  --brand-radius: 0.5rem;
  --brand-font-sans: 'Inter', system-ui, sans-serif;
}
```

The React app imports it and maps to semantic roles:

```css
/* resources/css/app.css */
@import "tailwindcss";
@import "./tokens.css";

@theme {
  --color-primary: var(--brand-primary-500);
  --font-sans: var(--brand-font-sans);
  --radius-md: var(--brand-radius);
}
```

The Filament theme imports the same file:

```bash
php artisan make:filament-theme
```

```css
/* resources/css/filament/admin/theme.css */
@import '/vendor/filament/filament/resources/css/theme.css';
@import '../../tokens.css';

@theme {
  --font-family-sans: var(--brand-font-sans);
}
```

Register the theme on the panel, then rebuild both:

```php
->viteTheme('resources/css/filament/admin/theme.css')
```

## Filament's color system

Filament takes colors as PHP config, not CSS, so map them in the panel provider:

```php
use Filament\Support\Colors\Color;

$panel->colors([
    'primary' => Color::hex('#2563eb'), // same value as --brand-primary-500
    'danger'  => Color::Rose,
    'gray'    => Color::Slate,
]);
```

Filament generates its own shade ramp from that hex. Keep the hex in one place — a PHP constant or a config entry read by both — so it cannot drift from the CSS token.

## What to match, and what not to

Match: brand color, typeface, border radius, logo, favicon.

**Do not** try to make the admin look like the public site. It is a different product with a different user doing a different job. An admin optimized for dense scanning and fast data entry should look dense and functional; forcing marketing-site spacing and hero typography onto it makes it slower to use.

The goal is *recognizably the same brand*, not visually identical. Shared color, type, and radius achieve that. Everything else should follow each context's job.

## Filament customization worth doing

```php
->brandLogo(asset('images/logo.svg'))
->brandLogoHeight('2rem')
->favicon(asset('favicon.ico'))
->font('Inter')
->sidebarCollapsibleOnDesktop()
->maxContentWidth(MaxWidth::Full)
```

Filament's defaults are good. Restyling it heavily is usually a poor return — the effort belongs on the public side, where it affects conversion rather than internal workflow.

## After changing anything

```bash
npm run build
php artisan filament:assets
php artisan filament:optimize
```

Styling that works locally and breaks after deploy is nearly always one of those three not having run in the deploy pipeline.

## Parity checklist

- Same primary color in `tokens.css` and the panel's `colors()`
- Same typeface both sides
- Logo and favicon in both
- Login page carries the brand
- Both dark modes behave the same, or neither has one
