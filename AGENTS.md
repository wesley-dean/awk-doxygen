# AGENTS.md

## Repository Purpose

`awk-doxygen` provides a documentation-led Doxygen filter for AWK source.  The
project is derived from `wesley-dean/bash-doxygen`, but it is independently
governed with its own language contracts, releases, fixtures, and architecture
decisions.

The maintained filter is `doxygen-awk.awk`.  Do not describe planned support as
implemented behavior; claims about syntax, portability, validation, generated
output, and release artifacts must match the regression suite and governing
ADRs.

## Governing Documentation

Before proposing or making changes, review at minimum:

1. `README.md`
2. this file
3. `doc/documentation-standard.md`
4. every ADR in `doc/adr/*.md`
5. `doc/decisions.md`

Treat accepted ADRs as governance rather than suggestions.  Do not silently
contradict, supersede, or work around an accepted ADR.  If a requested change
conflicts with an existing decision, identify the conflict and determine whether
a new or superseding ADR is required.

## Documentation Standard

`doc/documentation-standard.md` is the normative source-documentation standard
for maintained AWK source in this repository and is intended to be reusable by
other AWK projects.

The project uses contiguous `##` Doxygen comment blocks.  Ordinary `#` comments
remain appropriate for narrow implementation annotations that are not part of
generated reference documentation.

The documentation model is intentionally verbose.  Preserve contracts,
assumptions, state ownership, portability constraints, failure behavior,
security boundaries, and architectural relationships rather than forcing a
future maintainer to infer them from executable code.

The filter itself is maintained AWK source and should comply with the same
standard.  Its regression suite includes strict self-validation of documented
functions and rules, so parser changes must keep source documentation and real
AWK structure aligned.

## Architecture and Scope

`awk-doxygen` is a documentation compiler for an intentionally small subset of
AWK structure.  It is not intended to become a complete AWK parser.

Prefer conservative recognition over speculative inference.  When source does
not provide enough information to make a structural claim reliably, require
explicit documentation metadata or leave the construct undocumented rather than
inventing semantics.

The implemented function baseline is centered on named AWK function headers
whose complete parenthesized formal list appears on one physical line.  The
opening brace may appear on that same line or after newline/comment-only
separator lines.  Public parameters and conventional omitted-formal locals are
distinct concepts: `@param` documents caller-supplied formals and `@local`
documents formals used as local storage by convention.  Every declared formal in
a documented function must be classified explicitly.

Formal lists split across physical lines remain outside the portable parser
boundary.  Do not broaden that boundary merely because one supported AWK
implementation accepts a continuation form that POSIX does not specify in the
function grammar.

Significant global variables and arrays are documented with standalone `@var`
blocks under ADR-006.  The `@var` block itself is authoritative: do not require,
scan for, or infer a following assignment, initializer, first use, or declaration
anchor.  Generated output uses the generic `AwkValue` pseudo-type for both
scalar-like and array-like globals.  Shape, lifecycle, ownership, mutability, and
initialization semantics remain maintained prose unless later governance adds
explicit metadata.

A conventional omitted function formal remains `@local`, not `@var`.

Significant AWK rules use stable source-side `@rule` identities under ADR-007.
Supported action-bearing rule headers are translated to file-local synthetic
Doxygen functions using generated prefixes that distinguish `BEGIN`, `END`, and
ordinary/action-only rules.  The generated declarations are indexing artifacts,
not callable AWK functions.

The initial rule parser recognizes only action-bearing rules whose opening action
brace is on the same physical line as the rule header.  It does not parse or
reproduce arbitrary pattern expressions.  Pattern-only rules remain valid source
and may be documented under the maintained standard, but the filter does not yet
synthesize Doxygen entities for them.  Do not widen that boundary by treating any
arbitrary source line following `@rule` as a recognized rule.

Generated rule functions are `static` so the same natural source identity can be
used independently in different AWK files.  Doxygen consumers therefore require
`EXTRACT_STATIC = YES` for rule entities to appear.

## Portability

Portable AWK is the default compatibility floor unless an accepted ADR states
otherwise.  Avoid GNU awk, mawk, BusyBox awk, or other implementation-specific
features in production code without an explicit decision and corresponding
documentation.

Do not use whole-array `delete array` in portable filter code.  Clear arrays by
iterating over their keys and deleting individual elements unless governance
changes the compatibility floor.

The active CI suite runs the filter under both `mawk` and GNU awk.  Portability
claims should continue to be supported by multiple implementations where
practical.

## Testing

Regression tests are small and behavior-focused.  Active AWK fixtures live
under:

```text
tests/awk/fixtures/
tests/awk/expected/
tests/awk/diagnostics/
```

The inherited Bash fixture directories are inactive historical scaffolding and
must not be reintroduced into the active regression path.

Tests protect public behavior, not internal helper structure.  Do not couple
fixtures to implementation details merely to increase apparent coverage.

The same semantic suite must exercise maintained source and the generated
`dist/doxygen-awk.awk` artifact.  Preserve tests for strict/non-strict
diagnostics, compact output, source-line correspondence, portable next-line
function braces, standalone documented globals, documented action-bearing rules,
and self-documentation when changing parser structure.

Global-state tests must continue to protect ADR-006's inference boundary: scalar
and array examples use the same generated pseudo-type, no following assignment
is required, unrelated following source is not consumed as a declaration, and
invalid `@var` identities are diagnosed.

Rule tests must continue to protect ADR-007's semantic boundary: `BEGIN`, `END`,
ordinary action-bearing, and action-only rules receive the correct file-local
synthetic prefix; source `@rule` metadata is suppressed; invalid identities are
diagnosed; pattern-only rules remain unsupported; and generated declarations stay
on the source rule-header line in default mode.

Run the suite with a selected interpreter using, for example:

```sh
make test AWK_BIN=mawk
make test AWK_BIN=gawk
```

## Documentation Dependencies and Publication

ADR-008 governs generated reference documentation.  Documentation-only external
artifacts live in `dependencies-docs.txt` and are materialized beneath `vendor/`
through a directly bootstrapped, SHA-256-pinned bashdeps release.

The stable documentation build intentionally consumes released filters from
`vendor/`, including the pinned `awk-doxygen` release rather than the repository's
maintained source file.  This is a downstream-consumer dogfood boundary, not an
accidental duplication of the local filter.

Use these targets deliberately:

```text
make deps-docs        synchronize documentation dependencies; may use network
make deps-docs-check  verify prepared documentation state; no repair
make docs             generate stable docs from pinned vendored filters
make docs-canary      generate docs with explicitly selected filter paths
make docs-clean       remove doc/reference/
```

`make docs` must not synchronize or repair dependencies.  A fresh checkout should
run `make deps-docs` first.  `doc/reference/` and `vendor/` are generated state and
must not be committed.

GitHub Pages regenerates `doc/reference/` from source and publishes that generated
tree.  It does not require committed HTML.

## Documentation Canaries

ADR-009 separates stable publication from proactive failure detection.

The current-source canary runs on pull requests and `main` and substitutes the
repository's maintained `doxygen-awk.awk` into the same Doxygen configuration used
for stable publication.  It should detect source-level integration regressions
before a release is cut.

The released-artifact canary runs when a GitHub release is published.  It must
download the exact `doxygen-awk.awk` release asset and checksum, verify those bytes,
and run the same reference generation with the released artifact.  Do not replace
this with a tag checkout; packaging and asset publication are part of the consumer
contract being tested.

Canary success does not automatically update `dependencies-docs.txt`.  Stable
publication pins change only through normal reviewed repository changes.

## Build and Release

The maintained consumer source and generated artifact are named:

```text
doxygen-awk.awk
dist/doxygen-awk.awk
```

`make build` is the canonical build interface.  `make checksums` produces
`dist/doxygen-awk.awk.sha256`.

Build provenance remains comments rather than executable AWK state.  Do not add
runtime variables, patterns, or `BEGIN` behavior merely to expose version or
build metadata.

Release publication may be enabled only while the release workflow, artifact
names, checksum names, and tested build boundary remain aligned with ADR-004.
The documentation release canary provides an additional check of exact published
filter bytes after each release.

## Engineering Approach

Prefer surgical, reviewable changes.  Do not introduce unrelated cleanup or
architecture changes merely because an alternative appears preferable.

For consequential behavior, interfaces, portability decisions, security
boundaries, compatibility decisions, or release contracts, add or update an ADR
unless existing governance already covers the decision.  ADRs prepared for
merge use `Accepted` status by project convention.  Update `doc/decisions.md`
when adding or materially changing an ADR.

Accuracy is more important than apparent completeness.  State uncertainty
plainly, distinguish evidence from inference, and do not claim support for
behavior that has not been implemented and verified.
