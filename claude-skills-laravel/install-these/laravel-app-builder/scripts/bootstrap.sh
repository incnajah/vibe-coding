#!/usr/bin/env bash
# Bootstrap a Laravel + Filament + Inertia React project and register MCP servers.
# Idempotent: safe to re-run on an existing project.
#
# Usage:
#   bash "$SKILL_DIR/scripts/bootstrap.sh" [project-name]
#
# Run it from the directory that should CONTAIN the new project, or from inside
# an existing Laravel project (it then only adds what is missing).
#
# On success the last line is:  PROJECT_ROOT=<absolute path>
# cd there before running anything else — this script cannot change the caller's
# working directory.

set -uo pipefail

# Every child inherits EOF on stdin. Any tool that decides to prompt then fails
# immediately instead of hanging forever, which is the difference between a
# visible error and an autonomous run that stops dead with no output.
exec </dev/null

PROJECT="${1:-}"
log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ok]\033[0m %s\n' "$*"; }

DEGRADED=()
degrade() { DEGRADED+=("$1"); }

# ---------------------------------------------------------------- preflight
log "Checking prerequisites"
MISSING=()
for bin in php composer node npm; do
  command -v "$bin" >/dev/null 2>&1 || MISSING+=("$bin")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
  warn "missing required tools: ${MISSING[*]}"
  warn "install all of them before re-running — this script does not partially proceed"
  exit 1
fi
php -r 'exit(version_compare(PHP_VERSION, "8.2.0", ">=") ? 0 : 1);' \
  || { warn "PHP 8.2+ required, found $(php -r 'echo PHP_VERSION;')"; exit 1; }
command -v git >/dev/null 2>&1 || degrade "git: no per-slice commits, so no rollback points"
ok "php $(php -r 'echo PHP_VERSION;') / node $(node -v)"

# ------------------------------------------------------------ laravel install
if [ -f artisan ]; then
  log "Existing Laravel project detected — skipping scaffold"
else
  [ -n "$PROJECT" ] || { warn "no artisan found and no project name given"; exit 1; }
  log "Creating Laravel project: $PROJECT"
  composer create-project --no-interaction laravel/laravel "$PROJECT" || exit 1
  cd "$PROJECT" || exit 1
fi
PROJECT_ROOT="$(pwd)"

[ -f .env ] || { cp .env.example .env && php artisan key:generate; }

# Default to sqlite so the build loop never blocks on DB credentials.
log "Configuring sqlite for local development"
mkdir -p database
[ -f database/database.sqlite ] || touch database/database.sqlite
if grep -q '^DB_CONNECTION=sqlite' .env 2>/dev/null; then
  ok "sqlite already selected in .env"
else
  sed -i.bak 's/^DB_CONNECTION=.*/DB_CONNECTION=sqlite/' .env && rm -f .env.bak
  sed -i.bak '/^DB_HOST=/d;/^DB_PORT=/d;/^DB_DATABASE=/d;/^DB_USERNAME=/d;/^DB_PASSWORD=/d' .env && rm -f .env.bak
fi

# ------------------------------------------------------------------ packages
log "Installing composer packages"
composer require --no-interaction filament/filament spatie/laravel-medialibrary inertiajs/inertia-laravel tightenco/ziggy \
  || warn "composer require partially failed — check the output above before continuing"
composer require --dev --no-interaction --with-all-dependencies \
  laravel/boost pestphp/pest pestphp/pest-plugin-laravel larastan/larastan barryvdh/laravel-debugbar \
  || warn "dev packages partially failed"

log "Installing Filament panel"
php artisan filament:install --panels --no-interaction || warn "filament:install needs manual attention"

# Filament v5's generated panel provider does not call ->login(), so a fresh
# panel has no login page at all: /admin/login is a 404 and nobody can get in.
PANELPATCH="$(mktemp)"
cat > "$PANELPATCH" <<'PHP'
<?php
$f = 'app/Providers/Filament/AdminPanelProvider.php';
if (!is_file($f)) { exit(4); }
$s = file_get_contents($f);
if (preg_match('/->login\(/', $s)) { exit(0); }
$new = preg_replace('/(->path\(\s*[\'"][^\'"]*[\'"]\s*\))/', "$1\n            ->login()", $s, 1, $c);
if ($c !== 1) { exit(3); }
file_put_contents($f, $new);
exit(0);
PHP
case "$(php "$PANELPATCH" >/dev/null 2>&1; echo $?)" in
  0) ok "admin panel login enabled" ;;
  4) warn "no AdminPanelProvider found — is the Filament panel installed?" ;;
  *) warn "could not enable ->login() on the admin panel; add it to AdminPanelProvider manually" ;;
esac
rm -f "$PANELPATCH"

# Filament scaffolds the dashboard with AccountWidget ("Welcome, Admin" + a sign
# out button that already exists in the menu) and FilamentInfoWidget (Filament's
# logo, version, and links to its own docs). Neither says anything about the
# client's data, and a panel opening on them reads as unfinished work.
WIDGETPATCH="$(mktemp)"
cat > "$WIDGETPATCH" <<'PHP'
<?php
$f = 'app/Providers/Filament/AdminPanelProvider.php';
if (!is_file($f)) { exit(4); }
$s = $orig = file_get_contents($f);
foreach (['AccountWidget', 'FilamentInfoWidget'] as $w) {
    $s = str_replace("use Filament\\Widgets\\{$w};\n", '', $s);
    $s = preg_replace('/^\s*'.$w.'::class,\s*\n/m', '', $s);
}
if ($s === $orig) { exit(0); }
if (!is_string($s)) { exit(3); }          // preg_replace returns null on failure
if (trim($s) === '') { exit(3); }         // never write an empty provider
file_put_contents($f, $s);
exit(5);
PHP
case "$(php "$WIDGETPATCH" >/dev/null 2>&1; echo $?)" in
  0) ok "no stock Filament widgets to remove" ;;
  5) ok "removed Filament's stock dashboard widgets — build real ones" ;;
  4) : ;;
  *) warn "could not remove the stock widgets; delete AccountWidget and FilamentInfoWidget from AdminPanelProvider yourself" ;;
esac
rm -f "$WIDGETPATCH"

log "Publishing media library migrations"
php artisan vendor:publish --tag=medialibrary-migrations --no-interaction >/dev/null 2>&1 \
  || warn "medialibrary migrations not published — the media table will be missing"

# ------------------------------------------------------- inertia server side
log "Wiring Inertia (server side)"
[ -f app/Http/Middleware/HandleInertiaRequests.php ] \
  || php artisan inertia:middleware --no-interaction >/dev/null 2>&1 \
  || warn "inertia:middleware failed"

# Register the middleware in bootstrap/app.php. Done in PHP because the exact
# shape of that file changes between Laravel minors and sed guesses badly.
PATCH="$(mktemp)"
cat > "$PATCH" <<'PHP'
<?php
$f = 'bootstrap/app.php';
if (!is_file($f)) { fwrite(STDERR, "no bootstrap/app.php\n"); exit(2); }
$s = file_get_contents($f);
if (str_contains($s, 'HandleInertiaRequests')) { exit(0); }
$add = "\n        \$middleware->web(append: [\n"
     . "            \\App\\Http\\Middleware\\HandleInertiaRequests::class,\n"
     . "        ]);\n";
$new = preg_replace(
    '/(->withMiddleware\(\s*function\s*\(\s*Middleware\s+\$middleware\s*\)[^{]*\{)/',
    '$1' . $add,
    $s,
    1,
    $count
);
if ($count !== 1) { fwrite(STDERR, "could not locate withMiddleware closure\n"); exit(3); }
file_put_contents($f, $new);
exit(0);
PHP
php "$PATCH" \
  && ok "HandleInertiaRequests registered" \
  || warn "register \\App\\Http\\Middleware\\HandleInertiaRequests::class in bootstrap/app.php manually"
rm -f "$PATCH"

if [ ! -f resources/views/app.blade.php ]; then
  cat > resources/views/app.blade.php <<'BLADE'
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" class="h-full">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title inertia>{{ config('app.name') }}</title>
    @routes
    @viteReactRefresh
    @vite(['resources/css/app.css', 'resources/js/app.tsx'])
    @inertiaHead
</head>
<body class="h-full antialiased">
    @inertia
</body>
</html>
BLADE
  ok "resources/views/app.blade.php created"
fi

# ------------------------------------------------------ inertia client side
log "Wiring Inertia + React + Tailwind (client side)"
npm install @inertiajs/react react react-dom ziggy-js || warn "npm install failed"

# The Laravel skeleton pins a vite major, and the newest @vitejs/plugin-react
# usually requires the *next* one. npm fails the entire `install -D` on that peer
# conflict, which silently takes typescript and tailwind down with it — the build
# then fails much later, far from the cause. Pick the newest plugin release whose
# peer range accepts the vite that is actually installed.
REACT_PLUGIN="@vitejs/plugin-react"
VITE_MAJOR="$(node -p "require('./node_modules/vite/package.json').version.split('.')[0]" 2>/dev/null)"
[ -n "$VITE_MAJOR" ] || VITE_MAJOR="$(node -p "((require('./package.json').devDependencies||{}).vite||'').replace(/[^0-9.]/g,'').split('.')[0]" 2>/dev/null)"
if [ -n "$VITE_MAJOR" ]; then
  PICKED="$(npm view "@vitejs/plugin-react@>=4" --json version peerDependencies.vite 2>/dev/null \
    | node -e '
        let s = "";
        process.stdin.on("data", d => (s += d)).on("end", () => {
          const want = "^" + process.argv[1] + ".";
          let list;
          try { list = JSON.parse(s) } catch { return }
          if (!Array.isArray(list)) list = [list];
          const ok = list.filter(v => String(v["peerDependencies.vite"] || "").includes(want));
          if (ok.length) process.stdout.write(ok[ok.length - 1].version);
        })' "$VITE_MAJOR" 2>/dev/null)"
  [ -n "$PICKED" ] && REACT_PLUGIN="@vitejs/plugin-react@$PICKED"
fi
ok "react plugin: ${REACT_PLUGIN} (vite major ${VITE_MAJOR:-unknown})"

DEV_PKGS=("$REACT_PLUGIN" typescript @types/react @types/react-dom tailwindcss @tailwindcss/vite)
if ! npm install -D "${DEV_PKGS[@]}"; then
  warn "batch dev install failed — retrying one package at a time so one bad peer does not block the rest"
  for pkg in "${DEV_PKGS[@]}"; do
    npm install -D "$pkg" >/dev/null 2>&1 || warn "npm install -D $pkg failed"
  done
fi

mkdir -p resources/js/Pages resources/js/Layouts resources/js/components/ui \
         resources/js/lib resources/css

# Vite resolves vite.config.js before vite.config.ts, so patch the .js the
# skeleton ships rather than adding a second config that never loads.
if [ -f vite.config.js ] && grep -q '@vitejs/plugin-react' vite.config.js; then
  ok "vite config already wired for react"
else
  [ -f vite.config.js ] && cp vite.config.js vite.config.js.orig
  rm -f vite.config.ts
  cat > vite.config.js <<'VITE'
import { defineConfig } from 'vite'
import laravel from 'laravel-vite-plugin'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.tsx'],
            refresh: true,
        }),
        react(),
        tailwindcss(),
    ],
    resolve: {
        alias: { '@': '/resources/js' },
    },
})
VITE
  ok "vite.config.js wired (previous version kept as vite.config.js.orig)"
fi

if [ ! -f resources/js/app.tsx ]; then
  cat > resources/js/app.tsx <<'APP'
import { createInertiaApp } from '@inertiajs/react'
import { createRoot } from 'react-dom/client'

const appName = import.meta.env.VITE_APP_NAME || 'Laravel'

createInertiaApp({
    title: (title) => (title ? `${title} · ${appName}` : appName),
    resolve: (name) => {
        const pages = import.meta.glob('./Pages/**/*.tsx', { eager: true })
        const page = pages[`./Pages/${name}.tsx`]
        if (!page) throw new Error(`Inertia page not found: ./Pages/${name}.tsx`)
        return page
    },
    setup({ el, App, props }) {
        createRoot(el).render(<App {...props} />)
    },
    // A token, not a hex. audit-ui.sh flags raw hex as HIGH, and a bootstrap that
    // violates the design system it ships is a bad first commit.
    progress: { color: 'var(--color-primary)' },
})
APP
  ok "resources/js/app.tsx created"
fi

if [ ! -f resources/css/app.css ] || ! grep -q '@import "tailwindcss"' resources/css/app.css; then
  cat > resources/css/app.css <<'CSS'
@import "tailwindcss";

@source "../views/**/*.blade.php";
@source "../js/**/*.{ts,tsx}";

/* Starting token set — semantic roles, not literal colour names, so a rebrand
   touches this block and nothing else. Replace the values once the visual
   direction is decided; keep the names. Guidance: the `ui-design-system` skill. */
@theme {
  --color-surface:        oklch(1 0 0);
  --color-surface-muted:  oklch(0.97 0.005 260);
  --color-border:         oklch(0.92 0.006 260);
  --color-content:        oklch(0.22 0.01 260);
  --color-content-muted:  oklch(0.55 0.015 260);
  --color-primary:        oklch(0.55 0.18 255);
  --color-primary-fg:     oklch(0.99 0 0);
  --color-danger:         oklch(0.58 0.20 25);

  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
}
CSS
  ok "resources/css/app.css created"
fi

# The skeleton's welcome.blade.php loads `resources/js/app.js`, which this script
# just stopped building when it switched the Vite entry to app.tsx. Left alone the
# homepage 500s with "Unable to locate file in Vite manifest" and the default test
# fails. Point the root route at a real Inertia page instead — that also proves the
# whole stack works before a single feature is built.
if [ ! -f resources/js/Pages/Welcome.tsx ]; then
  mkdir -p resources/js/Pages
  cat > resources/js/Pages/Welcome.tsx <<'WELCOME'
import { Head } from '@inertiajs/react'

export default function Welcome() {
    return (
        <>
            <Head title="Welcome" />
            <main className="min-h-screen bg-surface text-content flex items-center justify-center p-8">
                <div className="max-w-prose space-y-3 text-center">
                    <h1 className="text-2xl font-semibold">Inertia is wired up</h1>
                    <p className="text-content-muted">
                        Laravel, Filament, React and Tailwind are installed and talking to each
                        other. Replace this page once the first slice is built.
                    </p>
                </div>
            </main>
        </>
    )
}
WELCOME
  ok "resources/js/Pages/Welcome.tsx created"
fi

ROUTEPATCH="$(mktemp)"
cat > "$ROUTEPATCH" <<'PHP'
<?php
$f = 'routes/web.php';
if (!is_file($f)) { exit(0); }
$s = file_get_contents($f);
if (str_contains($s, "Inertia::render('Welcome')")) { exit(0); }
if (!str_contains($s, "view('welcome')")) { exit(4); }  // already customised — leave it alone
$s = str_replace("view('welcome')", "Inertia::render('Welcome')", $s);
if (!str_contains($s, 'use Inertia\Inertia;')) {
    $s = preg_replace('/^(<\?php\s*\n)/', "$1\nuse Inertia\\Inertia;\n", $s, 1);
}
file_put_contents($f, $s);
exit(0);
PHP
case "$(php "$ROUTEPATCH" >/dev/null 2>&1; echo $?)" in
  0) ok "root route renders the Inertia Welcome page" ;;
  4) ok "routes/web.php already customised — left untouched" ;;
  *) warn "could not point '/' at an Inertia page; welcome.blade.php still loads app.js and will 500" ;;
esac
rm -f "$ROUTEPATCH"

if [ ! -f tsconfig.json ]; then
  cat > tsconfig.json <<'TSCONFIG'
{
    "compilerOptions": {
        "target": "ESNext",
        "module": "ESNext",
        "moduleResolution": "bundler",
        "jsx": "react-jsx",
        "lib": ["DOM", "DOM.Iterable", "ESNext"],
        "strict": true,
        "noEmit": true,
        "allowJs": true,
        "esModuleInterop": true,
        "skipLibCheck": true,
        "isolatedModules": true,
        "resolveJsonModule": true,
        "types": ["vite/client"],
        "baseUrl": ".",
        "paths": { "@/*": ["resources/js/*"] }
    },
    "include": ["resources/js/**/*.ts", "resources/js/**/*.tsx", "resources/js/**/*.d.ts"]
}
TSCONFIG
  ok "tsconfig.json created"
fi

# ------------------------------------------------------------- test + static
log "Configuring test and analysis tooling"
# `vendor/bin/pest --init` prompts, and a prompt in an autonomous run is a hang.
# tests/Pest.php is three lines and fully determined by the Laravel skeleton, so
# write it rather than asking a wizard for it.
if [ -f vendor/bin/pest ] && [ ! -f tests/Pest.php ]; then
  mkdir -p tests
  cat > tests/Pest.php <<'PEST'
<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

uses(TestCase::class, RefreshDatabase::class)->in('Feature');
PEST
  ok "tests/Pest.php created"
fi

# The skeleton's Feature/ExampleTest is a PHPUnit class, so Pest's
# uses(...)->in('Feature') binding does not reach it and it never gets
# RefreshDatabase. It passes on an empty app and fails the moment the homepage
# touches the database — a red suite caused by scaffolding, not by your code.
if [ -f tests/Feature/ExampleTest.php ] && grep -q 'class ExampleTest' tests/Feature/ExampleTest.php; then
  cat > tests/Feature/ExampleTest.php <<'PEST'
<?php

it('serves the homepage', function () {
    $this->get('/')->assertOk();
});
PEST
  ok "stock Feature/ExampleTest converted to Pest so it picks up RefreshDatabase"
fi

if [ ! -f phpstan.neon ] && [ ! -f phpstan.neon.dist ]; then
  cat > phpstan.neon <<'NEON'
includes:
    - vendor/larastan/larastan/extension.neon

parameters:
    paths:
        - app
    level: 5
NEON
  ok "phpstan.neon created (level 5)"
fi

# ------------------------------------------------------------- composer dev
# `composer run dev` runs concurrently with --kill-others, and one of its four
# processes is `php artisan pail`, which requires the pcntl extension. pcntl does
# not exist on Windows, so pail dies on startup and takes the server and Vite
# down with it — the whole dev loop is unusable, and the error is buried under a
# stack trace from a log viewer nobody asked for.
log "Checking the dev script"
DEVPATCH="$(mktemp)"
cat > "$DEVPATCH" <<'PHP'
<?php
if (extension_loaded('pcntl')) { exit(0); }
$f = 'composer.json';
if (!is_file($f)) { exit(4); }
$j = json_decode(file_get_contents($f), true);
if (!isset($j['scripts']['dev']) || !is_array($j['scripts']['dev'])) { exit(4); }
$changed = false;
foreach ($j['scripts']['dev'] as $i => $line) {
    if (!is_string($line) || !str_contains($line, 'pail')) { continue; }
    $line = preg_replace('/\s*"php artisan pail[^"]*"/', '', $line);
    $line = preg_replace('/--names=[^\s]*/', '', $line);
    $j['scripts']['dev'][$i] = trim(preg_replace('/\s+/', ' ', $line)).' --names=server,queue,vite';
    $changed = true;
}
if (!$changed) { exit(0); }
file_put_contents($f, json_encode($j, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)."\n");
exit(5);
PHP
case "$(php "$DEVPATCH" >/dev/null 2>&1; echo $?)" in
  0) ok "composer run dev is usable as-is" ;;
  5) ok "removed 'artisan pail' from composer run dev (no pcntl on this platform)" ;;
  *) warn "could not inspect composer.json's dev script" ;;
esac
rm -f "$DEVPATCH"

# ---------------------------------------------------------------------- MCP
log "Registering MCP servers"

# Laravel Boost: exposes schema, models, routes, artisan, tinker, browser logs,
# and semantic search over Laravel ecosystem docs. Highest-value server here.
if php artisan list 2>/dev/null | grep -q 'boost:install'; then
  # Never fall back to the interactive form — it hangs an autonomous loop.
  if php artisan boost:install --no-interaction </dev/null >/dev/null 2>&1; then
    ok "laravel-boost installed"
  else
    warn "boost:install needs interactive input — run 'php artisan boost:install' yourself"
    degrade "laravel-boost: not fully installed; verify APIs against docs, not the live app"
  fi
else
  warn "laravel/boost not available"
  degrade "laravel-boost: agent cannot introspect the live app; verify APIs against docs instead"
fi

if command -v claude >/dev/null 2>&1; then
  MCP_LIST="$(claude mcp list 2>/dev/null || true)"

  if printf '%s' "$MCP_LIST" | grep -q laravel-boost; then
    ok "laravel-boost MCP already registered"
  elif claude mcp add -s local -t stdio laravel-boost -- php artisan boost:mcp >/dev/null 2>&1; then
    ok "laravel-boost MCP registered"
  else
    warn "could not register laravel-boost with the claude cli"
    degrade "laravel-boost MCP: no live schema/route/tinker access from the agent"
  fi

  # Playwright: closes the verification loop with a real browser.
  if printf '%s' "$MCP_LIST" | grep -q playwright; then
    ok "playwright MCP already registered"
  elif claude mcp add playwright -- npx @playwright/mcp@latest >/dev/null 2>&1; then
    ok "playwright MCP registered"
  else
    warn "could not register playwright"
    degrade "playwright: no real-browser verification; tests only"
  fi
  printf '  run '\''claude mcp list'\'' to confirm\n'
else
  warn "claude CLI not found — MCP servers not registered"
  degrade "playwright: no real-browser verification; tests only"
  degrade "laravel-boost MCP: no live schema/route/tinker access from the agent"
fi

# --------------------------------------------------------------- project dirs
log "Creating project structure"
mkdir -p app/Actions app/Queries docs tests/Feature tests/Unit

php artisan migrate --force 2>&1 | tail -5 || warn "initial migrate failed"

# ---------------------------------------------------------------------- git
if command -v git >/dev/null 2>&1; then
  if [ -d .git ]; then
    ok "git repository already initialised"
  else
    log "Initialising git (the build loop commits one slice at a time)"
    git init -q \
      && git add -A \
      && git -c user.name="${GIT_AUTHOR_NAME:-bootstrap}" \
             -c user.email="${GIT_AUTHOR_EMAIL:-bootstrap@localhost}" \
             commit -qm "chore: bootstrap Laravel + Filament + Inertia React" \
      && ok "initial commit created" \
      || warn "git init/commit failed — per-slice commits will not work"
  fi
fi

# ------------------------------------------------------------------- summary
log "Bootstrap complete"
php artisan --version
composer show filament/filament 2>/dev/null | grep -m1 versions || true

if [ "${#DEGRADED[@]}" -gt 0 ]; then
  printf '\n\033[1;33mDegraded capabilities:\033[0m\n'
  for d in "${DEGRADED[@]}"; do printf '  - %s\n' "$d"; done
  printf '\nThe build can proceed, but report these to the user.\n'
fi

printf '\nNext: shadcn/ui is not installed yet (its init is interactive).\n'
printf 'Run it once from the project root before building components:\n'
printf '  npx shadcn@latest init\n'
printf '\nPROJECT_ROOT=%s\n' "$PROJECT_ROOT"
