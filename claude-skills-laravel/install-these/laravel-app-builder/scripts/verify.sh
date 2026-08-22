#!/usr/bin/env bash
# The gate the build loop runs after every slice.
# Run it from the PROJECT ROOT, not from the skill directory:
#   bash "$SKILL_DIR/scripts/verify.sh" [--full]
#
# Exits non-zero if anything failed, and names the first failure so the agent
# has exactly one thing to fix.

set -uo pipefail

FULL=false
for arg in "$@"; do
  case "$arg" in
    --full) FULL=true ;;
    *) printf 'unknown argument: %s (usage: verify.sh [--full])\n' "$arg" >&2; exit 2 ;;
  esac
done

[ -f artisan ] || { printf 'verify.sh must run from the Laravel project root (no ./artisan here)\n' >&2; exit 2; }

FAILED=()
step() { printf '\n\033[1;34m▸ %s\033[0m\n' "$*"; }
pass() { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m  ✗ %s\033[0m\n' "$*"; FAILED+=("$1"); }

SERVE_PID=""
cleanup() {
  [ -n "$SERVE_PID" ] || return 0
  # `php artisan serve` spawns `php -S` as a child; killing only the parent
  # orphans the child and leaves the port bound for the next run.
  pkill -P "$SERVE_PID" 2>/dev/null
  kill "$SERVE_PID" 2>/dev/null
  wait "$SERVE_PID" 2>/dev/null
  SERVE_PID=""
}
trap cleanup EXIT INT TERM

step "PHP syntax"
SCAN_DIRS=()
for d in app database routes tests; do [ -d "$d" ] && SCAN_DIRS+=("$d"); done
if [ "${#SCAN_DIRS[@]}" -eq 0 ]; then
  printf '  – nothing to scan\n'
else
  LINT_OUT="$(find "${SCAN_DIRS[@]}" -name '*.php' -print0 \
              | xargs -0 -r -n1 php -l 2>&1 | grep -v '^No syntax errors' || true)"
  if [ -n "$LINT_OUT" ]; then
    printf '%s\n' "$LINT_OUT" | head -20
    fail "php syntax"
  else
    pass "php syntax"
  fi
fi

step "Migrations"
if php artisan migrate:status >/dev/null 2>&1; then
  php artisan migrate --force 2>&1 | tail -20
  [ "${PIPESTATUS[0]}" -eq 0 ] && pass "migrations" || fail "migrations"
else
  php artisan migrate:status 2>&1 | tail -10
  fail "migrations (cannot reach database)"
fi

step "Routes resolve"
if php artisan route:list >/dev/null 2>&1; then
  pass "routes"
else
  php artisan route:list 2>&1 | tail -20
  fail "routes"
fi

step "Tests"
if [ -f vendor/bin/pest ] && [ -f tests/Pest.php ]; then
  vendor/bin/pest --compact 2>&1 | tail -40
  [ "${PIPESTATUS[0]}" -eq 0 ] && pass "pest" || fail "pest"
elif [ -f vendor/bin/phpunit ]; then
  vendor/bin/phpunit 2>&1 | tail -40
  [ "${PIPESTATUS[0]}" -eq 0 ] && pass "phpunit" || fail "phpunit"
else
  printf '  – no usable test runner (pest needs tests/Pest.php; run: vendor/bin/pest --init)\n'
fi

step "Frontend build"
if [ -f package.json ] && grep -q '"build"' package.json; then
  npm run build 2>&1 | tail -30
  [ "${PIPESTATUS[0]}" -eq 0 ] && pass "vite build" || fail "vite build"
else
  printf '  – no build script\n'
fi

if [ "$FULL" = true ]; then
  step "Static analysis (advisory)"
  if [ -f vendor/bin/phpstan ] && { [ -f phpstan.neon ] || [ -f phpstan.neon.dist ]; }; then
    vendor/bin/phpstan analyse --no-progress 2>&1 | tail -30 \
      || printf '  – phpstan reported issues (not blocking)\n'
  else
    printf '  – phpstan not configured (needs vendor/bin/phpstan and phpstan.neon)\n'
  fi

  step "Filament panel boots"
  if php artisan filament:optimize >/dev/null 2>&1; then
    pass "filament caches built"
  else
    php artisan filament:optimize 2>&1 | tail -20
    fail "filament optimize"
  fi

  step "Smoke: key routes return 2xx/3xx"
  if ! command -v curl >/dev/null 2>&1; then
    printf '  – curl not installed, skipping smoke test\n'
  else
    PORT="${VERIFY_PORT:-8899}"
    SERVE_LOG="$(mktemp)"
    php artisan serve --port="$PORT" >"$SERVE_LOG" 2>&1 &
    SERVE_PID=$!

    UP=false
    for _ in $(seq 1 30); do
      if curl -s -o /dev/null "http://127.0.0.1:${PORT}/" 2>/dev/null; then UP=true; break; fi
      kill -0 "$SERVE_PID" 2>/dev/null || break
      sleep 0.5
    done

    if [ "$UP" != true ]; then
      tail -20 "$SERVE_LOG"
      fail "dev server did not come up on port ${PORT}"
    else
      for path in "/" "/admin/login"; do
        CODE="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}${path}" || echo 000)"
        case "$CODE" in
          2*|3*) pass "GET ${path} → ${CODE}" ;;
          *)     fail "GET ${path} → ${CODE}" ;;
        esac
      done
    fi
    cleanup
    rm -f "$SERVE_LOG"
  fi
fi

printf '\n'
if [ "${#FAILED[@]}" -eq 0 ]; then
  printf '\033[1;32mVERIFY PASSED\033[0m\n'
  exit 0
fi
printf '\033[1;31mVERIFY FAILED:\033[0m %s\n' "${FAILED[*]}"
printf 'Fix the FIRST failure above, then re-run. Do not start the next slice.\n'
exit 1
