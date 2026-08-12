# Contributing

This repo has two files that need to stay in sync:

- [README.md](README.md) — the research itself
- [rustdoc-ultimate.md](rustdoc-ultimate.md) — the Claude Skill distilled from that research

## Reporting inaccuracies or gaps

Open an issue if you spot something outdated (a changed rustdoc behavior, a superseded RFC, a new tool worth covering) or a gap in coverage. Point to the specific claim and, where possible, a source (rustdoc book, an RFC, docs.rs) backing the correction.

## Proposing changes

1. Fork the repo and create a branch for your change.
2. If your change affects a claim or recommendation in `README.md`, update the corresponding guidance in `rustdoc-ultimate.md` as well (and vice versa) — the two files should never contradict each other.
3. Keep additions grounded: cite the rustdoc book, an RFC, the Rust API Guidelines, or other authoritative sources rather than personal preference.
4. Open a pull request describing what changed and why.

## Style

- Match the existing tone: concise, reference-style, backed by citations rather than opinion.
- Keep Markdown headings and section structure consistent with the rest of the file you're editing.

## Versioning the GitHub Action

`action.yml` and `scripts/` are versioned separately from the research content, using [Semantic Versioning](https://semver.org/). Any change to either:

1. Gets a [CHANGELOG.md](CHANGELOG.md) entry under `[Unreleased]`, moved into a new dated `[X.Y.Z]` section when released.
2. Gets a new `vX.Y.Z` tag — patch for a fix, minor for a backward-compatible input/feature, major for a breaking change to inputs or behavior.
3. Moves the floating `v1` tag (or `v2`, etc.) to match, so repos pinned to `@v1` pick up non-breaking updates automatically.

README/skill changes with no effect on `action.yml`/`scripts/` don't need a version bump.
