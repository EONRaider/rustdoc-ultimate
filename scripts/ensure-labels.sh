#!/usr/bin/env bash
# Creates any label in $LABELS (comma-separated) that doesn't already exist
# in the current repo, so create-pull-request's `labels` input never fails
# on a missing label. Requires GH_TOKEN with the `issues: write` permission.
set -euo pipefail

labels="${LABELS:-}"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"

if [[ -z "$labels" ]]; then
  echo "no labels requested, nothing to ensure" >&2
  exit 0
fi

existing="$(gh api "repos/${repo}/labels" --paginate --jq '.[].name')"

IFS=',' read -ra label_array <<< "$labels"
for raw in "${label_array[@]}"; do
  label="$(echo "$raw" | sed -E 's/^ +| +$//g')"
  [[ -z "$label" ]] && continue

  if grep -qxF "$label" <<< "$existing"; then
    echo "label '$label' already exists" >&2
    continue
  fi

  echo "creating missing label '$label'" >&2
  gh api "repos/${repo}/labels" \
    -f name="$label" \
    -f color="0e8a16" \
    -f description="Applied by the rustdoc-ultimate GitHub Action" >/dev/null
done
