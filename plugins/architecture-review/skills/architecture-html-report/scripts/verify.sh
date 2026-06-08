#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/architecture-html-report-verify.$$"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/cache/node_modules/.bin" "$TMP/out"
printf '%s' '11.15.0' > "$TMP/cache/.mermaid-cli-version"

cat > "$TMP/cache/node_modules/.bin/mmdc" <<'SH'
#!/usr/bin/env bash
out=""
input=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -i)
      shift
      input="$1"
      ;;
    -o)
      shift
      out="$1"
      ;;
  esac
  shift || true
done
if [ -n "$input" ] && grep -q "__INVALID__" "$input"; then
  echo "simulated Mermaid render failure" >&2
  exit 1
fi
if [ -n "$out" ]; then
  printf '<svg xmlns="http://www.w3.org/2000/svg"></svg>\n' > "$out"
fi
exit 0
SH
chmod +x "$TMP/cache/node_modules/.bin/mmdc"

MMDC_HOME="$TMP/cache" bash "$SKILL_DIR/scripts/validate_mermaid.sh" "$SKILL_DIR/test-fixtures/diagrams" > "$TMP/validate.out"
grep -q "Mermaid validation (render): 2 passed, 0 failed (of 2)." "$TMP/validate.out"

mkdir -p "$TMP/invalid/workflows"
printf 'flowchart TD\n  A-->B\n' > "$TMP/invalid/layers.mmd"
printf '__INVALID__\n' > "$TMP/invalid/workflows/bad_workflow.mmd"
if MMDC_HOME="$TMP/cache" bash "$SKILL_DIR/scripts/validate_mermaid.sh" "$TMP/invalid" > "$TMP/invalid.out" 2>&1; then
  echo "ERROR: nested invalid diagram unexpectedly passed" >&2
  exit 1
fi
grep -q "FAIL  $TMP/invalid/workflows/bad_workflow.mmd" "$TMP/invalid.out"

node --check "$SKILL_DIR/scripts/build_report.mjs"
node "$SKILL_DIR/scripts/build_report.mjs" \
  "$SKILL_DIR/test-fixtures/report-input.json" \
  "$TMP/out/ARCHITECTURE_OVERVIEW.html" > "$TMP/build.out"

grep -q "workflow-signup" "$TMP/out/ARCHITECTURE_OVERVIEW.html"
grep -q "mermaid@11.15.0" "$TMP/out/ARCHITECTURE_OVERVIEW.html"
if grep -q "{{" "$TMP/out/ARCHITECTURE_OVERVIEW.html"; then
  echo "ERROR: unreplaced template token found" >&2
  exit 1
fi

echo "architecture-html-report verification passed"
