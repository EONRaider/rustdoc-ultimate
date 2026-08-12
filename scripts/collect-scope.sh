#!/usr/bin/env bash
# Resolves the set of *.rs files in scope for this run and writes it, one path
# per line, to the file named by $SCOPE_FILE. Reads GITHUB_EVENT_NAME,
# GITHUB_EVENT_PATH, INPUT_SCOPE and INPUT_BASE_BRANCH from the environment.
set -euo pipefail

scope_file="${SCOPE_FILE:?SCOPE_FILE must be set}"
: > "$scope_file"

if [[ "${INPUT_SCOPE}" == "whole-repo" ]]; then
  echo "scope=whole-repo: leaving $scope_file empty (Claude will use Glob/Grep)" >&2
  exit 0
fi

before=""
after="HEAD"

case "${GITHUB_EVENT_NAME}" in
  push)
    before="$(jq -r '.before' "${GITHUB_EVENT_PATH}")"
    after="$(jq -r '.after' "${GITHUB_EVENT_PATH}")"
    # A brand-new branch (or force-push) reports an all-zero "before" SHA;
    # there's nothing to diff against, so fall back to the pushed commit alone.
    if [[ "$before" =~ ^0+$ ]]; then
      before="${after}^"
    fi
    ;;
  pull_request)
    base="${INPUT_BASE_BRANCH:-$(jq -r '.pull_request.base.ref' "${GITHUB_EVENT_PATH}")}"
    git fetch --no-tags --depth=1 origin "${base}" >&2
    before="origin/${base}"
    after="HEAD"
    ;;
  workflow_dispatch|schedule)
    # No natural "diff range" for these triggers; diff against base_branch
    # if the caller set one, otherwise fall back to the tip commit.
    if [[ -n "${INPUT_BASE_BRANCH}" ]]; then
      git fetch --no-tags --depth=1 origin "${INPUT_BASE_BRANCH}" >&2
      before="origin/${INPUT_BASE_BRANCH}"
    else
      before="${after}^"
    fi
    ;;
  *)
    echo "unrecognized event '${GITHUB_EVENT_NAME}', defaulting to last commit only" >&2
    before="${after}^"
    ;;
esac

git diff --name-only --diff-filter=ACMR "${before}" "${after}" -- '*.rs' > "$scope_file" || true

count="$(wc -l < "$scope_file" | tr -d ' ')"
echo "scope=changed-files: ${count} Rust file(s) in scope" >&2
