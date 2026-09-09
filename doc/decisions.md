# Architecture Decisions

This document provides concise summaries of the architecture decisions governing
`awk-doxygen`.  The ADRs themselves remain authoritative; these summaries are
navigation aids rather than substitutes for the full decisions.

## ADR-000: Capability scope and epistemic honesty

The project prioritizes accuracy, explicit capability boundaries, evidence,
separation of concerns, and resistance to over-commitment or performative
agreement.  Claims about supported syntax, portability, validation, or generated
behavior must therefore match what the implementation and tests actually prove.
Inherited scaffolding, planned behavior, and implemented behavior must remain
clearly distinguished.  See
[`ADR-000`](adr/ADR-000-capability-scope-and-epistemic-honesty.md).

## ADR-001: Define the supported AWK documentation scope

`awk-doxygen` is a documentation compiler for an intentionally small, governed
subset of AWK rather than a complete language parser.  The first implementation
focuses on file documentation and named functions, while `@var` and `@rule`
provide vocabulary for significant globals and rule constructs that may be
implemented later under explicit contracts.  The filter prefers explicit author
intent and conservative recognition over speculative inference, and portable AWK
is the default implementation floor.  See
[`ADR-001`](adr/ADR-001-define-supported-awk-documentation-scope.md).

## ADR-002: Distinguish caller parameters from conventional AWK locals

Portable AWK commonly uses omitted formal parameters as function-local storage,
but whitespace does not make those formals semantically local.  `@param`
therefore identifies caller-visible parameters, while `@local` explicitly marks
formals normal callers omit for local storage.  The filter validates both against
the real AWK declaration and excludes `@local` formals from generated public
signatures.  See
[`ADR-002`](adr/ADR-002-distinguish-caller-parameters-from-conventional-locals.md).

## ADR-003: Use synthesized declarations as authoritative Doxygen signatures

For each recognized AWK function, the generated pseudo-C++ declaration is the
single authoritative signature presented to Doxygen.  Source `@fn` metadata is
retained for validation but suppressed from generated output so it cannot
compete with the synthesized signature.  Only caller-visible `@param` formals
appear in that declaration; conventional `@local` formals remain implementation
documentation rather than public arguments.  See
[`ADR-003`](adr/ADR-003-use-synthesized-declarations-as-authoritative-doxygen-signatures.md).

## ADR-004: Build and release a versioned doxygen-awk artifact

The maintained and released filter is named `doxygen-awk.awk`.  Release builds
will create `dist/doxygen-awk.awk`, add version/build/commit provenance as
comments, and publish a standard `doxygen-awk.awk.sha256` checksum without adding
runtime metadata state.  Automatic releases remain disabled until the AWK
implementation, AWK regression suite, generated artifact, checksum, and release
workflow all describe the same verified consumer contract.  See
[`ADR-004`](adr/ADR-004-build-and-release-a-versioned-doxygen-awk-artifact.md).

## ADR-005: Use small behavior-focused regression fixtures

Regression tests are organized around small source fixtures and golden generated
output so each failure identifies a narrow public contract.  Diagnostics are
tested independently where useful, and the same semantic suite will exercise
both maintained source and generated release bytes.  Portable-AWK claims should
be supported by more than one AWK implementation where practical, and inherited
Bash fixtures are transitional scaffolding rather than evidence of AWK support.
See
[`ADR-005`](adr/ADR-005-use-small-behavior-focused-regression-fixtures.md).

## ADR-006: Treat @var as authoritative global documentation

A maintained `@var` block is itself the authoritative documentation declaration
for one significant AWK global variable or array; no following assignment or
first use is required or inferred.  The filter rewrites the structural line to a
Doxygen declaration such as `@var AwkValue name`, preserving source-line
correspondence while keeping scalar-versus-array shape, lifecycle, ownership,
and mutability in maintained prose.  `@var` names must be valid portable AWK
identifiers, and conventional function-local formals remain governed by
`@local`.  See
[`ADR-006`](adr/ADR-006-treat-var-as-authoritative-global-documentation.md).

## ADR-007: Represent AWK rules as file-local synthetic functions

Maintained source uses `@rule` to name significant `BEGIN`, `END`, and ordinary
AWK rules without pretending those constructs are source-level functions.  The
filter represents supported action-bearing rules to Doxygen as file-local
`static void` synthetic functions, using distinct generated prefixes for
`BEGIN`, `END`, and ordinary/action-only rules while preserving the declaration
on the original rule-header line.  The first implementation deliberately leaves
pattern-only rules outside the recognition boundary and requires consumers to
set `EXTRACT_STATIC = YES` so generated rule entities appear in Doxygen output.
See
[`ADR-007`](adr/ADR-007-represent-awk-rules-as-file-local-synthetic-functions.md).

## ADR-008: Publish ephemeral reference documentation with pinned filters

Generated Doxygen HTML is disposable output under `doc/reference/` and is never
committed merely to support GitHub Pages.  Documentation dependencies are
isolated in `dependencies-docs.txt`, synchronized through a directly bootstrapped
and SHA-256-pinned bashdeps release, and consumed from `vendor/`; stable Pages
publication uses pinned released `awk-doxygen` and `bash-doxygen` artifacts rather
than repository-local filter source.  Dependency synchronization may use the
network, while verification and `make docs` remain non-repairing after state is
prepared.  See
[`ADR-008`](adr/ADR-008-publish-ephemeral-reference-documentation-with-pinned-filters.md).

## ADR-009: Continuously dogfood current and released filters

Stable Pages publication stays pinned, while two separate canaries detect
regressions earlier.  Pull-request and `main` CI generate the same reference
corpus with current repository `doxygen-awk.awk`, and a release-published canary
downloads, verifies, and exercises the exact released `doxygen-awk.awk` asset.
Neither canary mutates the stable dependency pin, and both complement rather than
replace focused parser fixtures.  See
[`ADR-009`](adr/ADR-009-continuously-dogfood-current-and-released-filters.md).
