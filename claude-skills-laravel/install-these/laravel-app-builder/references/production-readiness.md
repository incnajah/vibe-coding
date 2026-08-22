# Production Readiness

`verify.sh` answers one question: does the application run. Production asks a different one: **what happens when it runs unattended, under load, for a user who is not you, on a machine you cannot see.**

The gap between those two is where most "finished" Laravel apps actually fail. An app can pass every test and still lose every queued job, leak stack traces to strangers, and have no way to tell you it broke.

This phase runs after the last slice and before handover. Read it with `scripts/preflight-prod.sh`, which mechanically checks the parts that can be checked from the repo.

## The five things that break first

Ordered by how often they bite, not by how interesting they are.

**1. `APP_DEBUG=true` in production.** Every exception page becomes a full disclosure: environment variables, database credentials, file paths, and a stack trace. This is a data breach delivered as a 500 page. `APP_ENV=production` and `APP_DEBUG=false`, and confirm it on the server, not in `.env.example`.

**2. `QUEUE_CONNECTION=sync`.** The default runs jobs inline in the request. Email sending, image conversions, and notifications all become part of the user's page load, and a failure takes the request down with it. Move to `redis` or `database`, run a worker under Supervisor so it restarts, and create the `failed_jobs` table so failures are recoverable rather than gone.

**3. No scheduler.** `php artisan schedule:run` needs a cron entry every minute. Without it, everything scheduled silently never happens — and nothing reports the absence.

**4. No error tracking.** `storage/logs/laravel.log` on a server nobody reads is not error tracking. Something has to reach a human: Sentry, Flare, Bugsnag, or at minimum a log channel that ships somewhere. The alternative is finding out from the client.

**5. Untested backups.** A backup that has never been restored is a hypothesis. Schedule automated database backups, then actually restore one into a scratch database before handover. This is the single check most likely to be skipped and most expensive to have skipped.

## Environment and secrets

- `.env` is never committed. `.env.example` carries every key with empty or safe values, so a deploy fails loudly on a missing key rather than silently on a wrong default.
- `APP_KEY` generated per environment. Reusing the local key in production makes every encrypted value and signed URL forgeable by anyone with the repo.
- `APP_URL` set correctly — signed URLs, password resets, and asset paths all derive from it.
- Credentials come from the platform's secret store, not from a `.env` copied over SSH.

## The optimize pass

```bash
composer install --no-dev --optimize-autoloader
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
php artisan filament:optimize
npm ci && npm run build
```

Two traps. `config:cache` means `env()` returns `null` everywhere outside config files — if any code calls `env()` directly, it breaks only in production, only after caching. And every one of these must be re-run on deploy; a cached route table from the previous release is a very confusing bug.

`php artisan optimize` bundles most of them, but run `filament:optimize` explicitly — it caches panel components and is not part of the framework's optimize.

## Database

- Index every foreign key, and every column used in a `where` or `orderBy` on a page that will be hit often. Laravel does not add these for you.
- Deploy runs `php artisan migrate --force`. It never runs `migrate:fresh` — that drops everything, and on production that is unrecoverable.
- Automated daily backups, offsite, with a restore that has been tested.
- A dedicated database user with only the privileges the app needs.

## Sessions, cache, and multi-server

The `file` driver works until there are two servers, and then it fails in a way that looks like random logouts. If the app will ever run on more than one instance, sessions and cache go to Redis or the database from the start — retrofitting it during an outage is not the moment to learn this.

## Security floor

- HTTPS everywhere, HTTP redirected at the web server, HSTS with a long `max-age`.
- Rate limiting on login, password reset, and every public form. Laravel's `throttle` middleware is one line and prevents the most common abuse.
- `canAccessPanel()` implemented on the User model. Without it Filament blocks the panel outside `local`, which surfaces as a 403 that only appears in production.
- Authorization through policies, which Filament respects automatically — not inline checks scattered through resources.
- `$fillable` or `$guarded` on every model. Mass assignment is the vulnerability that looks like convenience.
- Two-factor authentication on the admin panel if the data warrants it.
- Security headers: CSP, `X-Content-Type-Options`, `Referrer-Policy`. A restrictive CSP conflicts with Livewire and Alpine inline handlers, so test the panel after adding one rather than assuming.
- No `dd()`, `dump()`, `ray()`, or `Log::debug()` of request payloads left in the code.

## Observability

| Tool | Where |
|---|---|
| Horizon | production, if queues run on Redis — a queue with no dashboard is a queue nobody notices has stopped |
| Pulse | production — real-time performance and slow query visibility |
| Telescope | **staging only.** In production it stores every request and becomes both a performance problem and an information disclosure |
| Error tracking | production, always |

Also expose a health check. Laravel 11+ ships `/up`; point the platform's health probe at it so a broken deploy is caught by the platform rather than by a user.

## Performance, in diagnostic order

"Laravel is slow" is almost never PHP. Work through these before touching a runtime:

1. **N+1 queries.** Debugbar or Pulse; read the query count on every page. This is the cause the overwhelming majority of the time.
2. **Oversized Inertia props** — check the JSON in the `data-page="app"` script tag in page source. Trim, defer, paginate.
3. **Missing indexes** on foreign keys and sorted columns.
4. **Uncached repeated work.**
5. **Frontend bundle size** — code splitting.

Only after those are clean is the runtime the bottleneck. Recommending Octane or FrankenPHP for an unmeasured problem is guessing with extra steps; say so if it comes up.

## Deploy pipeline

The minimum that makes deploys boring:

```
1. CI: verify.sh --full, audit-ui.sh, phpstan, composer audit, npm audit
2. Build assets on CI, not on the production box
3. Deploy to a new release directory
4. php artisan migrate --force
5. Cache config, routes, views, events, filament
6. Switch the symlink
7. Restart queue workers  (php artisan queue:restart)
8. Health check /up; roll back if it fails
```

Step 7 is the one that gets forgotten. Workers hold the old code in memory until restarted, so a deploy without it runs new requests against old job handlers.

## Handover

Production readiness is not a checkbox on a report; it is a set of facts the user has to be able to act on. State plainly:

- Which items above are done, and which are not
- What the app needs from the user before it can go live — a domain, a mail provider, an error-tracking DSN, a queue worker
- What was deliberately left out and why
- Anything still failing

An app handed over as "production ready" when queues run on `sync` and there are no backups is not a small overstatement. It is the difference between a launch and an incident.
