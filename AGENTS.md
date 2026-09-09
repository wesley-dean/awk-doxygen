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
conflicts with an existing decision, identify the conflict and determine
whether a new or superseding ADR is required.

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
functions, so parser changes must keep source documentation and real AWK formals
aligned.

## Architecture and Scope

`awk-doxygen` is a documentation compiler for an intentionally small subset of
AWK structure.  It is not intended to become a complete AWK parser.

Prefer conservative recognition over speculative inference.  When source does
not provide enough information to make a structural claim reliably, require
explicit documentation metadata or leave the construct undocumented rather than
inventing semantics.

The implemented baseline is centered on file blocks and named AWK function
headers whose complete parenthesized formal list appears on one physical line.
The opening brace may appear on that same line or after newline/comment-only
separator lines.  Public parameters and conventional omitted-formal locals are
distinct concepts: `@param` documents caller-supplied formals and `@local`
documents formals used as local storage by convention.  Every declared formal in
a documented function must be classified explicitly.

Formal lists split across physical lines remain outside the portable parser
boundary.  Do not broaden that boundary merely because one supported AWK
implementation accepts a continuation form that POSIX does not specify in the
function grammar.

`@var` and `@rule` belong to the maintained documentation vocabulary, but their
Doxygen representation is not implemented yet.  Do not infer globals, arrays,
`BEGIN`, `END`, or ordinary pattern/action rules opportunistically.  Expand
those capabilities only under governing ADRs and focused regression fixtures.

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
function braces, and self-documentation when changing parser structure.

Run the suite with a selected interpreter using, for example:

```sh
make test AWK_BIN=mawk
make test AWK_BIN=gawk
```

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

Automatic release publication is currently disabled during development.  Keep
the release workflow, artifact names, checksum names, and tested build boundary
aligned so releases can be enabled deliberately when appropriate.

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
