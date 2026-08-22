# Architecture Contract

## Step 0 — Is this stack even the right one?

Do not skip this. Adding Inertia + React on top of Filament costs a second build pipeline, a second design system, a second auth mental model, and roughly double the frontend surface to maintain. That cost is worth paying only sometimes.

| Situation | Recommendation |
|---|---|
| Admin panel only — internal tool, dashboard, CRUD | Filament alone. No Inertia. |
| Public side is mostly static content or a catalogue, SEO matters, low interactivity | Filament admin + **Blade** frontend. Ships in a fraction of the time. |
| Public side has real app-like interactivity: multi-step flows, live filtering, a cart, end-user dashboards | Filament admin + Inertia/React. This is the case the stack is for. |
| A separate mobile or JS client is also needed | Filament admin + API (Sanctum) + a standalone React SPA. Inertia is the wrong fit. |

State the recommendation plainly, **including when it means talking the user out of React.** If they still want it for learning, that is a legitimate reason — acknowledge it and move on. What is not legitimate is an unexamined default driving the architecture.

Say this once, at the ERD gate, in one or two sentences. It is advice, not a veto.

## The two-paradigm problem

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

These are the versions a clean `bootstrap.sh` run actually resolved on 2026-08-23, not a remembered baseline:

| Package | Resolved |
|---|---|
| PHP | 8.2.12 |
| `laravel/framework` | 12.67.0 |
| `filament/filament` | v5.7.6 |
| `livewire/livewire` | v4.4.1 |
| `inertiajs/inertia-laravel` | v3.3.1 |
| `tightenco/ziggy` | v2.6.4 |
| `spatie/laravel-medialibrary` | 11.23.5 |
| `pestphp/pest` | v3.8.7 |
| vite | 7.3.6 |
| tailwindcss | 4.3.3 |
| `@vitejs/plugin-react` | 5.2.0 |

Treat that table as a snapshot, not a contract — it will drift. The commands above are what tell you the truth on the machine you are on.

- **Filament v3 → v4 is a real break.** Forms and infolists moved to a unified Schema API; actions consolidated into one namespace. v3 snippets do not run on v4/v5, and vice versa.
- **Filament v5 does not enable panel login by default.** A generated `AdminPanelProvider` has no `->login()` call, so `/admin/login` is a 404 and nobody can sign in. `bootstrap.sh` patches this; on a panel you did not scaffold, check for it before concluding auth is broken.
- **Tailwind v4** is CSS-configured via `@theme`, not `tailwind.config.js`-first.
- **The Vite entry and the Blade view must agree.** Laravel's `welcome.blade.php` loads `resources/js/app.js`. Switching the Vite input to `app.tsx` without changing the view leaves the homepage throwing "Unable to locate file in Vite manifest" — a 500 on `/` that no unit test catches.
- **`@vitejs/plugin-react` often requires the next Vite major** after the one the skeleton pins, and npm fails the whole install on that peer conflict rather than choosing an older plugin. Pin the plugin to a version whose peer range accepts the installed Vite.

When unsure whether a method exists in the installed version, check via Boost's docs search tool or the real documentation. Inventing a plausible-looking method call is the single most common way an autonomous build produces code that reads correctly and does not run.

## Asset pipeline — keep the two worlds apart

The most common configuration failure here is trying to make Filament and the app frontend share one CSS entry point.

- Filament compiles and serves its own assets (`php artisan filament:assets`)
- The app frontend has its own Vite entries: `resources/css/app.css`, `resources/js/app.tsx`
- Customizing Filament's look means a custom theme (`php artisan make:filament-theme`) with its own CSS file registered on the panel — never merged into `app.css`
- Never import app styles into a Filament view or Filament's theme into React. The two Tailwind builds have different presets and will fight

## Settings are key-value. Always.

**Non-negotiable: application settings live in a key-value store, never as columns on a one-row `settings` table.**

The wide-table version looks tidy for about a week. Then every new setting — a WhatsApp number, a footer line, a toggle for a feature that shipped yesterday — is a migration, a deploy, a model change, and a form change. Settings are exactly the data that changes most often and matters least architecturally; putting them in the schema inverts that.

```php
Schema::create('settings', function (Blueprint $table) {
    $table->id();
    $table->string('group')->default('general')->index();
    $table->string('key')->unique();
    $table->json('value')->nullable();   // json so a bool stays a bool
    $table->timestamps();
});
```

The rules:

- **Adding a setting must never require a migration.** That is the whole test. If it does, the design is wrong.
- **`value` is JSON, not `string`.** Otherwise every read needs a cast the caller has to remember, and `"false"` eventually gets treated as true by someone.
- **Reads go through one class**, never `Setting::where('key', ...)` scattered around:

```php
final class Settings
{
    public function get(string $key, mixed $default = null): mixed
    {
        return Cache::rememberForever('settings', fn () => Setting::pluck('value', 'key'))
            ->get($key, $default);
    }
}
```

- **Cache the whole set, invalidate on write.** A settings row read on every request, uncached, is a query on every page for data that changes monthly.
- **Typed accessors at the edges.** `$settings->whatsappNumber()` beats `$settings->get('whatsapp_number')` sprinkled through views — one place to change the key, one place to validate the shape.
- **Seed defaults.** A missing key must not be a 500. Every setting has a default in code, and the store only overrides it.

For a project that wants this ready-made, `spatie/laravel-settings` gives typed settings classes backed by exactly this table. Either approach is fine; a column per setting is not.

**In Filament**, settings get a dedicated Page, not a Resource — there is no list of settings to browse. Group them into sections the same way as any other form. Filament's `KeyValue` field is for genuinely open-ended maps the admin invents (custom meta tags, redirects); known settings get real typed fields with validation, because a text box that accepts anything will eventually receive anything.

## Performance defaults

"Laravel is slow" is almost never PHP's fault. Diagnose in this order before touching Octane or FrankenPHP:

1. **N+1 queries** — Debugbar or Telescope, read the query count on every page. This is the cause the overwhelming majority of the time.
2. **Oversized Inertia props** — check the size of the JSON in the `data-page="app"` script tag in page source. Trim, defer, paginate.
3. **Missing indexes** on foreign keys and `where`/`orderBy` columns
4. **Uncached repeated work**; `php artisan optimize` in production
5. **Frontend bundle size** — code splitting

Only after those are clean is the runtime the bottleneck. Recommending FrankenPHP for an unmeasured problem is guessing with extra steps — say so if it comes up.

## Anti-patterns

- **Filament as the whole app.** It is an admin panel framework. Customer-facing flows built as Filament pages fight you within a month.
- **A package for every feature.** Each Filament plugin is a compatibility liability at the next major version. Check supported majors before adding one.
- **Building admin and frontend simultaneously.** Slice order exists for a reason.
- **Designing for scale not yet reached.** Multi-tenancy and nationwide architecture are decisions to make with users in production.
