# ADR-002: Distinguish caller parameters from conventional AWK locals

Date: 2026-09-09

## Status

Accepted

## Context

Portable AWK has no dedicated local-variable declaration for user-defined
functions.  The long-standing portable convention is to add extra formal
parameters that normal callers intentionally omit and then use those formals as
function-local storage:

```awk
function parse(line, separator,    fields, count) {
```

From the language's perspective, `line`, `separator`, `fields`, and `count` are
all formal parameters.  From the program's interface perspective, only `line`
and `separator` are intended caller inputs; `fields` and `count` are local
implementation state by convention.

Whitespace is commonly used to visually separate these groups, but whitespace
does not create a semantic boundary in AWK.  A documentation tool therefore
cannot honestly infer public-versus-local intent merely from spacing.

The AWK documentation standard introduces `@param` for caller-visible formals
and `@local` for conventional omitted formals.  The filter needs one canonical
interpretation of those directives so source documentation, validation, and
synthesized declarations remain aligned.

## Decision Drivers

- Preserve portable AWK's conventional-local technique.
- Avoid pretending that whitespace changes AWK semantics.
- Make the intended caller interface explicit in maintained source.
- Allow the filter to validate documentation drift against the actual function
  declaration.
- Prevent conventional locals from appearing as public arguments in generated
  Doxygen signatures.
- Keep source documentation natural to AWK authors rather than exposing
  pseudo-C++ implementation details.

## Decision

For a documented AWK function, `@param` SHALL identify a formal parameter that
is part of the intended caller-visible interface.  `@local` SHALL identify a
formal parameter that normal callers intentionally omit so that the function can
use it as local storage.

For example:

```awk
## @fn parse(line, separator)
## @param line Record to parse.
## @param separator Field separator.
## @local fields Scratch array populated while parsing.
## @local count Number of fields discovered.
function parse(line, separator,    fields, count) {
```

The filter SHALL parse the formal parameter names from the AWK declaration and
validate that every documented `@param` and `@local` refers to a declared formal.
The filter SHALL diagnose duplicate documentation, unknown documented formals,
or incompatible ordering when those conditions would make the intended
interface ambiguous.

The filter SHALL NOT classify a formal as local solely because it follows an
unusually large whitespace gap.  Formatting MAY be used as a supporting
readability convention, but `@local` is the authoritative maintained-source
statement of local intent.

The generated public function signature SHALL contain `@param` formals only.
Documented `@local` names MAY be preserved in descriptive documentation if that
helps readers understand implementation state, but they SHALL NOT be emitted as
caller-visible parameters.

Normal callers that explicitly supply values for documented `@local` formals are
relying on behavior outside the documented public contract unless later
project-specific governance explicitly promotes those formals to caller-visible
parameters.

The project SHALL preserve declaration order.  Caller-visible parameters SHALL
appear in generated signatures in their AWK declaration order, and conventional
locals SHALL be documented in their declaration order.

## Considered Alternatives

### Infer locals from spacing

The filter could treat formals following several spaces as locals.  This was
rejected because AWK does not assign semantic meaning to that whitespace.  Such
an inference would encode a style convention as language truth and could silently
misclassify valid source.

### Treat every formal as public

This would accurately reflect AWK syntax but poorly reflect the programmer's
interface intent.  Generated Doxygen signatures would expose scratch variables
and local arrays as if callers were expected to provide them.

### Require non-portable local-variable syntax

Some AWK implementations offer extensions that can improve local-variable
expression.  Requiring them would violate the project's portable-AWK default and
would solve a documentation problem by narrowing the implementation language.

### Hide local formals from source documentation

The filter could document only public parameters and ignore conventional locals.
This was rejected because significant local arrays and scratch variables often
carry important lifecycle, ownership, or mutation assumptions worth preserving.

## Consequences

AWK authors receive a precise vocabulary for documenting the difference between
syntax and intended interface.  Doxygen-facing signatures remain useful to
callers instead of exposing implementation-only formals.

The filter must maintain per-function formal metadata and compare documented
names with declaration names.  This adds modest parser state but remains far
short of general AWK parsing.

Formatting alone is deliberately insufficient evidence.  Existing AWK source
that uses visual spacing but lacks `@local` documentation will require explicit
metadata before the filter can claim those formals are locals.

Regression coverage must include caller parameters, conventional scalar locals,
conventional local arrays, missing names, duplicate names, and ordering-related
diagnostics.

## Related Decisions

- Builds on ADR-001, which limits `awk-doxygen` to an explicitly governed subset
  of AWK structure.
- ADR-003 uses the `@param` / `@local` distinction when synthesizing the
  authoritative Doxygen-facing function signature.
