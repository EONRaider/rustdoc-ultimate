#!/usr/bin/env bash
# Assembles the prompt passed to `claude-code-action` and writes it to the
# file named by $PROMPT_FILE. Reads INPUT_MODE, INPUT_SCOPE, SCOPE_FILE, and
# MISSING_DOCS_FILE from the environment.
set -euo pipefail

prompt_file="${PROMPT_FILE:?PROMPT_FILE must be set}"
mode="${INPUT_MODE:?INPUT_MODE must be set}"
scope="${INPUT_SCOPE:?INPUT_SCOPE must be set}"
scope_file="${SCOPE_FILE:-}"
missing_docs_file="${MISSING_DOCS_FILE:-}"

{
  echo "/rustdoc-ultimate"
  echo

  if [[ "$scope" == "whole-repo" ]]; then
    echo "Scope: the entire crate/workspace. Use Glob/Grep to find every public item."
  elif [[ -n "$scope_file" && -s "$scope_file" ]]; then
    echo "Scope: only the following files changed by this push/PR. Do not touch any other file:"
    sed 's/^/  - /' "$scope_file"
  else
    echo "Scope: no Rust files changed in this push/PR. Do nothing and report that there is nothing to do."
  fi
  echo

  if [[ "$mode" == "conservative" ]]; then
    echo "Guardrail: CONSERVATIVE mode."
    echo "Only add documentation to items that are structurally undocumented, i.e. the exact"
    echo "locations flagged by the missing_docs rustdoc lint, listed below. Do not modify,"
    echo "rewrite, shorten, or delete any existing doc comment or crate-level //! doc, even if"
    echo "you believe it could be improved. If the list below is empty, make no changes at all."
    echo
    if [[ -n "$missing_docs_file" && -s "$missing_docs_file" ]]; then
      echo "Undocumented locations (missing_docs lint):"
      sed 's/^/  - /' "$missing_docs_file"
    else
      echo "Undocumented locations (missing_docs lint): none."
    fi
  else
    echo "Guardrail: AGGRESSIVE mode."
    echo "Follow the skill's full workflow: add missing documentation AND review/rewrite"
    echo "existing documentation in scope that falls short of the standard (e.g. missing"
    echo "# Errors/# Panics/# Safety sections, missing or non-doctest examples, unlinked"
    echo "type references, or prose that just restates the item's name)."
  fi
  echo
  echo "When finished, only leave behind the doc-comment/attribute/Cargo.toml-metadata edits"
  echo "described above — do not modify any other code, and do not commit or open a pull"
  echo "request yourself; a separate CI step handles that."
} > "$prompt_file"
