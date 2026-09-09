# ADR-001: Define the supported AWK documentation scope

Date: 2026-09-09

## Status

Accepted

## Context

`awk-doxygen` is derived from the architecture of `bash-doxygen`, which succeeds
by acting as a documentation compiler rather than attempting to parse an entire
language.  The Bash filter buffers an explicit Doxygen block, recognizes a
small set of declarations that can reasonably follow that block, validates
source-side intent where possible, and emits a Doxygen-friendly pseudo-C++
representation.

AWK presents a different structural problem.  Named functions have explicit
formal parameters, but variables are created through use rather than declaration,
local variables are commonly represented by omitted formals, and much program
behavior is expressed in `BEGIN`, `END`, and anonymous pattern/action rules.
A filter that tries to infer all AWK semantics from arbitrary source text would
quickly become a partial parser while still being unable to establish several
important properties reliably.

The repository was initially seeded from `bash-doxygen`, so inherited source and
fixtures must not implicitly define the AWK contract.  The project needs an
explicit boundary before implementation begins.

## Decision Drivers

- Preserve the documentation-led model proven useful by `bash-doxygen`.
- Avoid claiming to be a complete AWK parser.
- Prefer explicit author intent over speculative source inference.
- Support the constructs that provide high documentation value first.
- Keep the implementation portable, inspectable, and regression-oriented.
- Allow later support for AWK-specific constructs without forcing them into a
  function-shaped model prematurely.
- Keep generated Doxygen structure separate from executable AWK semantics.

## Decision

`awk-doxygen` SHALL be a documentation compiler for an intentionally small,
explicitly governed subset of AWK structure.  It SHALL NOT claim to parse or
semantically understand arbitrary AWK programs.

The first implementation scope SHALL center on documented named functions and
file-level documentation.  The filter SHALL understand enough AWK function
syntax to associate a contiguous Doxygen block with a following function
declaration, validate the documented function name and formal names, distinguish
caller-supplied parameters from documented conventional locals, and synthesize a
Doxygen-facing declaration.

The maintained documentation vocabulary SHALL include these structural concepts:

- `@file` for file-level documentation;
- `@fn` for AWK functions;
- `@param` for caller-visible formal parameters;
- `@local` for conventional omitted formals used as local storage;
- `@var` for significant global variables or arrays; and
- `@rule` for stable documentation identities associated with `BEGIN`, `END`,
  and ordinary pattern/action rules.

Support for `@var` and `@rule` in the filter MAY be introduced after the initial
function implementation, but their semantics SHALL be governed explicitly before
code begins inferring or emitting those constructs.

The filter SHALL preserve ordinary Doxygen commands that it does not need to
translate for structural correctness.  It SHALL parse source-side structural
metadata only to the extent necessary for association, validation, or generated
representation.

The filter SHALL prefer a false negative to a false semantic claim.  When a
source construct cannot be classified reliably within the governed subset, the
filter SHOULD leave it undocumented or emit a diagnostic rather than guess.

Portable AWK SHALL be the default compatibility floor for production filter
source unless a later ADR explicitly changes that boundary.  Implementation-
specific extensions MUST NOT enter the core filter accidentally.

## Considered Alternatives

### Build a general AWK parser

A complete grammar or AST could provide richer structural information.  This was
rejected because it would materially increase implementation scope and
maintenance burden while changing the nature of the project.  The goal is to
make intentionally documented AWK indexable by Doxygen, not to provide an AWK
front end.

### Treat every assignment as a variable declaration

AWK variables come into existence through use, and assignments occur throughout
normal executable code.  Treating assignments as declarations would produce
misleading reference documentation and would require the filter to infer scope,
shape, ownership, and lifecycle from insufficient evidence.

### Treat BEGIN, END, and ordinary rules as functions

Doxygen understands functions, so anonymous rules could be disguised as
synthetic functions.  This was rejected as a source-side model because AWK rules
are not functions.  The project may synthesize Doxygen-facing entities later,
but maintained documentation will retain the distinct `@rule` concept.

### Require GNU awk and use implementation-specific parsing helpers

GNU awk provides useful extensions, but requiring it would narrow portability
without evidence that the documentation problem requires those extensions.
Portable AWK remains the default until a concrete need justifies a different
tradeoff.

## Consequences

The initial implementation remains deliberately small and reviewable.  Named
functions can receive rich Doxygen documentation without forcing the project to
solve global-variable inference or anonymous-rule representation at the same
time.

Some intentionally documented AWK constructs may not be emitted by early
versions of the filter.  That limitation is accepted and should be stated
plainly rather than obscured by speculative support.

Future functionality for variables, arrays, `BEGIN`, `END`, or pattern/action
rules will require explicit contracts and focused regression fixtures.  The
project can therefore expand incrementally while preserving epistemic honesty
about what each release actually understands.

## Related Decisions

- Related to ADR-000, which requires capability honesty, evidence-oriented
  reasoning, and explicit scope boundaries.
- ADR-002 defines the distinction between caller parameters and conventional
  AWK locals inside the initial function scope.
- ADR-003 defines how supported functions are represented to Doxygen.
