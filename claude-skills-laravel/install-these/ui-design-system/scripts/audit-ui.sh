#!/usr/bin/env bash
# Design system drift audit.
# Findings are ranked: HIGH breaks the system, MED erodes it, LOW is noise to know about.
# Exits 1 when there is at least one HIGH finding, so it can gate CI.
#
# Usage: bash audit-ui.sh [source-dir] [css-dir]
#   source-dir  default: resources/js
#   css-dir     default: resources/css

set -uo pipefail

SRC="${1:-resources/js}"
CSS_DIR="${2:-resources/css}"
[ -d "$SRC" ] || { echo "Source directory not found: $SRC"; exit 1; }

HIGH=0; MED=0; LOW=0
h()   { printf '\n\033[1m%s\033[0m\n' "$*"; }
hi()  { printf '\033[1;31m  HIGH \033[0m %s\n' "$*"; HIGH=$((HIGH+1)); }
me()  { printf '\033[1;33m  MED  \033[0m %s\n' "$*"; MED=$((MED+1)); }
lo()  { printf '\033[1;34m  LOW  \033[0m %s\n' "$*"; LOW=$((LOW+1)); }
okk() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

COMMON_PRUNE=(-not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/build/*'
              -not -name '*.d.ts' -not -name '*.test.*' -not -name '*.spec.*'
              -not -name '*.stories.*')

# All component sources.
find "$SRC" -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.ts' \) \
     "${COMMON_PRUNE[@]}" -print0 > "$TMP/all" 2>/dev/null

# Same, minus files that legitimately define raw values (the token layer itself).
find "$SRC" -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.ts' \) \
     "${COMMON_PRUNE[@]}" -not -iname '*token*' -not -iname '*theme*' -print0 > "$TMP/nontoken" 2>/dev/null

# Same, minus the primitive layer (where a raw <button> is correct).
find "$SRC" -type f \( -name '*.tsx' -o -name '*.jsx' \) \
     "${COMMON_PRUNE[@]}" -not -path '*/components/ui/*' -print0 > "$TMP/nonui" 2>/dev/null

nfiles() { tr -cd '\0' < "$1" | wc -c | tr -d ' '; }
[ "$(nfiles "$TMP/all")" -gt 0 ] || { echo "No component files found in $SRC"; exit 0; }

# grep over a NUL-delimited list. -r keeps grep from reading stdin (and hanging)
# when the list is empty; -0 keeps paths with spaces intact.
# -H is forced: xargs may hand grep a single file, and grep then omits the
# filename, producing findings the reader cannot locate.
gr() { local list="$1"; shift; xargs -0 -r grep -H "$@" < "$list" 2>/dev/null || true; }
count() { [ -z "$1" ] && echo 0 || printf '%s\n' "$1" | wc -l | tr -d ' '; }
show()  { printf '%s\n' "$1" | head -"$2" | sed 's/^/        /'; }

# ------------------------------------------------------------ raw color values
h "Color tokens"
HEX="$(gr "$TMP/nontoken" -nE '#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?\b')"
if [ -n "$HEX" ]; then
  hi "raw hex colors in components ($(count "$HEX") occurrences) — should be tokens"
  show "$HEX" 8
else
  okk "no raw hex in components"
fi

ARBCOLOR="$(gr "$TMP/all" -nE '(bg|text|border|ring|fill|stroke)-\[[^]]+\]')"
if [ -n "$ARBCOLOR" ]; then
  hi "arbitrary Tailwind colors ($(count "$ARBCOLOR")) — bypasses the palette"
  show "$ARBCOLOR" 6
else
  okk "no arbitrary color classes"
fi

INLINE="$(gr "$TMP/all" -nE 'style=\{\{[^}]*(color|background|border)')"
if [ -n "$INLINE" ]; then
  me "inline style colors ($(count "$INLINE"))"
  show "$INLINE" 4
else
  okk "no inline style colors"
fi

# ---------------------------------------------------------- spacing and sizing
h "Spacing and sizing scale"
ARBSPACE="$(gr "$TMP/all" -nE '\b[pm][xytrbl]?-\[[0-9.]+(px|rem)\]|\bgap-\[[^]]+\]')"
if [ -n "$ARBSPACE" ]; then
  me "arbitrary spacing values ($(count "$ARBSPACE")) — outside the scale"
  show "$ARBSPACE" 6
else
  okk "spacing stays on scale"
fi

ARBTEXT="$(gr "$TMP/all" -nE 'text-\[[0-9.]+(px|rem)\]')"
if [ -n "$ARBTEXT" ]; then
  me "hardcoded font sizes ($(count "$ARBTEXT"))"
  show "$ARBTEXT" 4
else
  okk "type stays on scale"
fi

ARBZ="$(gr "$TMP/all" -nE 'z-\[[0-9]+\]|zIndex:[[:space:]]*[0-9]{3,}')"
if [ -n "$ARBZ" ]; then
  me "arbitrary z-index ($(count "$ARBZ")) — stacking will fight itself"
  show "$ARBZ" 4
else
  okk "z-index controlled"
fi

# ---------------------------------------------------------------------- states
h "Interaction states"
gr "$TMP/all" -l 'focus:outline-none' | tr '\n' '\0' > "$TMP/nofocus_candidates"
NOFOCUS="$(xargs -0 -r grep -L 'focus-visible' < "$TMP/nofocus_candidates" 2>/dev/null || true)"
if [ -n "$NOFOCUS" ]; then
  hi "outline removed with no focus-visible replacement — keyboard users lose the app"
  show "$NOFOCUS" 6
else
  okk "focus states present where outlines are removed"
fi

DIVCLICK="$(gr "$TMP/all" -nE '<div[^>]*onClick')"
if [ -n "$DIVCLICK" ]; then
  hi "clickable <div> ($(count "$DIVCLICK")) — not keyboard reachable, use <button>"
  show "$DIVCLICK" 4
else
  okk "no clickable divs"
fi

RAWBTN="$(gr "$TMP/nonui" -nE '<button[^>]*className=')"
if [ -n "$RAWBTN" ]; then
  me "raw <button> outside ui/ ($(count "$RAWBTN")) — should use the Button primitive"
  show "$RAWBTN" 5
else
  okk "buttons go through the primitive"
fi

# Two-step instead of a PCRE lookahead: BSD grep (macOS) has no -P, and -E -P
# together is a hard error on GNU grep, which silently disabled this check before.
NOALT="$(gr "$TMP/all" -n '<img' | grep -v 'alt=' || true)"
if [ -n "$NOALT" ]; then
  me "<img> without alt ($(count "$NOALT"))"
  show "$NOALT" 4
else
  okk "images have alt"
fi

# ----------------------------------------------------------- duplicate components
h "Component duplication"
if [ -d "$SRC/components" ]; then
  # index.tsx / route-style barrel files repeat by design — excluding them keeps
  # this check from failing CI on a perfectly healthy tree.
  DUPES="$(find "$SRC/components" -type f -name '*.tsx' "${COMMON_PRUNE[@]}" \
             -not -iname 'index.tsx' -print 2>/dev/null \
           | sed -E 's#.*/##; s/\.tsx$//; s/(Primary|Secondary|Custom|New|Old|Simple|Base|Main|Alt)//g' \
           | tr 'A-Z' 'a-z' | sed '/^$/d' | sort | uniq -d || true)"
  if [ -n "$DUPES" ]; then
    hi "likely duplicate components — same job, multiple implementations:"
    show "$DUPES" 10
  else
    okk "no obvious duplicates"
  fi

  BTNFILES="$(find "$SRC/components" -type f -name '*.tsx' -iname '*button*' \
                "${COMMON_PRUNE[@]}" 2>/dev/null || true)"
  BTNLIKE="$(count "$BTNFILES")"
  if [ "$BTNLIKE" -gt 1 ]; then
    hi "$BTNLIKE button-like components — one Button with variants instead"
    show "$BTNFILES" 6
  else
    okk "one button component"
  fi
fi

# ----------------------------------------------------------------- token health
h "Token file"
if [ -d "$CSS_DIR" ] && grep -rq '@theme' "$CSS_DIR" 2>/dev/null; then
  # Unique token names, not occurrences — counting every var() reference again
  # inflated these numbers and made the "scale too wide" check meaningless.
  SPACES="$(grep -rhoE '\-\-spacing-[a-z0-9]+' "$CSS_DIR" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
  COLORS="$(grep -rhoE '\-\-color-[a-z0-9-]+' "$CSS_DIR" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
  okk "@theme found — $COLORS color tokens, $SPACES spacing tokens"
  [ "$SPACES" -gt 12 ] && lo "$SPACES spacing steps — a scale that wide stops constraining anything"
  if grep -rqE '\-\-color-(red|blue|green|gray|grey|yellow|orange|purple|pink)-' "$CSS_DIR" 2>/dev/null; then
    me "literal color names in tokens — use roles (primary, danger, surface) instead"
  fi
else
  hi "no @theme token block found in $CSS_DIR — there is no design system, only components"
fi

# -------------------------------------------------------------------- dark mode
h "Dark mode"
DARKC="$(gr "$TMP/all" -o 'dark:' | wc -l | tr -d ' ')"
if [ "$DARKC" -gt 20 ]; then
  me "$DARKC dark: classes in components — override tokens instead of branching per component"
elif [ "$DARKC" -gt 0 ]; then
  lo "$DARKC dark: classes — small enough to be fine"
else
  okk "no per-component dark branching"
fi

# ---------------------------------------------------------------------- summary
printf '\n\033[1m────────────────────────────────────────\033[0m\n'
printf 'HIGH %s   MED %s   LOW %s   (%s files scanned)\n' "$HIGH" "$MED" "$LOW" "$(nfiles "$TMP/all")"
if [ "$HIGH" -gt 0 ]; then
  printf '\033[1;31mFix HIGH findings before adding UI.\033[0m They are how the system stops being one.\n'
  exit 1
fi
if [ "$MED" -gt 0 ]; then
  printf '\033[1;33mNo blockers. MED findings erode consistency over time.\033[0m\n'
else
  printf '\033[1;32mDesign system intact.\033[0m\n'
fi
exit 0
