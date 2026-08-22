# Architecture Contract

This stack puts two frontend paradigms in one codebase: Filament (Livewire + Alpine + Blade, server-driven) for admin, and Inertia + React for the public side. Nearly every failure in it traces back to business logic leaking into one of the two UI layers, so behaviour silently diverges between admin and frontend.

One rule settles most design questions:

> **Filament Resources and Inertia controllers are both thin callers. All business logic lives in single-purpose Action classes that neither layer owns.**

## Layout

```
app/
├── Actions/            # business logic — the only place it lives
│   └── Package/
│       ├── CreatePackage.php
│       ├── UpdatePackage.php
│       └── PublishPackage.php
├── Http/
│   ├── Controllers/    # Inertia controllers, thin
│   ├── Requests/       # validation shared by both layers
│   └── Resources/      # prop shaping for Inertia
├── Filament/Resources/ # admin UI definition, thin
├── Models/
├── Queries/            # reusable query builders for public listings
└── Support/
```

## Why it matters concretely

Publishing a package must stamp `published_at`, clear a cache, and fire a notification. That sequence has to be identical whether an admin clicked a Filament action or a controller triggered it. Logic living inside the Filament Resource means the second caller silently does less — and this class of bug does not throw an error, it just produces wrong data quietly.

```php
final class PublishPackage
{
    public function __construct(private CacheRepository $cache) {}

    public function handle(Package $package): Package
    {
        $package->update(['published_at' => now()]);
        $this->cache->forget('packages.published');
        PackagePublished::dispatch($package);

        return $package->fresh();
    }
}
```

Filament calls it:

```php
Action::make('publish')
    ->requiresConfirmation()
    ->action(fn (Package $record, PublishPackage $publish) => $publish->handle($record));
```

The controller calls the same class. Validation is shared through Form Request classes so the two layers cannot drift.

## Red flags — stop and refactor if generated code contains these

- A `DB::` call or an `update()` chain inside a Filament Resource
- Business rules duplicated in a React component
- A Filament `->afterSave()` hook containing logic the frontend also needs
- An Eloquent model passed directly as an Inertia prop (leaks columns, couples the frontend to the schema)

## Version discipline

This ecosystem moves fast enough that assumed APIs produce non-running code. Before generating, confirm:

```bash
php artisan --version
composer show filament/filament laravel/framework inertiajs/inertia-laravel
```

Baseline as of mid-2026: Laravel 13.x, Filament v4 and v5 both maintained, Inertia v2, Tailwind v4, PHP 8.2+.

- **Filament v3 → v4 is a real break.** Forms and infolists moved to a unified Schema API; actions consolidated into one namespace. v3 snippets do not run on v4/v5, and vice versa.
- **Filament v5 has no new features over v4** — it exists only for Livewire v4 support. Never present a v5 upgrade as a feature win.
- **Tailwind v4** is CSS-configured via `@theme`, not `tailwind.config.js`-first.

When unsure whether a method exists in the installed version, check via Boost's docs search tool or the real documentation. Inventing a plausible-looking method call is the single most common way an autonomous build produces code that reads correctly and does not run.

## Asset pipeline — keep the two worlds apart

The most common configuration failure here is trying to make Filament and the app frontend share one CSS entry point.

- Filament compiles and serves its own assets (`php artisan filament:assets`)
- The app frontend has its own Vite entries: `resources/css/app.css`, `resources/js/app.tsx`
- Customizing Filament's look means a custom theme (`php artisan make:filament-theme`) with its own CSS file registered on the panel — never merged into `app.css`
- Never import app styles into a Filament view or Filament's theme into React. The two Tailwind builds have different presets and will fight

## Performance defaults

"Laravel is slow" is almost never PHP's fault. Diagnose in this order before touching Octane or FrankenPHP:

1. **N+1 queries** — Debugbar or Telescope, read the query count on every page. This is the cause the overwhelming majority of the time.
2. **Oversized Inertia props** — check the `data-page` payload size in page source. Trim, defer, paginate.
3. **Missing indexes** on foreign keys and `where`/`orderBy` columns
4. **Uncached repeated work**; `php artisan optimize` in production
5. **Frontend bundle size** — code splitting

Only after those are clean is the runtime the bottleneck. Recommending FrankenPHP for an unmeasured problem is guessing with extra steps — say so if it comes up.

## Anti-patterns

- **Filament as the whole app.** It is an admin panel framework. Customer-facing flows built as Filament pages fight you within a month.
- **A package for every feature.** Each Filament plugin is a compatibility liability at the next major version. Check supported majors before adding one.
- **Building admin and frontend simultaneously.** Slice order exists for a reason.
- **Designing for scale not yet reached.** Multi-tenancy and nationwide architecture are decisions to make with users in production.
