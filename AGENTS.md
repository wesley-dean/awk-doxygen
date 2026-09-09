# AGENTS.md

## Repository Purpose

`awk-doxygen` provides a documentation-led Doxygen filter for AWK source.
The project is derived from `wesley-dean/bash-doxygen`, but it is an
independently governed project with its own language contracts, releases,
fixtures, and architecture decisions.

The repository was initially seeded from `bash-doxygen`.  Until the AWK filter
implementation replaces the inherited Bash-oriented scaffold, do not represent
the inherited filter, fixtures, Makefile targets, or release artifact as a
working AWK implementation.

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

## Architecture and Scope

`awk-doxygen` is a documentation compiler for an intentionally small subset of
AWK structure.  It is not intended to become a complete AWK parser.

Prefer conservative recognition over speculative inference.  When source does
not provide enough information to make a structural claim reliably, require
explicit documentation metadata or leave the construct undocumented rather than
inventing semantics.

The initial supported model is centered on documented AWK functions.  Public
parameters and conventional omitted-formal locals are distinct concepts.
`@param` documents caller-supplied parameters; `@local` documents formals used
as local storage by convention.  Additional support for globals, arrays,
`BEGIN`, `END`, and ordinary pattern/action rules must follow the governing ADRs
rather than being inferred opportunistically during implementation.

## Portability

Portable AWK is the default compatibility floor unless an accepted ADR states
otherwise.  Avoid GNU awk, mawk, BusyBox awk, or other implementation-specific
features in production code without an explicit decision and corresponding
documentation.

When practical, regression tests should exercise more than one AWK
implementation so portability claims are supported by observable evidence.

## Testing

Regression tests should be small and behavior-focused.  Prefer one fixture per
observable contract, with golden Doxygen-facing output and separate diagnostic
cases where appropriate.

Tests protect public behavior, not internal helper structure.  Do not couple
fixtures to implementation details merely to increase apparent coverage.

During the repository-establishment phase, inherited Bash-oriented fixtures are
transitional scaffolding only.  They are not evidence that `awk-doxygen`
correctly processes AWK.

## Build and Release

The intended consumer artifact is `doxygen-awk.awk` with a corresponding
SHA-256 checksum.  Build provenance should remain metadata rather than runtime
state unless a later ADR establishes a runtime metadata interface.

Do not enable or publish a release until the maintained AWK implementation,
AWK-oriented regression suite, build artifact, checksum, and release workflow
agree on the same consumer contract.

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
