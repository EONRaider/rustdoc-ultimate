---
name: rustdoc-ultimate
description: Write, review, or refactor documentation for Rust code (crates, libraries, binaries, CLIs, or public APIs) to the highest modern standard using rustdoc. Use this skill whenever the user asks to document a Rust codebase, add doc comments, write a crate-level README/overview, fix rustdoc warnings, set up doc lints or CI, prepare a crate for crates.io/docs.rs publication, write doctests/examples, add man pages or --help text for a Rust CLI, or review/audit existing Rust documentation for completeness and quality. Trigger even if the user just says "document this Rust code," "add docs," "improve these doc comments," or pastes Rust source and asks for documentation — don't wait for them to mention rustdoc by name.
---

# rustdoc-ultimate

A complete standard for documenting Rust code — libraries, public APIs, and binaries/CLIs — synthesized from the official rustdoc book, the Rust API Guidelines, RFCs 505/1270/1574/1687/1946/3631, and current (2025–2026) ecosystem tooling.

Use this skill any time you are writing new Rust doc comments, auditing/fixing existing ones, setting up doc-related lints/CI, or preparing a crate for publication. Work through the sections in order for a full pass; jump directly to a section when the user has a narrower ask (e.g., "just add `# Errors` sections").

## Workflow

1. **Classify the target.** Is this a library (public API consumed by others), an application/binary, or both? This changes defaults — see [Libraries vs. binaries](#libraries-vs-binaries).
2. **Write/fix the crate-level docs first** (`//!` in `lib.rs`/`main.rs`) — see [Crate-level docs](#4-crate-level-documentation-the-front-page). This is the highest-leverage documentation in the whole crate.
3. **Walk every public item** (fn, struct, enum, trait, module, macro, field, variant) and apply the [item template](#2-the-item-template). Don't skip trait impls that need their own explanation, but don't duplicate docs that belong on the trait.
4. **Add the standard sections** where applicable: `# Examples` (always), `# Errors`, `# Panics`, `# Safety` (mandatory for `unsafe fn`) — see [Standard sections](#3-standard-sections).
5. **Wire up intra-doc links** instead of prose type names or raw URLs — see [Intra-doc links](#6-intra-doc-links).
6. **Add lints and CI enforcement** so the documentation can't silently rot — see [Lints and CI](#8-lints-and-ci-enforcement).
7. **If it's a binary/CLI**, additionally handle `--help` text, man pages, and completions — see [Binaries and CLIs](#14-binaries-and-cli-tools).
8. **If it's a library heading for crates.io**, fill in `Cargo.toml` metadata and docs.rs config — see [docs.rs and metadata](#10-docsrs-conventions-and-feature-gated-docs).
9. Report back what you changed and, if relevant, suggest next-stage improvements from the [maturity ladder](#maturity-ladder) rather than silently doing everything unasked (e.g., don't add a full mdBook nobody asked for).

Always actually run or reason about `cargo doc`/`cargo test --doc` mentally against what you write: examples must compile, `?` needs a concrete hidden error type, and intra-doc link targets must exist.

---

## 1. Doc comment syntax

- `///` (outer) documents the item **immediately following** it: fn, struct, enum, trait, module, field, variant, macro.
- `//!` (inner) documents the item **containing** it — in practice, only the crate root or a module file. **Rule: never use `//!` for anything except crate/module docs.** When documenting a `mod` block from outside, prefer an outer `///` above the `mod` declaration over `//!` inside the block.
- Both are sugar for the `#[doc = "..."]` attribute; use the attribute form directly for `#[doc = include_str!("../README.md")]` or macro-generated docs.
- Doc comments are CommonMark Markdown. Use fenced code blocks (` ``` `), not indented blocks — only fenced blocks accept attributes like `ignore`/`should_panic`.
- Refer to generic types with full names in prose: `Option<T>`, not bare `Option` (long bounds may be elided).
- Use `#[doc(alias = "...")]` (or `#[doc(alias("a", "b"))]`) to add searchable aliases — essential for FFI wrappers so users can find the Rust type by its C symbol name.

## 2. The item template

Every public item should follow this shape:

```rust
/// Summary line: one short sentence, third-person singular present
/// indicative ("Returns", not "Return"), ends with a period.
///
/// Longer prose: what it does, when to reach for it, invariants,
/// anything counter-intuitive. Link related items with [`OtherType`].
///
/// # Errors
///
/// Describes each error condition / which variant it produces.
///
/// # Examples
///
/// ```
/// # use mycrate::thing;
/// let x = thing()?;
/// # Ok::<(), std::io::Error>(())
/// ```
pub fn thing() -> Result<Thing, std::io::Error> { ... }
```

Rules:
- **Summary line is load-bearing.** Rustdoc uses text up to the first period as the summary shown in module listings and search results. Keep it one short sentence. Don't write "This function..." — start with the verb.
- **Describe behavior, not the name.** "The `Config` struct." is worthless. Explain formats, failure modes, relationships to other items.
- **Don't add `# Arguments`/`# Returns`** when the signature already makes them obvious — that's noise. Do explain non-obvious assumptions or values that trigger surprising behavior.
- **Document traits, not their impls.** Put docs on the trait's methods. If two impls genuinely need very different docs, that's usually a sign the trait is modeled wrong.
- **Explain design rationale ("why"), not just mechanics ("what/how")** — most crates only do the latter. Put "why" content at the crate/module level or in a dedicated docs section, not scattered across every fn.

## 3. Standard sections

Use exactly these headings (always `#` level, always this wording/case — rustdoc and readers both key on them):

| Section | Required when |
|---|---|
| `# Examples` | Every public item (function, struct, enum, trait, macro). Plural, always. |
| `# Errors` | Any fn returning `Result` — enumerate each error condition/variant. |
| `# Panics` | Any fn that can panic — state exactly when. |
| `# Safety` | **Mandatory on every `unsafe fn`** — state the invariants the caller must uphold. Never skip this. |
| `# Aborts` | Conditions causing process abort (rare — FFI/allocator code). |
| `# Undefined Behavior` | Conditions triggering UB (unsafe-heavy crates). |
| `# Lifetimes` | Only for unusually-modeled lifetimes (e.g. a `PhantomData` enforcing an FFI invariant). Skip for ordinary/obvious lifetimes. |

`# Safety` example pattern (mirrors `std::ptr::read`):
```rust
/// # Safety
///
/// `src` must be [valid] for reads, and must be properly aligned even
/// if `T` has size 0. Use [`read_unaligned`] if the pointer may be
/// unaligned. This semantically moves the value out of `src` without
/// preventing further use of `src` — the caller must ensure no double-drop.
```

## 4. Crate-level documentation (the front page)

Written as `//!` at the very top of `lib.rs`/`main.rs`. It is the first thing readers see on docs.rs — treat it as a landing page, not an afterthought (this is the API Guidelines' C-CRATE-DOC).

Order: **what it does → when to use it → a realistic, copy-pasteable getting-started example → then deeper design discussion.** Put "what/how" before "why."

Two techniques to keep README and crate docs in sync:
```rust
#![doc = include_str!("../README.md")]
```
And, if you also want the README's code fences tested:
```rust
#[doc = include_str!("../README.md")]
#[cfg(doctest)]
pub struct ReadmeDoctests;
```

For larger design/rationale/migration content, use the `_documentation` module pattern (leading underscore sorts it first in docs):
```rust
/// Design rationale and comparisons with alternatives.
pub mod _documentation {
    #[doc = include_str!("../docs/design.md")]
    pub mod design {}
    #[doc = include_str!("../docs/migration.md")]
    pub mod migration {}
}
```
Tradeoff: docs.rs renders these as plain Markdown pages with no custom nav — for a full tutorial site, use mdBook instead (see [§13](#13-ecosystem-tooling)).

## 5. Module vs. item docs

Module docs (`//!`) give a broad summary of everything in the module; each type still documents itself fully — a little overlap is fine and expected. Never write "see the module docs for details" on a type as a substitute for actually documenting it. Keep module nesting shallow (roughly 2 levels).

## 6. Intra-doc links

Prefer links over raw URLs or unlinked type names (API Guidelines C-LINK — "link all the things," even `String`/`Vec`). These are compiler-checked.

- Syntax: `` [`Vec`] ``, `[text](Type)`, `[text][ref]` + `[ref]: Type`. Rust paths work: `Self`, `self`, `super`, `crate`, associated items, primitives, generics (`` [`Vec<T>`] `` resolves to `Vec`).
- **Disambiguators** when a name exists in multiple namespaces: prefix `struct@`, `enum@`, `trait@`, `mod@`, `const@`, `fn@`, `macro@`, `type@`, `value@`, `derive@`, `prim@`; or suffix `Foo()` for functions, `foo!` for macros.
- Links resolve in the scope where the item is **defined**, even through re-exports.
- Prefer reference-style links (`[text][ref]`) for long/reused targets to keep prose readable.

## 7. Doctests

Code fences default to Rust and are compiled+run by `cargo test --doc`. A doctest passes if it compiles and runs without panicking.

- **Use `?`, never `unwrap()`/`try!()`** in example bodies (API Guidelines C-QUESTION-MARK — "example code is often copied verbatim by users; unwrapping an error should be a conscious decision"). Hide the plumbing:
  ```rust
  /// ```
  /// # use std::error::Error;
  /// # fn main() -> Result<(), Box<dyn Error>> {
  /// your::thing()?;
  /// #     Ok(())
  /// # }
  /// ```
  ```
- **Hidden lines:** prefix with `# ` (note the space) to compile but not display. Escape a literal `#` as `##`. **Never hide a line the reader actually needs to see to use the API correctly** — sanity check by re-reading only the visible lines.
- **Code-fence attributes:**
  - `should_panic` — must panic to pass. **Always add context so it can't silently match the wrong panic** (a bare `should_panic` passes on *any* panic).
  - `no_run` — compiles, doesn't execute (network/hardware/long-running examples).
  - `compile_fail` — must fail to compile (documents a type-system guarantee).
  - `ignore` — skipped entirely; use sparingly, prefer `text` for non-Rust snippets or `#` to hide setup.
  - `text` — non-Rust, no compilation, no highlighting.
  - Non-Rust languages: use the language tag (` ```c `) or `custom,{class=language-c}`.
  - Edition tags: `edition2021`, `edition2024`, etc.; `standalone_crate` to opt a doctest out of 2024-edition merging.
- Every public item should have at least one `# Examples` doctest (C-EXAMPLE). Its purpose is often to show **why** you'd reach for the item, not merely the call syntax.

## 8. Lints and CI enforcement

Add at the crate root (adjust `deny`/`warn` by maturity — see [ladder](#maturity-ladder)):

```rust
#![warn(missing_docs)]
#![deny(rustdoc::broken_intra_doc_links)]
#![warn(rustdoc::all)]
```

Key lints to know:

| Lint | Default | Catches |
|---|---|---|
| `missing_docs` (rustc) | allow | Public items with no docs. |
| `rustdoc::broken_intra_doc_links` | warn | Unresolved `` [`Link`] `` targets. |
| `rustdoc::private_intra_doc_links` | warn | Public item linking to a private item. |
| `rustdoc::missing_crate_level_docs` | allow | No `//!` at crate root. |
| `rustdoc::private_doc_tests` | allow | Doctest on a private item. |
| `rustdoc::invalid_codeblock_attributes` | warn | Typos like `should-panic`. |
| `rustdoc::invalid_rust_codeblocks` | warn | Empty/unparseable Rust fences. |
| `rustdoc::bare_urls` | warn | Raw URL not wrapped in `<...>`. |
| `rustdoc::redundant_explicit_links` | warn | Explicit link identical to automatic resolution. |

Clippy pedantic doc lints worth enabling: `missing_errors_doc`, `missing_panics_doc`, `missing_safety_doc`, `doc_markdown`.

CI: fail the build on any doc warning and run doctests.
```bash
RUSTDOCFLAGS="-D warnings" cargo doc --no-deps
cargo test --doc
```

## 9. Presentation and feature-gating attributes

- **`#[doc(hidden)]`** — omit an item from rendered docs (e.g. an internal `From<PrivateError>` impl needed only for `?` to compile, or internal-only macros). Complements `pub(crate)`, which removes an item from the public API entirely (C-HIDDEN).
- **`#[doc(inline)]` / `#[doc(no_inline)]`** on `use` — controls whether a re-export's docs are inlined vs. shown as a "Re-exports" line. A `pub use` of a dependency's item is **not** inlined by default; add `#[doc(inline)]` to inline it. Note: `hidden`/`alias`/`inline`/`no_inline` are not inherited through inlined re-exports — repeat them if needed.
- **Feature-gate badges** ("Available on feature X only"), stable-compatible pattern:
  ```rust
  #![cfg_attr(docsrs, feature(doc_cfg))]

  #[cfg(feature = "rt")]
  #[cfg_attr(docsrs, doc(cfg(feature = "rt")))]
  pub mod runtime {}
  ```
  Build locally with `RUSTDOCFLAGS="--cfg docsrs" cargo +nightly doc --all-features`. (`doc_auto_cfg` can generate these automatically from `#[cfg]` once stabilized — check current channel status before relying on it being stable.)
- **`#[deprecated(since = "x.y.z", note = "use `bar` instead")]`** — rustc warns on use, rustdoc renders the banner. Applies to fns/methods/impls/consts/types/fields/variants and is inherited by module children. To land a deprecation without breaking `-D warnings` builds elsewhere, gate it: `#[cfg_attr(feature = "deprecated", deprecated = "...")]`.
- Crate-level cosmetic attributes: `#![doc(html_logo_url = "...")]`, `html_favicon_url`, `html_playground_url`, `issue_tracker_base_url`, `test(no_crate_inject)`, `test(attr(deny(warnings)))`.

## 10. docs.rs conventions and metadata

`Cargo.toml` (`[package]`) — always fill for anything published (C-METADATA): `description`, `license`, `repository`, `keywords`, `categories`, `readme`. Only add `documentation`/`homepage` if they point somewhere *other* than docs.rs/the repo — don't duplicate.

Customize the docs.rs build:
```toml
[package.metadata.docs.rs]
all-features = true
rustdoc-args = ["--cfg", "docsrs"]
# optional: features = ["full"], default-target, targets = [...]
```
Verify locally with `cargo docs-rs` to catch docs.rs-only build failures before publishing.

## 11. Scraped examples

If the crate ships an `examples/` directory, `cargo doc --scrape-examples` (auto-enabled on docs.rs when `examples/` exists) pulls real usages of each public item into that item's doc page. Write example binaries with this in mind — clean, idiomatic call sites double as documentation.

## 12. Local generation commands

```bash
cargo doc --open --no-deps                        # build + open just this crate
RUSTDOCFLAGS="-D warnings" cargo doc --no-deps     # fail on any warning (broken links, etc.)
cargo test --doc                                   # run only doctests
cargo doc --document-private-items                 # include private items (default for bin targets)
```

## 13. Ecosystem tooling

Reach for these when the user's ask goes beyond hand-writing doc comments:

- **README sync:** `cargo-readme` / `cargo-rdme` (generate/update README from crate docs, keeping examples tested and links in sync) / `cargo-doc2readme`.
- **API-surface / breaking-change safety:** `cargo-semver-checks` (lints rustdoc JSON for semver violations pre-publish, has a GitHub Action) and `cargo-public-api` (diff the public API surface, snapshot-testable).
- **Link checking:** `lychee` (fast async, CI-friendly) or `cargo-deadlinks`.
- **Long-form guides/tutorials:** mdBook — use it for conceptual/tutorial content; rustdoc stays focused on API reference.

## 14. Binaries and CLI tools

Binaries differ from libraries in what gets documented and how:

- `cargo doc` documents binary targets too, and **enables `--document-private-items` by default for bin targets** (most of a binary's code is private). Still write a strong `//!` crate-level doc (purpose, usage, examples) — it's the most valuable part for readers.
- **clap derive → `--help` mapping:** a `///` doc comment has three parts — summary line, a *blank* line, then detail. The summary becomes short help (`-h`); if (and only if) a blank line is present, the full comment becomes long help (`--help`). No blank line → no long help is set. `#[clap(long_about = None)]` clears the doc comment so only the short `about` shows for both `-h`/`--help`. `#![deny(missing_docs)]` will catch CLI args missing help text.
- **`#[arg(verbatim_doc_comment)]`** disables clap's default preprocessing (whitespace/blank-line stripping, paragraph rewrapping, trailing-period removal) — needed to preserve ASCII art, tables, or exact line breaks. It still strips one leading space after `///`.
- **Man pages** via `clap_mangen`, generated from the same `Command` used at runtime (single source of truth). Typical `build.rs`:
  ```rust
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
  (Prefer a `cargo xtask` over `build.rs` if the extra build-time cost matters.)
- **Shell completions** via `clap_complete::generate(shell, &mut cmd, name, &mut stdout)` for bash/zsh/fish/elvish/powershell — ahead-of-time from `build.rs`/xtask, or dynamically behind the `unstable-dynamic` feature.
- Keep `--help`, bare invocation, and `man <bin>` telling the same story — derive all three from one CLI definition.

## 15. Accessibility and formatting

- Only use `#`-level headings for recognized sections inside a doc comment; don't skip levels or invent multiple H1s per item.
- Always tag code fences with a language (or `text`) — an untagged fence is treated as Rust and will fail to compile as a doctest.
- Wrap bare URLs in `<...>`. Prefer tables and reference-style links for long content.

---

## Maturity ladder

Use this to scope the work and to tell the user what's done vs. what's still available as a next step — don't silently do Stage 3 work when the user only asked for Stage 1.

**Stage 1 — Baseline (do this for any crate):**
1. `//!` crate-level doc: what/when/how + one realistic tested example.
2. Fill `Cargo.toml` metadata (`description`, `license`, `repository`, `keywords`, `categories`, `readme`).
3. `#![warn(missing_docs)]` + `#![deny(rustdoc::broken_intra_doc_links)]`.
4. Every public item: summary line + `# Examples`.

**Stage 2 — Rigor (libraries / public APIs):**
1. `# Errors` on every `Result`-returning fn, `# Panics` where applicable, `# Safety` on every `unsafe fn`.
2. Examples use `?` with hidden boilerplate; show *why*, not just *how*.
3. Raw URLs/type names → intra-doc links; hide non-API impls with `#[doc(hidden)]`.
4. Escalate `missing_docs` to `deny`; enable Clippy pedantic doc lints.
5. docs.rs metadata (`all-features`, `--cfg docsrs`) + `#[doc(cfg(...))]` badges for feature-gated items.
6. CI: `RUSTDOCFLAGS="-D warnings" cargo doc --no-deps` + `cargo test --doc`.

**Stage 3 — Excellence:**
1. `_documentation` module or mdBook for design rationale, comparisons, migration guides.
2. Scraped examples from a well-structured `examples/` directory.
3. `cargo-semver-checks` and/or `cargo-public-api` gating releases; maintained CHANGELOG (C-RELNOTES).
4. `#[deprecated(since, note)]` for graceful evolution; `lychee` for external link rot.
5. README kept in sync via `cargo-rdme`.

## Caveats to flag when relevant

- `#[doc(cfg(...))]` / `doc_auto_cfg`, `rustdoc::missing_doc_code_examples`, and rustdoc JSON output are nightly/unstable as of this writing — check current stabilization status before promising stable-only behavior. The `docsrs` cfg gate is a community convention, not a language feature.
- `cargo-semver-checks` / `cargo-public-api` consume unstable rustdoc JSON and are pinned to specific toolchains — expect occasional breakage on Rust upgrades.
- Hidden (`#`) doctest lines run but aren't shown; a passing doctest can still hide a broken *visible* example — always sanity-check the visible-only version.
- `should_panic` without an expected-message constraint passes on any panic, masking regressions — always constrain it.
- clap's doc-comment mapping and `verbatim_doc_comment` behavior described here target clap v3.2+/v4 — verify against the project's actual clap version.
