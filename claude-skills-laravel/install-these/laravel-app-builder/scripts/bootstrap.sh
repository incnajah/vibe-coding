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
  composer create-project laravel/laravel "$PROJECT" || exit 1
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
composer require filament/filament spatie/laravel-medialibrary inertiajs/inertia-laravel tightenco/ziggy \
  || warn "composer require partially failed — check the output above before continuing"
composer require --dev --with-all-dependencies \
  laravel/boost pestphp/pest pestphp/pest-plugin-laravel larastan/larastan barryvdh/laravel-debugbar \
  || warn "dev packages partially failed"

log "Installing Filament panel"
php artisan filament:install --panels --no-interaction || warn "filament:install needs manual attention"

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
npm install -D @vitejs/plugin-react typescript @types/react @types/react-dom \
  tailwindcss @tailwindcss/vite || warn "npm dev install failed"

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
    progress: { color: '#4B5563' },
})
APP
  ok "resources/js/app.tsx created"
fi

if [ ! -f resources/css/app.css ] || ! grep -q '@import "tailwindcss"' resources/css/app.css; then
  cat > resources/css/app.css <<'CSS'
@import "tailwindcss";

@source "../views/**/*.blade.php";
@source "../js/**/*.{ts,tsx}";

/* Design tokens belong here. Define them with the `ui-design-system` skill
   before building components — semantic roles, not literal color names. */
CSS
  ok "resources/css/app.css created"
fi

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
if [ -f vendor/bin/pest ] && [ ! -f tests/Pest.php ]; then
  vendor/bin/pest --init >/dev/null 2>&1 && ok "pest initialised" \
    || warn "pest --init failed — vendor/bin/pest will not run until tests/Pest.php exists"
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

# ---------------------------------------------------------------------- MCP
log "Registering MCP servers"

# Laravel Boost: exposes schema, models, routes, artisan, tinker, browser logs,
# and semantic search over Laravel ecosystem docs. Highest-value server here.
if php artisan list 2>/dev/null | grep -q 'boost:install'; then
  # Never fall back to the interactive form — it hangs an autonomous loop.
  if php artisan boost:install --no-interaction >/dev/null 2>&1; then
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
