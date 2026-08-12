# rustdoc-ultimate — The Complete Skill for Documenting Rust Code

A comprehensive reference for writing, structuring, testing, and shipping Rust documentation with rustdoc to the highest standard, covering libraries, public APIs, and binaries/CLIs. Synthesized from the [official rustdoc book](https://doc.rust-lang.org/rustdoc/), the [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/), RFCs [505](https://rust-lang.github.io/rfcs/0505-api-comment-conventions.html)/[1270](https://rust-lang.github.io/rfcs/1270-deprecation.html)/[1574](https://rust-lang.github.io/rfcs/1574-more-api-documentation-conventions.html)/[1687](https://github.com/rust-lang/rfcs/pull/1687)/[1946](https://rust-lang.github.io/rfcs/1946-intra-rustdoc-links.html)/[3631](https://rust-lang.github.io/rfcs/3631-rustdoc-cfgs-handling.html), the [Rust Project Primer](https://rustprojectprimer.com/documentation/rustdoc.html), [Tangram Vision's rustdoc guide](https://www.tangramvision.com/blog/making-great-docs-with-rustdoc), and current (2025–2026) ecosystem tooling.

## About this repo

This README is the research itself. The repo also includes [rustdoc-ultimate.md](rustdoc-ultimate.md), a [Claude Skill](https://docs.claude.com/en/docs/claude-code/skills) built from this research — it teaches Claude to write, review, and refactor Rust documentation to the standard described below.

To use the skill in Claude Code, download `rustdoc-ultimate.md` and place it at `.claude/skills/rustdoc-ultimate/SKILL.md` in your project (or `~/.claude/skills/rustdoc-ultimate/SKILL.md` to make it available across projects).

This repo also ships a [GitHub Action](#using-rustdoc-ultimate-as-a-github-action) that runs the skill in CI and opens a pull request with the results, for repos that want documentation upkeep automated rather than invoked interactively.

## Using rustdoc-ultimate as a GitHub Action

Instead of invoking the skill interactively, a Rust repository can run it as a CI step: on every push (by default), Claude documents or fixes what's missing and opens a pull request with the result — it never commits directly to your branch.

### Prerequisites

1. Create an API key in the [Claude Console](https://console.anthropic.com) and add it as a repository secret named `ANTHROPIC_API_KEY` (**Settings → Secrets and variables → Actions → New repository secret**).
2. Install the [Claude GitHub App](https://github.com/apps/claude) on the repository (or your account/organization). `anthropics/claude-code-action`, which this action wraps, needs it for git operations even when authenticating with an API key.
3. Enable **Settings → Actions → General → Workflow permissions → "Allow GitHub Actions to create and approve pull requests"** — the action's final step opens a PR with `peter-evans/create-pull-request`, which GitHub blocks by default.
4. Be aware this is billed per the [Claude API](https://claude.com/platform/api) — each run's cost scales with how much code is in scope and how many turns it takes. Use the `mode`/`scope` inputs below, and `claude_args: "--max-turns N"`, to keep runs small and predictable.

### Setup

Copy [examples/rustdoc-ultimate.yml](examples/rustdoc-ultimate.yml) into `.github/workflows/` in your repository:

```yaml
name: rustdoc-ultimate
on:
  push:
    branches: [main, master]

permissions:
  contents: write
  pull-requests: write
  id-token: write # required by anthropics/claude-code-action even with anthropic_api_key

jobs:
  rustdoc-ultimate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: eonraider/rustdoc-ultimate@v1
        with:
          mode: conservative
          scope: changed-files
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

The example file also shows (commented out) how to trigger on `pull_request`, `workflow_dispatch` with per-run `mode`/`scope` overrides, or a `schedule`.

### Inputs

| Input | Default | Meaning |
|---|---|---|
| `mode` | `conservative` | **Conservative** only documents items the `missing_docs` rustdoc lint flags as structurally undocumented, and never edits existing doc text. **Aggressive** additionally reviews and rewrites existing documentation that falls short of the standard described in this README. |
| `scope` | `changed-files` | **changed-files** limits the run to the `*.rs` files touched by the triggering push/PR. **whole-repo** lets Claude review every file in the crate/workspace. |
| `anthropic_api_key` | — (required) | Your `ANTHROPIC_API_KEY` repository secret. |
| `base_branch` | event's base ref | Branch to diff against for `scope: changed-files` on `pull_request`/`workflow_dispatch`/`schedule` triggers. |
| `claude_args` | — | Extra CLI arguments appended to the underlying `claude-code-action` call, e.g. `--max-turns 15 --model claude-sonnet-5`. |
| `pull_request_labels` | `documentation` | Comma-separated labels applied to the opened PR. |

> [!NOTE]
> `pull_request_labels` defaults to `documentation`, but GitHub won't auto-create a missing label — if your repository doesn't already have one with that name, PR creation will fail. Create the label first, or pass `pull_request_labels: ""` to skip labeling.

This section documents the automated path; the manual install instructions above remain the way to use the skill without CI.

## TL;DR

- **Document behavior, not names.** Every public item gets a one-line summary written in third-person singular present indicative form ("Returns", not "Return", per RFC 505), an `# Examples` section whose code is a real doc-test using `?` (never `unwrap`/`try!` — the API Guidelines note "example code is often copied verbatim by users"), and the relevant `# Errors` / `# Panics` / `# Safety` sections; enforce it with `#![deny(missing_docs)]`, `#![deny(rustdoc::broken_intra_doc_links)]`, and `RUSTDOCFLAGS="-D warnings" cargo doc` in CI.
- **Use rustdoc's structure deliberately:** `//!` for crate/module front matter (what/why/getting-started), `///` for items; intra-doc links (``[`Type::method`]``) instead of raw URLs; `#[doc(hidden)]` to hide non-API impls; docs.rs metadata (`all-features`, `--cfg docsrs`) plus `#[doc(cfg(...))]` for feature-gated APIs.
- **Libraries vs binaries differ:** libraries document only public items and should follow the Rust API Guidelines (C-CRATE-DOC, C-EXAMPLE, C-FAILURE, C-LINK, C-METADATA, C-HIDDEN); binaries document private items by default and derive their `--help`/man pages from clap doc comments via `clap_mangen`/`clap_complete`.

## Key Findings

1. **The summary line is load-bearing.** The rustdoc book states rustdoc "will use the text up to the first period as the summary. There is an arbitrary limit on the length of a summary so make them brief. If the first sentence is too long then rustdoc will not create a summary." It appears in module listings and search results. Keep it one short sentence, third-person singular present indicative, and don't start with "This function".
2. **Standard section headings** are recognized conventions (rendered consistently). RFC 1574 gives the full list verbatim: "Examples · Panics · Errors · Safety · Aborts · Undefined Behavior." Always plural "Examples". Use only `#` (H1) headings for sections — rustdoc keys on them.
3. **Everything should have an example (C-EXAMPLE)**, and the purpose of an example is often to show *why* you'd use an item, not merely *how*. Examples are compiled and run as tests by `cargo test`, so they cannot silently rot.
4. **Examples use `?`, not `unwrap`/`try!` (C-QUESTION-MARK)** because, in the API Guidelines' words, "example code is often copied verbatim by users. Unwrapping an error should be a conscious decision that the user needs to make." Hide boilerplate (`main`, imports, `Ok(())`) with lines prefixed `#`.
5. **Intra-doc links** (RFC 1946) are compiler-checked: ``[`Vec`]``, `[Type::method]`, with disambiguators (`struct@`, `fn@`, `macro@`, or trailing `()`/`!`). Broken links warn by default via `rustdoc::broken_intra_doc_links`.
6. **`#[doc(hidden)]`, `#[doc(inline)]`/`#[doc(no_inline)]`, `#[doc(alias = "…")]`, `#[doc(cfg(…))]`** control visibility, re-export rendering, search aliases, and platform/feature badges. `#[doc = include_str!("../README.md")]` unifies README and crate docs.
7. **Doc-test code-block attributes:** `should_panic`, `no_run`, `compile_fail`, `ignore`, `text`, edition tags (`edition2021`/`edition2024`), plus `# ` hidden lines and `#[cfg(doctest)]` tricks.
8. **Tooling in 2025–2026:** docs.rs metadata table, `cargo-semver-checks` (rustdoc-JSON-based breaking-change detection), `cargo-public-api`, `cargo-readme`/`cargo-rdme` (README from docs), `lychee`/`cargo-deadlinks` (link checking), `clap_mangen`/`clap_complete` for CLI docs, and near-stable `doc_auto_cfg`.

## Details

### 1. Doc comment syntax and the `#[doc]` attribute

- **Two comment forms.** Outer `///` documents the item that *follows* it (fn, struct, enum, trait, module, field, variant). Inner `//!` documents the item that *contains* it — in practice the crate root (`lib.rs`/`main.rs`) or a module file.
- `///` is sugar for `#[doc = "…"]`; `//!` is sugar for `#![doc = "…"]`. The attribute form is needed for `#[doc = include_str!("…")]` and macro-generated docs.
- **RFC 1574 convention:** only use `//!` for crate- and module-level docs, nothing else. When documenting a `mod` block, prefer `///` *outside* the block over `//!` inside it. Avoid `/* */` block comments; use line comments.
- Doc comments are **Markdown** (CommonMark). Prefer fenced code blocks over indented ones (indented blocks can't take attributes like `ignore`/`should_panic`).
- **Referring to types:** use full generic names in prose — write `Option<T>`, not `Option` (exception: omit long bounds). Lower-case generic terms ("a string", "an option") are acceptable.
- **`#[doc(alias = "…")]`** adds a search-index alias (accepts a list: `#[doc(alias("x", "big"))]`); invaluable for FFI bindings so users can find the Rust wrapper by the C symbol name.

### 2. The summary + body structure (RFC 505 / RFC 1574)

Per RFC 505: "The summary line should be written in third person singular present indicative form. Basically, this means write 'Returns' instead of 'Return'." All doc comments should be properly punctuated full sentences.

Template for any item:

```rust
/// Summary line: one sentence, third-person present, ends with a period.
///
/// Longer prose describing behavior: what it does, when to reach for it,
/// invariants it maintains, and anything counter-intuitive. Link related
/// items with [`OtherType`].
///
/// # Errors
///
/// Describes each error condition and which variant it produces.
///
/// # Examples
///
/// ```
/// # use mycrate::thing;
/// let x = thing()?;
/// # Ok::<(), std::io::Error>(())
/// ```
```

- **Describe behavior, not the name.** A doc comment on `struct Config` that says "The Config struct" adds nothing. Explain expected formats, failure modes, and relationships to other items.
- **Explain design choices** ("why two duration types", "why the builder pattern") in crate-level or a dedicated docs module — most crates document *what* but not *why*.
- **Don't add an `# Arguments` or `# Returns` section** when names and types are self-evident; the type signature already conveys them. Reserve `# Arguments` for non-obvious assumptions (e.g., a value that triggers UB). Use `where` clauses rather than documenting generic bounds in prose.
- **Document traits, not their implementations.** Put the docs on the trait's methods; if two impls need vastly different docs, the trait is probably modeled wrong.

### 3. Standard sections

| Section | When to use |
|---|---|
| `# Examples` | Every public item (C-EXAMPLE). Always plural. |
| `# Errors` | Any fn returning `Result` (C-FAILURE). List each error condition/variant. Enforced by Clippy `missing_errors_doc` (pedantic). |
| `# Panics` | Any fn that may panic (C-FAILURE). Clippy `missing_panics_doc` (pedantic). |
| `# Safety` | **Every `unsafe fn`** — document invariants the caller must uphold (C-FAILURE). Clippy `missing_safety_doc`. |
| `# Aborts` | Conditions causing process abort (RFC 1574). |
| `# Undefined Behavior` | Conditions that trigger UB (RFC 1574). |
| `# Lifetimes` | Only when a lifetime is modeled unusually (e.g., a `PhantomData` lifetime enforcing an FFI invariant). Single obvious lifetimes need no docs. |

Example of the Errors + linked-variant pattern:

```rust
/// Sets `value` for the provided `option`.
///
/// # Errors
///
/// Returns [`OptionNotSupported`](SetOptionError::OptionNotSupported) if the
/// option is not supported on this sensor.
```

Standard-library exemplar for `# Safety` (`std::ptr::read`): "Beyond accepting a raw pointer, this is unsafe because it semantically moves the value out of `src` without preventing further usage of `src`… The pointer must be aligned; use `read_unaligned` if that is not the case."

### 4. Crate-level documentation (the front page)

- Written with `//!` at the top of `lib.rs`/`main.rs`. It's the first thing users see on docs.rs and should answer: **what does this crate do, when should you use it, how do you get started** (C-CRATE-DOC, RFC 1687).
- Structure: summary → features → usage example (realistic, copy-pasteable, no shortcuts) → then deeper design discussion. Put the "what/how" first, "why" after.
- The first line should place the crate in the ecosystem in one non-technical sentence, so a reader knows if it fits their use case.
- **`#![doc = include_str!("../README.md")]`** pulls the README into the crate docs so README and docs.rs stay in sync (single source of truth). To also *test* the README's code blocks: `#[doc = include_str!("../README.md")] #[cfg(doctest)] pub struct ReadmeDoctests;`.
- **The `_documentation` module pattern** (used by jiff, snafu, clap): a `pub mod _documentation` (leading underscore sorts it to the top) containing empty submodules each fed a Markdown file via `#[doc = include_str!("…")]`, turning design/comparison/migration guides into docs.rs pages. Tradeoff: docs.rs renders plain Markdown with no custom nav/search; for tutorials use a standalone mdBook.
- `missing_crate_level_docs` (rustdoc lint, allow by default) flags a crate root with no docs.

### 5. Module-level vs item-level docs (RFC 1574)

Resolve the classic tension: **module-level docs give a broad high-level summary of everything in the module; each type documents itself fully.** A small amount of duplication is fine. Don't make types say "see the module-level docs for details." Tangram Vision's top-down model: crate = big "what"; modules = why-you'd-reach-for-this; types = construction/drop/performance; functions = practical "how" with examples. Avoid sub-modules more than ~2 levels deep.

### 6. Intra-doc links (RFC 1946)

- Syntax: ``[`Option`]`` (backticks stripped), `[text](Type)`, `[text][ref]` with `[ref]: Type`. Rust path syntax works: `Self`, `self`, `super`, `crate`, associated items, primitives, generics (``[`Vec<T>`]`` resolves as `Vec`). URL fragments allowed: `[params]: std::fmt#formatting-parameters`.
- **Disambiguators** for name collisions across the type/value/macro namespaces: prefixes `struct@`, `enum@`, `trait@`, `mod@`, `const@`, `fn@`, `macro@`, `type@`, `value@`, `derive@`, `prim@`, etc.; or suffixes `Foo()` (function) and `foo!` (macro, may be followed by `()`/`{}`/`[]`). `Clone` auto-resolves to the trait over the derive macro.
- Links resolve in the scope where the item is *defined*, even when re-exported; when re-exporting you can add extra docs that resolve in the new scope.
- **Prefer links to raw URLs** (C-LINK): they're compiler-checked and won't rot. RFC 1574's "Link all the things" — link every referenced type, even `String`/`Vec`. Prefer reference-style links for readability.
- Relevant lints: `broken_intra_doc_links` (warn by default), `private_intra_doc_links` (warn), `redundant_explicit_links` (warn), `bare_urls` (warn — wrap URLs in `<…>`).

### 7. Doctests (the rustdoc testing model)

- Code blocks default to Rust and run under `cargo test` / `cargo test --doc`. A doctest "passes" if it compiles and runs without panicking; use `assert_eq!` to check results.
- **Preprocessing:** rustdoc inserts common `allow`s (`unused_variables`, `dead_code`, etc.), adds `#![doc(test(attr(...)))]` attributes, injects `extern crate mycrate;` unless present or `#![doc(test(no_crate_inject))]`, and wraps the body in `fn main()` if there's no `fn main`.
- **Hidden lines:** prefix with `# ` to compile-but-hide setup/boilerplate. Escape a literal leading `#` as `##`. **Caveat:** never hide lines that carry essential logic the user must copy — verify examples compile using only the *visible* lines.
- **Using `?`:** end a hidden block with `# Ok::<(), ErrorType>(())` or a hidden `# fn main() -> Result<…> { … # Ok(()) # }`. The API-guidelines pattern:

```rust
/// ```
/// # use std::error::Error;
/// # fn main() -> Result<(), Box<dyn Error>> {
/// your;
/// example?;
/// #     Ok(())
/// # }
/// ```
```

- **Code-block attributes:**
  - `should_panic` — must panic to pass. **Best practice:** constrain the expected panic message so message changes don't silently pass (a bare `should_panic` passes on *any* panic).
  - `no_run` — compiles but doesn't run (network/hardware examples; also for UB demonstrations).
  - `compile_fail` — must fail to compile (documents what the type system prevents); may work in a future release since features are added.
  - `ignore` — skips compilation entirely; **use sparingly** — prefer `text` for non-Rust or `#` to hide. Tangram Vision recommends `ignore`/`text` for illustrative-but-invalid code.
  - `text` — not Rust; no highlighting/testing.
  - Language tags for other languages: ```` ```c ```` (or `custom,{class=language-c}` to disable Rust treatment).
  - `edition2015`/`edition2018`/`edition2021`/`edition2024`, `standalone_crate` (opt out of the 2024-edition doctest merging), `ignore-<target>` (skip per target).
- `#[cfg(doctest)]` items exist only while collecting doctests (e.g., a `compile_fail` guard proving a type rejects bad input), without appearing in public docs.
- Show doctest warnings with `cargo test --doc -- --show-output`.

### 8. rustdoc lints and enforcement

Enable via `#![warn(...)]`/`#![deny(...)]` at the crate root. Except `missing_docs`, rustdoc lints only run under rustdoc, not rustc.

| Lint | Default | Purpose |
|---|---|---|
| `missing_docs` (rustc lint) | allow | Public items lacking docs. Set `deny` for established libs, `warn` while evolving. |
| `rustdoc::broken_intra_doc_links` | warn | Unresolved intra-doc links. |
| `rustdoc::private_intra_doc_links` | warn | Public item links to private item. |
| `rustdoc::missing_crate_level_docs` | allow | No crate-root docs. |
| `rustdoc::missing_doc_code_examples` | allow (nightly-only) | Public items lacking a code example. Not emitted on impls, variants, fields, type aliases, statics/consts, modules. |
| `rustdoc::private_doc_tests` | allow | Doctests on private items. |
| `rustdoc::invalid_codeblock_attributes` | warn | Typos like ` ```should-panic `. |
| `rustdoc::invalid_html_tags` | warn | Unclosed/invalid HTML. |
| `rustdoc::invalid_rust_codeblocks` | warn | Empty/unparseable Rust blocks. |
| `rustdoc::bare_urls` | warn | URLs not wrapped as links. |
| `rustdoc::unescaped_backticks` | allow | Likely-broken inline code. |
| `rustdoc::redundant_explicit_links` | warn | Explicit link identical to the automatic one. |

There is a `rustdoc::all` lint group covering the rustdoc lints. Recommended crate-root block for a serious library:

```rust
#![warn(missing_docs)]
#![deny(rustdoc::broken_intra_doc_links)]
#![warn(rustdoc::all)]
```

Clippy documentation lints (many in `clippy::pedantic`): `missing_errors_doc`, `missing_panics_doc`, `missing_safety_doc`, `doc_broken_link`, `doc_markdown`.

### 9. Attributes for presentation, features, and hiding

- **`#[doc(hidden)]`** — omit an item from docs (unless `--document-hidden-items`). Use for impls users can never exercise (e.g., `From<PrivateError>` needed only for internal `?`), internal macros, etc. (C-HIDDEN). `pub(crate)` is the complementary tool for keeping items out of the public API entirely.
- **`#[doc(inline)]` / `#[doc(no_inline)]`** — on `use` statements, control whether a re-export's docs are inlined into the current page or shown as a "Re-exports" line. In Rust 2018+, a `pub use` of a *dependency* is not inlined unless you add `#[doc(inline)]`. Note: `#[doc(hidden)]`, `#[doc(alias)]`, `#[doc(inline)]`, `#[doc(no_inline)]` are *not* inherited through inlined re-exports.
- **`#[doc(cfg(feature = "json"))]`** — renders an "Available on feature X only" badge. Requires nightly `#![feature(doc_cfg)]`; the standard stable-compatible pattern gates it on a `docsrs` cfg (see §10). `doc_auto_cfg` (RFC 3631) automatically generates these badges from `#[cfg]`; per rust-lang/rust-project-goals Issue #404 (opened by nikomatsakis, Sept 2025; point of contact @GuillaumeGomez, T-rustdoc), the 2025h2 plan is to stabilize the feature and "enable it by default on docs.rs" (stabilization tracked in rust-lang/rust PR #150055). `#[doc(auto_cfg(hide(...)))]` suppresses noisy cfgs like `unix`/`doctest`.
- **Crate-level `#![doc(...)]`:** `html_logo_url`, `html_favicon_url`, `html_playground_url`, `html_root_url`, `html_no_source`, `issue_tracker_base_url`, `test(no_crate_inject)`, `test(attr(...))` (apply attributes to all doctests, e.g. `#![doc(test(attr(deny(warnings))))]`).
- **`#[deprecated(since = "x.y.z", note = "use `bar` instead")]`** (RFC 1270) — rustc warns on use; rustdoc shows the deprecation banner with `since` and `note`. `since` follows semver (checked only by external tools like Clippy). Applies to fns, methods, impls, consts, type defs, struct fields, enum variants; inherited by module children. To introduce deprecations without breaking `-Dwarnings` builds, gate behind a feature: `#[cfg_attr(feature = "deprecated", deprecated = "…")]`.

### 10. docs.rs conventions and feature-gated docs

- **`Cargo.toml` metadata (C-METADATA):** `[package]` should include `description`, `license`, `repository`, `keywords`, `categories` (and `authors`); optionally `documentation` (only if hosted off docs.rs) and `homepage` (only for a distinct site, e.g. serde.rs — don't duplicate repo/docs). `readme` points at the README (crates.io renders it as Markdown).
- **docs.rs build customization** via `[package.metadata.docs.rs]`:

```toml
[package.metadata.docs.rs]
all-features = true
rustdoc-args = ["--cfg", "docsrs"]
# optionally: features = ["full"], default-target, targets = [...]
```

- **Stable-compatible feature badges** (the Tokio pattern):

```rust
// lib.rs
#![cfg_attr(docsrs, feature(doc_cfg))]

#[cfg(feature = "rt")]
#[cfg_attr(docsrs, doc(cfg(feature = "rt")))]
pub mod runtime {}
```

Build locally with `RUSTDOCFLAGS="--cfg docsrs" cargo +nightly doc --all-features`.
- `#[cfg(doc)]` / `#[cfg(docsrs)]` let you include doc-only items or check you're building on docs.rs. `cargo docs-rs` reproduces the build environment to catch docs.rs-only failures.

### 11. Scraped examples

`cargo doc --scrape-examples` (auto-enabled on docs.rs for crates with an `examples/` dir) finds uses of your public items in `examples/` and displays them inline on each item's page — a strong reason to write well-structured example binaries (Bevy uses this heavily).

### 12. Generating docs and CI

```bash
cargo doc --open --no-deps                 # build only your crate, open in browser
RUSTDOCFLAGS="-D warnings" cargo doc --no-deps   # fail on any doc warning (broken links etc.)
cargo test --doc                           # run only doctests
cargo doc --document-private-items         # include private items (default for binaries)
```

Put `RUSTDOCFLAGS="-D warnings" cargo doc --no-deps` (or a `RUSTDOCFLAGS: -Dwarnings` env in the GitHub Actions doc job) in CI so broken intra-doc links and other doc warnings fail the build.

### 13. Ecosystem tooling (2025–2026)

- **README from docs:** `cargo-readme` (`cargo readme > README.md`), `cargo-rdme` (inserts between `<!-- cargo-rdme -->` markers, rewrites intra-doc links to docs.rs URLs), `cargo-doc2readme` (supports Rust 1.48+ path links). Keeps examples tested and in sync.
- **Breaking-change / API-surface detection:** `cargo-semver-checks` (lints rustdoc JSON for semver violations before `cargo publish`; ships as a GitHub Action; supports current stable+beta Rust) and `cargo-public-api` (lists/diffs the public API from rustdoc JSON; usable as a snapshot test). Both consume the unstable **rustdoc JSON** output (`--output-format json`, nightly).
- **Link checking:** `lychee` (fast async checker for Markdown/HTML, CI + pre-commit) and `cargo-deadlinks` (checks generated docs for dead links).
- **Long-form docs:** **mdBook** for tutorials/guides/conceptual overviews (the tool behind "The Rust Programming Language"); rustdoc is for API *reference* only. mdBook supports the same doctest attributes plus `mdbook-runnable`.
- Near-stable rustdoc features: doctest merging (2024 edition, big perf win), `doc_auto_cfg` stabilization in progress.

### 14. Binaries and CLI tools (distinct from libraries)

- **`cargo doc` documents binary targets** and **enables `--document-private-items` by default for binaries** (bin items are mostly private) — the Cargo Book: "This will be enabled by default if documenting a binary target." Libraries document only public items by default. In a mixed lib+bin package, private items appear in the bin docs, not the lib docs.
- Even for a binary, write a strong **`//!` crate-level doc** (purpose, usage, examples) and a README — docs.rs builds and hosts binary-crate docs too, and the crate-level overview is the most valuable reader-facing part.
- **clap derive maps doc comments to `--help`:** a `///` doc comment has three parts — a short summary line, a blank (whitespace-only) line, then the detailed description. The summary becomes `Command::about` / `Arg::help` (shown with `-h`). Per clap's official derive reference: "When a blank line is present, the whole doc comment will be passed to `Command::long_about` / `Arg::long_help`" (shown with `--help`). Without a blank line, no long help is set, and attributes override doc comments. Tip: `#![deny(missing_docs)]` catches missing `--help` text at compile time. clap's derive_ref also advises: "When a doc comment is also present, you most likely want to add `#[clap(long_about = None)]` to clear the doc comment so only `about` gets shown with both `-h` and `--help`."
- **`verbatim_doc_comment`** disables clap's preprocessing (which strips whitespace/blank lines, word-wraps paragraphs collapsing newlines to spaces, and strips a single trailing period), preserving ASCII art / Markdown tables / line layout. Per clap's `_derive` docs, it "will still remove one leading space from each line, even if this attribute is present, to allow for a space between `///` and the content."
- **Man pages:** `clap_mangen` generates ROFF from a `clap::Command`. Recommended pattern: define the CLI once with the derive API in a shared module, get the `Command` via `CommandFactory::command()`, then in `build.rs` (or, per clap's tip, a `cargo xtask` to reduce build cost) render to `OUT_DIR`:

```rust
// build.rs
use clap::CommandFactory;
#[path = "src/cli.rs"] mod cli;
fn main() -> std::io::Result<()> {
    let out = std::path::PathBuf::from(std::env::var_os("OUT_DIR").unwrap());
    let man = clap_mangen::Man::new(cli::Cli::command());
    let mut buf = Vec::new();
    man.render(&mut buf)?;
    std::fs::write(out.join("mybin.1"), buf)
}
```

- **Shell completions:** `clap_complete::generate(shell, &mut cmd, name, &mut io::stdout())` (ahead-of-time) for bash/zsh/fish/elvish/powershell, from `build.rs` or a hidden `--generate <shell>` flag; dynamic completion is available behind `unstable-dynamic`. Single source of truth: same derive types drive runtime parsing, man pages, and completions.
- CLI UX convention: `mycli --help`, `mycli` help output, and `man mycli` should tell the same story.

### 15. Accessibility and formatting

- **Heading hierarchy:** in doc comments use only `#` for the recognized sections; rustdoc places item docs under the correct semantic heading level (it caps at `h6` and avoids multiple `h1`s per page). Don't jump levels; keep type/fn docs flat (only add an H1 section when needed).
- **Code blocks must declare a language** so non-Rust snippets are highlighted correctly and not treated as (failing) doctests — tag with `text`, `c`, `bash`, etc.
- Wrap bare URLs in `<…>` (avoids `bare_urls`); use tables and reference-style links for readability; use American English for std-style consistency (RFC 1574).

## Recommendations

**Stage 1 — Baseline (every crate, do first).**
1. Add a `//!` crate-level doc answering what/when/how with one realistic, tested usage example.
2. Fill `Cargo.toml` metadata: `description`, `license`, `repository`, `keywords`, `categories`, `readme`.
3. Add crate-root lints: `#![warn(missing_docs)]` and `#![deny(rustdoc::broken_intra_doc_links)]`.
4. Give every public item a summary line (third-person present) + `# Examples`.
*Threshold to advance:* `cargo doc` builds clean and every public item has docs.

**Stage 2 — Rigor (libraries / public APIs).**
1. Add `# Errors` to every `Result`-returning fn, `# Panics` where it can panic, `# Safety` to every `unsafe fn`.
2. Convert examples to use `?` with hidden boilerplate; make examples show *why*, not just *how*.
3. Replace raw URLs with intra-doc links; hide non-API impls with `#[doc(hidden)]`.
4. Turn on Clippy pedantic doc lints (`missing_errors_doc`, `missing_panics_doc`, `missing_safety_doc`); escalate `missing_docs` to `deny`.
5. Add docs.rs metadata (`all-features`, `--cfg docsrs`) and `#[doc(cfg(...))]` badges for feature-gated items.
6. Add CI job: `RUSTDOCFLAGS="-D warnings" cargo doc --no-deps` + `cargo test --doc`.
*Threshold to advance:* zero doc warnings under `-D warnings`; API-Guidelines documentation checklist (C-CRATE-DOC, C-EXAMPLE, C-QUESTION-MARK, C-FAILURE, C-LINK, C-METADATA, C-HIDDEN, C-RELNOTES) all satisfied.

**Stage 3 — Excellence / stability.**
1. Add the `_documentation` module or an mdBook for design rationale, comparisons, and migration/tutorial guides.
2. Enable scraped examples (well-structured `examples/`).
3. Adopt `cargo-semver-checks` and/or `cargo-public-api` in CI to gate releases; maintain release notes/CHANGELOG and tag releases (C-RELNOTES).
4. Use `#[deprecated(since, note)]` for graceful API evolution; add a link checker (`lychee`) for external URLs.
5. Sync README with `cargo-rdme`/`cargo-readme`.

**For binaries/CLIs specifically:** write doc comments on your clap structs/fields (summary → blank line → detail) to drive `--help`; generate man pages with `clap_mangen` and completions with `clap_complete` from a single shared CLI definition (prefer a `cargo xtask`); rely on `cargo doc` documenting private items by default.

## Caveats

- **These are guidelines, not mandates.** The Rust API Guidelines explicitly say to apply them "within reason"; C-EXAMPLE in particular says a link to one example may suffice rather than duplicating examples everywhere.
- **Nightly/unstable surface area:** `#[doc(cfg(...))]`/`doc_auto_cfg`, `rustdoc::missing_doc_code_examples`, and rustdoc JSON output are nightly-only or unstable as of this writing; the `docsrs` cfg gate is a community convention (tracked for standardization in cargo issue #13875), not a language feature. `doc_cfg` stabilization was targeted for the 2025h2 project-goals cycle (Issue #404) but confirm current status before relying on stable behavior.
- **rustdoc JSON is unstable** and changes across Rust versions — `cargo-semver-checks`/`cargo-public-api` pin to specific toolchains; expect to update them alongside Rust.
- **Don't over-hide in doctests:** hidden (`#`) lines run but aren't shown, so a passing test can mask a broken visible example; verify by compiling only the visible lines.
- **clap version specifics:** the mapping and `verbatim_doc_comment` behavior described are for clap v3.2+/v4; older Rust-CLI-book examples use string short flags (`short = "n"`) whereas clap v4 uses chars (`short = 'n'`). Verify against the clap version you use.
- **`should_panic` without `expected`** passes on *any* panic; always constrain the expected message to avoid masking regressions.
- The existing "Rust Documentation Standards" skill (mcpmarket.com, by paulnsorensen) is narrowly RFC-1574-focused (summary sentences, mandatory headings, type-reference linking, American-English normalization); this skill supersedes it with full doctest, attribute, lint, docs.rs, tooling, and binary/CLI coverage.