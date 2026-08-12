# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

`v1` is a floating tag that always points at the latest `v1.x.y` release —
pin to it for automatic non-breaking updates, or pin to an exact `vX.Y.Z`
tag for reproducible builds.

## [Unreleased]

## [1.0.1] - 2026-08-12

### Fixed

- `pull_request_labels` (default `documentation`) made PR creation fail outright when the label didn't already exist in the target repo. `scripts/ensure-labels.sh` now creates any missing label before `create-pull-request` runs, so the default works out of the box. Requires the `issues: write` permission, now included in the example workflow and README.

## [1.0.0] - 2026-08-12

### Added

- `action.yml`: a composite GitHub Action that installs the `rustdoc-ultimate`
  skill into a target Rust repository, runs it via
  [`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action),
  and opens a pull request with the results via
  [`peter-evans/create-pull-request`](https://github.com/peter-evans/create-pull-request).
- `mode` input (`conservative` default, `aggressive`): conservative only fills
  in items flagged by the `missing_docs` rustdoc lint and never edits existing
  doc text; aggressive also reviews and rewrites existing documentation.
- `scope` input (`changed-files` default, `whole-repo`): limits a run to the
  `*.rs` files touched by the triggering pull request, or reviews everything.
- `scripts/collect-scope.sh`, `scripts/lint-missing-docs.sh`,
  `scripts/build-prompt.sh`: the scope resolution, missing-docs detection, and
  prompt-assembly logic backing the two inputs above.
- `examples/rustdoc-ultimate.yml`: a copy-paste starter workflow.
- Published to the [GitHub Marketplace](https://github.com/marketplace/actions/rustdoc-ultimate).
- README sections documenting Action setup, prerequisites, and inputs,
  collapsed into `<details>` folds alongside the existing Claude Skill
  install instructions.

### Fixed

- `action.yml`'s `anthropic_api_key` input description embedded a literal
  `${{ secrets.ANTHROPIC_API_KEY }}` expression, which isn't a valid context
  in an action manifest and broke every run immediately.
- Missing `id-token: write` permission, required by `claude-code-action`
  even when authenticating with a direct API key.
- The CI-installed skill file (`.claude/skills/rustdoc-ultimate/SKILL.md`)
  was leaking into every opened PR's diff as an unrelated addition; it's now
  excluded via `.git/info/exclude` when not already tracked by the target repo.
- Default trigger switched from `push` to `pull_request`: the underlying
  `claude-code-action` rejects raw push events outright ("Unsupported event
  type: push", [anthropics/claude-code-action#1456](https://github.com/anthropics/claude-code-action/issues/1456)).
- `create-pull-request` failed on real `pull_request`-triggered runs with
  "the 'base' input must be supplied" — `actions/checkout` leaves a detached
  HEAD on that event, so the base branch is now set explicitly to
  `github.head_ref`.
- The `/rustdoc-ultimate` skill invocation was silently rejected on real
  `pull_request`-triggered runs ("Unknown command", failing before any model
  call). Replaced with an explicit instruction for Claude to `Read` the skill
  file directly, which doesn't depend on CLI-level slash-command resolution.

[Unreleased]: https://github.com/EONRaider/rustdoc-ultimate/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/EONRaider/rustdoc-ultimate/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/EONRaider/rustdoc-ultimate/compare/623f3d8...v1.0.0
