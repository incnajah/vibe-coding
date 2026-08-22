---
name: laravel-filament-inertia
description: Architecture guidance — advice only, no scaffolding and no build loop — for an existing Laravel codebase that pairs a Filament admin panel with an Inertia + React frontend. Use it when the user asks how to structure, review, or debug such a project: where business logic belongs across the two UI layers, pinning Filament/Inertia versions, Vite and Tailwind asset separation, diagnosing N+1 and slow pages, or deployment checks. Do not use it to build an application from a feature description — `laravel-app-builder` covers that, and only one of the two should be installed.
---

# Laravel + Filament + Inertia React

> **Superseded.** The content here is folded into `laravel-app-builder/references/architecture.md`. Install this skill *instead of* `laravel-app-builder`, never alongside it — two skills claiming the same stack makes triggering unpredictable. Keep this one only if you want the architecture guidance without the autonomous build machinery.

This stack puts **two frontend paradigms in one codebase**: Filament (Livewire + Alpine + Blade, server-driven) for the admin, and Inertia + React (client-rendered) for the public site. It works well, but only if the boundary between them is explicit. Almost every failure in this stack traces back to business logic leaking into one of the two UI layers, so that behaviour silently diverges between admin and frontend.

The job of this skill is to keep that boundary intact while shipping fast.

## Step 0 — Challenge the stack before building it

Do not skip this. Adding Inertia + React to a Filament project costs a second build pipeline, a second design system, a second auth mental model, and roughly double the frontend surface to maintain. That cost is worth paying only sometimes.

| Situation | Recommendation |
|---|---|
| Admin panel only (internal tool, dashboard, CRUD) | Filament alone. No Inertia. |
| Public site is mostly static content/catalog, SEO matters, low interactivity | Filament admin + **Blade** frontend. Ship in a fraction of the time. |
| Public side has real app-like interactivity: multi-step flows, live filtering, cart, dashboards for end users | Filament admin + Inertia/React. This is the case the stack is for. |
| Public side needs a separate mobile/JS client too | Filament admin + API (Sanctum) + React SPA. Inertia is the wrong fit. |

State the recommendation plainly, including when it means talking the user out of React. If they still want React for learning purposes, that is a legitimate reason — acknowledge it as such and move on, but do not let an unexamined default drive the architecture.

## Step 1 — Pin versions from the project, never from memory

This ecosystem moves fast and version details change real APIs. Before writing any code:

```bash
php artisan --version
composer show filament/filament laravel/framework inertiajs/inertia-laravel 2>/dev/null
cat package.json
```

Baseline as of mid-2026: Laravel 13.x, Filament v4 and v5 both actively maintained (v5 exists only for Livewire v4 support and is otherwise identical to v4 — never push a v5 upgrade as a feature win), Inertia v2, Tailwind v4, PHP 8.2+.

Version traps that produce broken code if assumed wrong:
- **Filament v3 → v4** is a real architectural break: forms and infolists moved to a unified **Schema** API, and actions consolidated into one namespace. v3 code snippets do not run on v4/v5 and vice versa. Confirm the major version before generating a single Resource.
- **Tailwind v4** has no `tailwind.config.js`-first workflow; configuration is CSS-based via `@theme`. Filament v4+ ships Tailwind v4.
- If unsure about a current API, fetch the docs rather than guessing. Confidently wrong Filament code wastes more of the user's time than a lookup.

## Step 2 — The architecture contract

This is the core of the skill. One rule, and it settles most design questions:

> **Filament Resources and Inertia controllers are both thin callers. All business logic lives in single-purpose Action classes that neither layer owns.**

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
│   └── Resources/      # DTO shaping for Inertia props
├── Filament/
│   └── Resources/      # admin UI definition, thin
├── Models/
├── Queries/            # reusable query builders (public catalog, filters)
└── Support/
```

Why this matters concretely: when publishing a package must also clear a cache, fire a notification, and stamp `published_at`, that sequence must be identical whether it was triggered by an admin clicking a Filament action or by an API/frontend call. If the logic sits inside the Filament Resource, the second caller silently does less.

An Action is boring on purpose:

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
    ->action(fn (Package $record, PublishPackage $publish) => $publish->handle($record));
```

The controller calls the same thing. Validation is shared through Form Request classes or a shared rules object so the two layers cannot drift apart.

**Red flags to call out immediately if seen in the user's code:** a `DB::` query or an `update()` chain inside a Filament Resource; business rules duplicated in a React component; a Filament `->afterSave()` hook containing logic the frontend also needs.

## Step 3 — Build order

Scaffold in this sequence. Each stage is verifiable before the next one starts, which keeps debugging cheap.

1. **Schema first.** Migrations, models, relationships, factories, seeders. Seed realistic volume (hundreds of rows, not three), because performance problems that only appear at volume should appear now.
2. **Actions + tests.** Write the Action classes and Pest feature tests against them, with no UI at all. Green tests here mean both UIs are built on something already proven.
3. **Filament admin.** Resources, relation managers, policies. Admin can now fully manage the data.
4. **Public frontend.** Inertia controllers → thin props → React pages.
5. **Hardening.** Performance pass, deployment, monitoring.

Building the React frontend before the admin exists is a common and expensive mistake: there is no real data to render, so the frontend gets built against invented shapes and reworked later.

## Filament specifics

- Generate with artisan rather than hand-writing: `php artisan make:filament-resource Package --generate --view`. Hand-written Resources drift from the installed version's API.
- **Panel access must be explicit in production.** Implement `FilamentUser::canAccessPanel()` on the User model — without it, Filament blocks access in non-local environments and the user will report "it works locally but not on the server."
- Use **relation managers** for one-to-many editing instead of nested repeaters on foreign data. Repeaters are for embedded/JSON-ish structures.
- Register **policies**; Filament respects them automatically. Do not reimplement authorization inside Resources.
- For file/image handling, use `spatie/laravel-medialibrary` with `SpatieMediaLibraryFileUpload` so the admin and the public frontend read images through one abstraction.
- Multi-tenancy in v4+ scopes queries automatically. If the user is on v3, warn that scoping outside tables and global search is manual — a real security footgun.
- Large tables: `->deferLoading()`, `->paginated([25, 50])`, and avoid computing values per-row in PHP when a query can do it.

## Inertia + React specifics

- Props are a **contract, not a database dump.** Never pass an Eloquent model straight through; shape it with an API Resource or an explicit array. Passing full models leaks columns (including sensitive ones) into the page's HTML.
- Keep initial payloads small. Use Inertia v2's deferred props for below-the-fold data, `WhenVisible` for lazy sections, and partial reloads (`only:`) for filter/search interactions instead of full page visits.
- Forms use Inertia's `useForm`; let Laravel validation be the source of truth and render `errors` from the server. Do not build a parallel client-side validation schema with different rules.
- shadcn/ui components are **copied into the repo**, not installed as a dependency. They live under `resources/js/components/ui/` and are yours to edit — treat them as project code.
- React state stays local. There is no need for Redux/Zustand in an Inertia app; the server is the store.

## Asset pipeline — keep the two worlds apart

The single most common configuration failure in this stack is trying to make Filament and the app frontend share one CSS entry point.

- Filament compiles and serves **its own** assets. Publish them with `php artisan filament:assets`.
- The app frontend has its own Vite entries: `resources/css/app.css` and `resources/js/app.tsx`.
- If Filament's appearance needs customizing, create a **custom Filament theme** (`php artisan make:filament-theme`) with its own CSS file registered on the panel. Do not merge it into `app.css`.
- Never import shadcn/Tailwind app styles into a Filament view, or Filament's theme into the React app. The two Tailwind builds have different presets and will fight each other.
- Filament panel lives on its own path (`/admin`) and can use its own guard. Keep session/auth config for the panel separate and deliberate.

## Performance defaults

Most "Laravel is slow" reports in this stack are not PHP's fault. Diagnose in this order before reaching for Octane, FrankenPHP, or async experiments:

1. **N+1 queries.** Install Laravel Debugbar or Telescope and read the query count on every page. Fix with eager loading. This is the cause the overwhelming majority of the time.
2. **Oversized Inertia props.** Check the size of the `data-page` payload in the page source. Trim, defer, paginate.
3. **Missing indexes** on foreign keys and columns used in `where`/`orderBy`.
4. **Uncached repeated work** — expensive aggregates, sitemap-ish queries, config/route caching in production.
5. **Frontend bundle size** — code splitting, lazy routes.

Only after those are clean does runtime (Octane/FrankenPHP) become the bottleneck worth addressing. Say so directly if the user proposes a runtime change before measuring; recommending FrankenPHP for an unmeasured problem is guessing with extra steps.

## Testing

Pest, weighted toward the Action layer since that is where the shared logic lives. Feature tests for Inertia responses via `assertInertia()`. Filament ships its own testing helpers for Resources — use them for critical admin flows (create, edit, custom actions, authorization), not for exhaustive coverage of generated CRUD.

## Deployment checklist

```bash
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan optimize          # config, routes, views, events
php artisan filament:optimize # Filament component + icon caches
php artisan icons:cache
npm ci && npm run build
php artisan storage:link
```

Plus: queue worker under Supervisor (Filament actions and notifications assume queues work), Redis for cache/session, scheduler cron entry, error tracking, automated database backups, and `APP_DEBUG=false`.

## Anti-patterns worth naming out loud

- **Filament as the whole app.** Filament is an admin panel framework. Building customer-facing flows as Filament pages produces something that fights you within a month.
- **Duplicated logic across the two UIs.** Covered above; it is the failure mode of this stack.
- **Passing raw models as Inertia props.** Leaks data and couples the frontend to the database schema.
- **Reaching for a package for every feature.** Each Filament plugin is a version-compatibility liability at the next major upgrade. Check the plugin's supported major version before recommending it.
- **Building admin and frontend simultaneously.** Order matters; see Step 3.
- **Planning past the first shipped version.** Multi-tenancy, microservices, and nationwide-scale architecture are decisions to make with users in production, not before. If the user is designing for scale they have not reached, say so.

## Communication

Respond in the language the user is writing in. Show real, runnable code over prose descriptions of code. When the user's request implies an architectural mistake, say it before implementing — a working implementation of the wrong structure is a more expensive outcome than a short disagreement.
