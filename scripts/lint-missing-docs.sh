#!/usr/bin/env bash
# Runs `cargo doc` with the missing_docs lint escalated to a warning and
# writes one "path:line" entry per undocumented public item to the file
# named by $MISSING_DOCS_FILE. When $SCOPE_FILE is non-empty, entries outside
# those paths are dropped, so conservative mode only ever targets in-scope
# files. Assumes a single-crate-or-workspace root Cargo.toml checked out at
# the current directory; skipped entirely for scope=whole-repo runs where a
# lint-derived allow-list isn't needed.
set -euo pipefail

missing_docs_file="${MISSING_DOCS_FILE:?MISSING_DOCS_FILE must be set}"
scope_file="${SCOPE_FILE:-}"
: > "$missing_docs_file"

if [[ ! -f Cargo.toml ]]; then
  echo "no Cargo.toml at repo root; skipping missing_docs lint" >&2
  exit 0
fi

raw_output="$(RUSTDOCFLAGS="-W missing_docs" cargo doc --no-deps --workspace 2>&1 >/dev/null || true)"

locations="$(echo "$raw_output" \
  | grep -A1 '^warning: missing documentation' \
  | grep -oE '\-\-> [^:]+:[0-9]+:[0-9]+' \
  | sed -E 's/^--> //; s/:[0-9]+$//' \
  | sort -u || true)"

if [[ -z "$locations" ]]; then
  echo "missing_docs lint: no undocumented public items found" >&2
  exit 0
fi

if [[ -n "$scope_file" && -s "$scope_file" ]]; then
  locations="$(echo "$locations" | awk -F: 'NR==FNR { scope[$0]=1; next } ($1) in scope' "$scope_file" -)"
fi

echo "$locations" > "$missing_docs_file"
count="$(wc -l < "$missing_docs_file" | tr -d ' ')"
echo "missing_docs lint: ${count} undocumented location(s) in scope" >&2
