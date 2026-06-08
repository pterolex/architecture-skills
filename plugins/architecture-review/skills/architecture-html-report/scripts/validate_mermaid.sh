#!/usr/bin/env bash
#
# validate_mermaid.sh — validate every Mermaid diagram in a directory.
#
# Usage:   ./validate_mermaid.sh [DIR]
#   DIR    directory containing *.mmd files, searched recursively
#          (default: ./diagrams)
#
# Exit code 0 only if EVERY diagram is valid. Non-zero otherwise, with the
# failing file and the parser error printed.
#
# Two engines, strongest first:
#   1. RENDER  — render each diagram to a throwaway SVG with the Mermaid CLI
#                (mmdc). Strongest check: catches everything the browser would.
#                Needs a headless Chromium (puppeteer downloads one on install).
#   2. PARSE   — if Chromium is unavailable (offline / locked-down sandbox),
#                fall back to mermaid.parse() via scripts/parse_check.mjs. No
#                browser needed; catches grammar/syntax errors (the vast
#                majority of defects).
#
# Either way, an invalid diagram fails the run with a readable error.

set -uo pipefail

DIR="${1:-diagrams}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${MMDC_HOME:-${HOME:-/tmp}/.cache/mermaid-validate}"
MERMAID_VERSION="${MERMAID_VERSION:-11.15.0}"
MERMAID_CLI_VERSION="${MERMAID_CLI_VERSION:-11.15.0}"
JSDOM_VERSION="${JSDOM_VERSION:-24.1.3}"
CLI_MARKER="$CACHE/.mermaid-cli-version"
PARSE_MARKER="$CACHE/.parse-deps-version"

if [ ! -d "$DIR" ]; then
  echo "ERROR: directory not found: $DIR" >&2
  exit 2
fi

files=()
while IFS= read -r f; do
  files+=("$f")
done < <(find "$DIR" -type f -name '*.mmd' | sort)
if [ ${#files[@]} -eq 0 ]; then
  echo "ERROR: no .mmd files found under $DIR" >&2
  exit 2
fi

mkdir -p "$CACHE"

# ----------------------------------------------------------------------------
# Resolve an mmdc binary (pinned cached local > fresh pinned local install).
# A local install into a writable prefix avoids the EACCES that `npm install -g`
# hits in sandboxes where /usr/lib is read-only.
# ----------------------------------------------------------------------------
MMDC=""
if [ -x "$CACHE/node_modules/.bin/mmdc" ] \
     && [ -f "$CLI_MARKER" ] \
     && [ "$(cat "$CLI_MARKER")" = "$MERMAID_CLI_VERSION" ]; then
  MMDC="$CACHE/node_modules/.bin/mmdc"
else
  echo "Installing @mermaid-js/mermaid-cli@$MERMAID_CLI_VERSION into $CACHE (one time)…" >&2
  if npm install --prefix "$CACHE" "@mermaid-js/mermaid-cli@$MERMAID_CLI_VERSION" >/tmp/mmdc_install.log 2>&1 \
     && [ -x "$CACHE/node_modules/.bin/mmdc" ]; then
    printf '%s' "$MERMAID_CLI_VERSION" > "$CLI_MARKER"
    MMDC="$CACHE/node_modules/.bin/mmdc"
  elif [ "${MMDC_ALLOW_GLOBAL:-0}" = "1" ] && command -v mmdc >/dev/null 2>&1; then
    echo "  (using global mmdc because MMDC_ALLOW_GLOBAL=1; version is not pinned)" >&2
    MMDC="mmdc"
  else
    echo "  (mermaid-cli unavailable — likely no Chromium/network. See /tmp/mmdc_install.log)" >&2
  fi
fi

# ----------------------------------------------------------------------------
# Engine 1: RENDER with mmdc. Probe with a trivial diagram first; if rendering
# fails (no Chromium), abandon this engine and fall back to PARSE.
# ----------------------------------------------------------------------------
run_render_engine() {
  local pcfg mcfg probe
  pcfg="$(mktemp /tmp/puppeteer.XXXXXX.json)"
  printf '{ "args": ["--no-sandbox","--disable-setuid-sandbox","--disable-gpu"] }' > "$pcfg"
  mcfg="$(mktemp /tmp/mermaid.XXXXXX.json)"
  printf '{ "theme":"default","securityLevel":"strict","maxTextSize":200000 }' > "$mcfg"

  # Probe: can mmdc actually render? (Chromium present and launchable?)
  probe="$(mktemp /tmp/probe.XXXXXX.mmd)"; printf 'flowchart TD\n  A-->B\n' > "$probe"
  if ! "$MMDC" -q -p "$pcfg" -c "$mcfg" -i "$probe" -o "${probe}.svg" >/tmp/mmdc_probe.log 2>&1; then
    rm -f "$pcfg" "$mcfg" "$probe" "${probe}.svg"
    return 99   # signal: render engine not usable
  fi
  rm -f "$probe" "${probe}.svg"

  local fail=0 pass=0 out err
  for f in "${files[@]}"; do
    out="$(mktemp /tmp/mmd_out.XXXXXX.svg)"
    if err="$("$MMDC" -q -p "$pcfg" -c "$mcfg" -i "$f" -o "$out" 2>&1)"; then
      echo "PASS  $f"; pass=$((pass+1))
    else
      echo "FAIL  $f" >&2; echo "$err" | sed 's/^/        /' >&2; fail=$((fail+1))
    fi
    rm -f "$out"
  done
  rm -f "$pcfg" "$mcfg"
  echo "------------------------------------------------------------"
  echo "Mermaid validation (render): $pass passed, $fail failed (of ${#files[@]})."
  [ "$fail" -eq 0 ]
}

# ----------------------------------------------------------------------------
# Engine 2: PARSE via scripts/parse_check.mjs (needs mermaid + jsdom locally).
# ----------------------------------------------------------------------------
run_parse_engine() {
  local parse_version="$MERMAID_VERSION+$JSDOM_VERSION"
  if [ ! -d "$CACHE/node_modules/mermaid" ] \
     || [ ! -d "$CACHE/node_modules/jsdom" ] \
     || [ ! -f "$PARSE_MARKER" ] \
     || [ "$(cat "$PARSE_MARKER")" != "$parse_version" ]; then
    echo "Installing mermaid@$MERMAID_VERSION + jsdom@$JSDOM_VERSION into $CACHE (one time, no browser needed)…" >&2
    if ! npm install --prefix "$CACHE" "mermaid@$MERMAID_VERSION" "jsdom@$JSDOM_VERSION" >/tmp/parse_install.log 2>&1; then
      echo "ERROR: could not install mermaid + jsdom (see /tmp/parse_install.log)." >&2
      echo "       No validation engine is available in this environment." >&2
      return 2
    fi
    printf '%s' "$parse_version" > "$PARSE_MARKER"
  fi
  # Resolve every diagram to an absolute path so it still resolves after we cd
  # into the cache dir.
  local abs=()
  local f
  for f in "${files[@]}"; do
    case "$f" in
      /*) abs+=("$f") ;;
      *)  abs+=("$PWD/$f") ;;
    esac
  done
  # Node resolves ESM bare imports (mermaid, jsdom) from the importing file's
  # own directory, not the cwd — so run a copy of the checker that lives next to
  # the cache's node_modules.
  cp -f "$SCRIPT_DIR/parse_check.mjs" "$CACHE/parse_check.mjs"
  ( cd "$CACHE" && node "$CACHE/parse_check.mjs" "${abs[@]}" )
}

# ----------------------------------------------------------------------------
# Drive: try render, fall back to parse.
# ----------------------------------------------------------------------------
if [ -n "$MMDC" ]; then
  run_render_engine
  rc=$?
  if [ "$rc" -ne 99 ]; then
    exit "$rc"
  fi
  echo "Chromium not available for rendering — falling back to parse-based validation." >&2
fi

run_parse_engine
exit $?
