#!/usr/bin/env bash
# Production preflight for a Laravel + Filament + Inertia app.
# Run from the PROJECT ROOT:  bash "$SKILL_DIR/scripts/preflight-prod.sh"
#
# Checks only what can be established from the repository. Anything that lives
# on the server — cron, Supervisor, TLS, backups — is listed at the end as
# "cannot be checked from here" rather than silently assumed to be fine.
#
# Exit 1 if there is at least one BLOCKER.

set -uo pipefail

[ -f artisan ] || { printf 'preflight-prod.sh must run from the Laravel project root (no ./artisan here)\n' >&2; exit 2; }

BLOCK=0; WARN=0
h()     { printf '\n\033[1m%s\033[0m\n' "$*"; }
block() { printf '\033[1;31m  BLOCKER \033[0m %s\n' "$*"; BLOCK=$((BLOCK+1)); }
warn()  { printf '\033[1;33m  WARN    \033[0m %s\n' "$*"; WARN=$((WARN+1)); }
ok()    { printf '\033[1;32m  ok      \033[0m %s\n' "$*"; }
info()  { printf '  –       %s\n' "$*"; }

envval() { [ -f .env ] && grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'"'"' \r' || true; }

# ------------------------------------------------------------------ secrets
h "Secrets"
if [ -d .git ] && git ls-files --error-unmatch .env >/dev/null 2>&1; then
  block ".env is tracked by git — every credential in it is in the repository history"
else
  ok ".env is not tracked by git"
fi

if [ -f .env.example ]; then
  MISSING="$(comm -23 \
    <(grep -oE '^[A-Z0-9_]+=' .env         2>/dev/null | sort -u) \
    <(grep -oE '^[A-Z0-9_]+=' .env.example 2>/dev/null | sort -u) || true)"
  if [ -n "$MISSING" ]; then
    warn "keys in .env but not in .env.example — a deploy will start with them unset:"
    printf '%s\n' "$MISSING" | sed 's/^/            /' | head -10
  else
    ok ".env.example covers every key in .env"
  fi
else
  block "no .env.example — nothing tells a deploy which keys are required"
fi

[ -n "$(envval APP_KEY)" ] && ok "APP_KEY is set" || block "APP_KEY is empty — encryption and signed URLs are broken"

# -------------------------------------------------------------- environment
h "Environment"
DEBUG="$(envval APP_DEBUG)"
case "$DEBUG" in
  false|0) ok "APP_DEBUG=$DEBUG" ;;
  "")      warn "APP_DEBUG not set in .env — confirm it is false on the server" ;;
  *)       block "APP_DEBUG=$DEBUG — exception pages leak env vars, credentials and stack traces" ;;
esac

APP_ENV_V="$(envval APP_ENV)"
[ "$APP_ENV_V" = "production" ] && ok "APP_ENV=production" \
  || info "APP_ENV=${APP_ENV_V:-unset} locally — must be 'production' on the server"

APP_URL_V="$(envval APP_URL)"
case "$APP_URL_V" in
  https://*)                ok "APP_URL uses https" ;;
  ""|http://localhost*|http://127.0.0.1*) info "APP_URL=${APP_URL_V:-unset} — must be the real https URL in production" ;;
  http://*)                 warn "APP_URL is http — signed URLs and password resets will point at http" ;;
esac

# ------------------------------------------------------------------- queues
h "Queues and scheduling"
Q="$(envval QUEUE_CONNECTION)"
case "$Q" in
  sync|"") block "QUEUE_CONNECTION=${Q:-sync} — jobs run inside the request; a failure takes the page down with it" ;;
  *)       ok "QUEUE_CONNECTION=$Q" ;;
esac

if ls database/migrations/*failed_jobs* >/dev/null 2>&1 || \
   grep -rqs 'failed_jobs' database/migrations 2>/dev/null; then
  ok "failed_jobs table migration present"
else
  warn "no failed_jobs migration — failed jobs vanish instead of being recoverable"
fi

grep -rqs 'Schedule::\|->command(' routes/console.php app/Console 2>/dev/null \
  && info "scheduled tasks defined — the server needs a cron entry running 'schedule:run' every minute" \
  || ok "no scheduled tasks to wire up"

# ----------------------------------------------------- sessions and storage
h "Sessions, cache, storage"
S="$(envval SESSION_DRIVER)"
case "$S" in
  file|"") warn "SESSION_DRIVER=${S:-file} — breaks as random logouts the moment there is a second server" ;;
  *)       ok "SESSION_DRIVER=$S" ;;
esac

if grep -rqs 'Storage::\|->disk(\|FileUpload\|SpatieMediaLibrary' app 2>/dev/null; then
  [ -e public/storage ] && ok "public/storage symlink exists" \
    || warn "the app stores files but public/storage is missing — run 'php artisan storage:link' on deploy"
fi

# ----------------------------------------------------------------- security
h "Security"
if [ -f app/Models/User.php ]; then
  grep -q 'canAccessPanel' app/Models/User.php \
    && ok "canAccessPanel() implemented on User" \
    || block "canAccessPanel() missing on User — Filament returns 403 outside the local environment"
fi

UNGUARDED=""
for m in app/Models/*.php; do
  [ -f "$m" ] || continue
  case "$(basename "$m")" in User.php) continue ;; esac
  grep -qE '\$fillable|\$guarded' "$m" || UNGUARDED="$UNGUARDED $(basename "$m" .php)"
done
[ -n "$UNGUARDED" ] && warn "models with neither \$fillable nor \$guarded:$UNGUARDED" \
                    || ok "models declare mass-assignment rules"

grep -rqs 'throttle' routes bootstrap/app.php 2>/dev/null \
  && ok "rate limiting present in routes or middleware" \
  || warn "no 'throttle' middleware found — login and public forms are unprotected against abuse"

DEBUGCALLS="$(grep -rnE '(^|[^a-zA-Z_>])(dd|dump|ray|var_dump)\(' app routes 2>/dev/null | grep -v '//' || true)"
[ -n "$DEBUGCALLS" ] && { warn "debug calls left in the code ($(printf '%s\n' "$DEBUGCALLS" | wc -l | tr -d ' ')):"; printf '%s\n' "$DEBUGCALLS" | head -5 | sed 's/^/            /'; } \
                     || ok "no dd/dump/ray left in app or routes"

ENVCALLS="$(grep -rn 'env(' app routes 2>/dev/null | grep -v '//' || true)"
[ -n "$ENVCALLS" ] && { warn "env() called outside config/ ($(printf '%s\n' "$ENVCALLS" | wc -l | tr -d ' ')) — returns null once config is cached, so this breaks only in production:"; printf '%s\n' "$ENVCALLS" | head -5 | sed 's/^/            /'; } \
                   || ok "env() is only read from config files"

if grep -rqs 'TelescopeServiceProvider' bootstrap/providers.php config/app.php 2>/dev/null; then
  grep -rqs "environment('local')\|isLocal()" app/Providers/TelescopeServiceProvider.php 2>/dev/null \
    && ok "Telescope is environment-guarded" \
    || block "Telescope registered without an environment guard — it records every request in production"
fi

# ------------------------------------------------------------- observability
h "Observability"
grep -rqs 'sentry\|bugsnag\|flare\|honeybadger' composer.json 2>/dev/null \
  && ok "an error tracker is installed" \
  || warn "no error tracker — a log file on a server nobody reads is not error tracking"

grep -rqs "health:" bootstrap/app.php 2>/dev/null \
  && ok "health check route configured" \
  || info "no health check found — Laravel 11+ exposes '/up' via withRouting(health: '/up')"

# ------------------------------------------------------------ dependencies
h "Dependencies"
if command -v composer >/dev/null 2>&1; then
  composer audit --no-interaction --format=plain >/dev/null 2>&1 \
    && ok "composer audit clean" \
    || warn "composer audit reported advisories — run 'composer audit' for detail"
fi

# ---------------------------------------------------------------- summary
h "Cannot be checked from here"
info "TLS/HSTS at the web server, cron running schedule:run, Supervisor keeping workers alive,"
info "offsite backups AND a restore that has actually been tested, secrets in the platform's"
info "secret store. Confirm each with the user — do not report them as done."

printf '\n\033[1m────────────────────────────────────────\033[0m\n'
printf 'BLOCKERS %s   WARNINGS %s\n' "$BLOCK" "$WARN"
if [ "$BLOCK" -gt 0 ]; then
  printf '\033[1;31mNot ready for production.\033[0m Fix the blockers before telling anyone it is live.\n'
  exit 1
fi
[ "$WARN" -gt 0 ] && printf '\033[1;33mNo blockers, but the warnings are how apps fail quietly.\033[0m\n' \
                  || printf '\033[1;32mRepository-side checks pass. The server-side list above is still yours to confirm.\033[0m\n'
exit 0
