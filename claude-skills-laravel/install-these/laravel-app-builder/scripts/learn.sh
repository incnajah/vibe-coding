#!/usr/bin/env bash
# Promote build lessons from a project into the skill itself.
#
# Usage:
#   bash "$SKILL_DIR/scripts/learn.sh"           # report only — nothing is written
#   bash "$SKILL_DIR/scripts/learn.sh" --apply   # append staged lessons to the skill
#
# Run from the PROJECT ROOT. The flow is deliberately two-step:
#
#   docs/lessons.md          written automatically during the build, project-scoped
#   docs/lessons-promote.md  curated by the agent — only what generalises
#   references/learned.md    inside the skill; affects every future project
#
# The curation step is a judgement call and stays with the agent. This script
# only does the mechanical part: dedupe, enforce the cap, flag stale entries,
# and append. It never decides what is worth keeping.

set -uo pipefail

APPLY=false
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    *) printf 'unknown argument: %s (usage: learn.sh [--apply])\n' "$arg" >&2; exit 2 ;;
  esac
done

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEARNED="$SKILL_ROOT/references/learned.md"
LESSONS="docs/lessons.md"
STAGED="docs/lessons-promote.md"
CAP=40

h()    { printf '\n\033[1m%s\033[0m\n' "$*"; }
note() { printf '  %s\n' "$*"; }
warn() { printf '\033[1;33m  [!]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }

[ -f artisan ] || { printf 'learn.sh must run from the Laravel project root (no ./artisan here)\n' >&2; exit 2; }
[ -f "$LEARNED" ] || { printf 'skill reference not found: %s\n' "$LEARNED" >&2; exit 2; }

# Count real entries only: everything after the marker. The header carries a
# format template using the same heading level, which must not be counted.
entries() {
  [ -f "$1" ] || { echo 0; return; }
  # learned.md carries a format template above the marker; count only below it.
  # Project files have no marker, so count the whole file.
  awk '
    /<!-- entries-below -->/ { marker = 1; n = 0; next }
    /^## / { n++ }
    END { print n + 0 }
  ' "$1"
}

# --------------------------------------------------------------------- report
h "Lessons in this project"
if [ -f "$LESSONS" ]; then
  note "$(entries "$LESSONS") recorded in $LESSONS"
else
  note "no $LESSONS — nothing was recorded during this build"
fi

h "Staged for promotion"
STAGED_N="$(entries "$STAGED")"
if [ ! -f "$STAGED" ] || [ "$STAGED_N" -eq 0 ]; then
  note "nothing staged in $STAGED"
  note "the agent curates that file: only lessons that generalise beyond this project,"
  note "recurred or cost three or more fix cycles, and are not already covered."
else
  grep '^## ' "$STAGED" | sed 's/^## /  • /'
fi

h "Skill reference: $LEARNED"
LEARNED_N="$(entries "$LEARNED")"
note "$LEARNED_N of $CAP entries used"
if [ "$((LEARNED_N + STAGED_N))" -gt "$CAP" ]; then
  warn "promoting $STAGED_N would exceed the cap by $((LEARNED_N + STAGED_N - CAP))"
  warn "retire the weakest existing entries first — appending past the cap crowds out"
  warn "guidance already known to be good."
fi

# Duplicates: same heading text already present.
if [ "$STAGED_N" -gt 0 ]; then
  DUPES="$(comm -12 \
    <(grep '^## ' "$STAGED"  | sed 's/^## //' | sort -u) \
    <(grep '^## ' "$LEARNED" | sed 's/^## //' | sort -u) || true)"
  if [ -n "$DUPES" ]; then
    h "Already present — will be skipped"
    printf '%s\n' "$DUPES" | sed 's/^/  • /'
  fi
fi

# Version staleness. Entries may carry: <!-- applies: filament/filament:^4 -->
h "Stale entries"
STALE=0
while IFS= read -r line; do
  spec="${line#*applies:}"; spec="${spec%%-->*}"
  for pkg_ver in $spec; do
    pkg="${pkg_ver%%:*}"
    case "$pkg" in */*) ;; *) continue ;; esac
    # Presence, not version parsing: `composer show` colourises its output, so
    # matching on '^versions' silently never fires and every entry reads as stale.
    composer show "$pkg" >/dev/null 2>&1       || { warn "$pkg not installed — an entry still assumes it"; STALE=$((STALE+1)); }
  done
done < <(grep -h 'applies:' "$LEARNED" 2>/dev/null || true)
[ "$STALE" -eq 0 ] && ok "no entry references a package that is missing from this project"

# ---------------------------------------------------------------------- apply
if [ "$APPLY" != true ]; then
  h "Dry run"
  note "nothing was written. Re-run with --apply once the user has seen the diff above."
  note "writing to the skill changes behaviour for every future project."
  exit 0
fi

if [ "$STAGED_N" -eq 0 ]; then
  h "Nothing to apply"
  exit 0
fi

STAMP="$(date +%Y-%m-%d)"
PROJECT="$(basename "$(pwd)")"
NEW="$(mktemp)"

# Skip entries whose heading already exists in the skill reference.
awk -v learned="$LEARNED" '
  BEGIN { while ((getline l < learned) > 0) if (l ~ /^## /) { sub(/^## /, "", l); seen[l] = 1 } }
  /^## / { t = $0; sub(/^## /, "", t); skip = (t in seen) }
  !skip { print }
' "$STAGED" > "$NEW"

if ! grep -q '^## ' "$NEW"; then
  rm -f "$NEW"
  h "Nothing new to apply"
  note "every staged entry is already in the skill reference."
  exit 0
fi

{
  printf '\n<!-- promoted %s from project: %s -->\n' "$STAMP" "$PROJECT"
  cat "$NEW"
} >> "$LEARNED"
rm -f "$NEW"

: > "$STAGED"

h "Applied"
ok "appended to $LEARNED (now $(entries "$LEARNED") entries)"
ok "cleared $STAGED"
note "the skill directory changed — if it is under version control, commit it there."
