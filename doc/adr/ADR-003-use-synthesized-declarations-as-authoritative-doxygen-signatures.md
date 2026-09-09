# ADR-003: Use synthesized declarations as authoritative Doxygen signatures

Date: 2026-09-09

## Status

Accepted

## Context

`awk-doxygen` must translate AWK source into a representation Doxygen can index.
AWK function declarations do not carry static parameter types, and the project
uses source-side directives such as `@fn`, `@param`, and `@local` to express and
validate documentation intent.

If the filter emits both a source-side `@fn` signature and a synthesized
pseudo-C++ declaration, Doxygen may receive two competing structural
representations of the same function.  That risk is particularly visible when
source documentation names only caller-visible parameters while the AWK
function declaration also contains conventional local formals.

The project needs one authoritative generated function signature and one place
where parameter normalization and public-interface filtering occur.

## Decision Drivers

- Give Doxygen one authoritative structural signature per documented function.
- Preserve `@fn` as useful source-side intent and mismatch metadata.
- Keep conventional `@local` formals out of caller-visible generated signatures.
- Avoid duplicated structural representations that can drift.
- Preserve descriptive Doxygen commands wherever translation is unnecessary.
- Keep generated declarations obviously synthetic rather than pretending AWK
  has static types.

## Decision

For every successfully recognized documented AWK function, `awk-doxygen` SHALL
synthesize one Doxygen-facing pseudo-C++ declaration and SHALL treat that
declaration as the sole emitted function signature.

Source `@fn` directives SHALL be parsed for maintained-source validation but
SHALL NOT be emitted into the generated function documentation block.

The synthesized declaration SHALL contain only caller-visible parameters
identified by `@param` under ADR-002.  Conventional `@local` formals SHALL NOT
appear as public parameters.

The pseudo-language type names used in generated declarations SHALL be clearly
synthetic implementation vocabulary.  They exist only to give Doxygen a stable
shape to index and MUST NOT be described as AWK static types.

A function documented as:

```awk
## @fn normalize(value)
## @brief Normalizes a value.
## @param value Value to normalize.
## @local result Scratch value.
## @returns The normalized value.
function normalize(value,    result) {
    result = value
    return result
}
```

shall produce a Doxygen-facing representation equivalent in structure to:

```cpp
/// @brief Normalizes a value.
/// @param value Value to normalize.
/// @returns The normalized value.
AwkValue normalize(AwkValue value);
```

The exact comment form and pseudo-type spelling are implementation details until
locked by regression fixtures, but the structural invariant is not: one emitted
signature, caller parameters only, and no emitted source `@fn` signature.

The filter SHALL preserve enough source metadata to diagnose mismatches between
`@fn` names and actual AWK function names even though `@fn` is suppressed from
the generated representation.

Where practical, generated output SHOULD preserve source line correspondence.
If a one-line AWK declaration is replaced by one synthesized declaration line,
the filter should avoid adding unnecessary structural lines that move later
Doxygen diagnostics away from the original source locations.

## Considered Alternatives

### Emit the source @fn directive unchanged

This was rejected because a source `@fn` directive can be less structurally
complete than the synthesized declaration and can disagree with the public
parameter list Doxygen should associate with the function.

### Rewrite and emit @fn in addition to the declaration

The filter could generate a normalized `@fn` signature matching the synthesized
declaration.  This was rejected because it would duplicate the same structural
information and create another invariant that must remain synchronized.

### Emit every AWK formal parameter

This would mirror syntax but violate ADR-002 by exposing conventional locals as
caller-visible parameters.

### Invent precise scalar or array types from source usage

This was rejected because AWK does not provide the static type information such
a declaration would imply.  The generated representation should provide only
the shape Doxygen needs, not speculative type analysis.

## Consequences

Generated function documentation has one authoritative structure, reducing the
chance of contradictory signatures in Doxygen output.

Source authors can continue using `@fn` for explicit intent and drift detection
without exposing that source metadata as a second generated signature.

The implementation must resolve the public parameter list before emitting either
parameter documentation or the synthesized declaration.  Tests must verify that
those two outputs use the same names and ordering.

Pseudo-type vocabulary becomes part of the generated artifact contract once
regression fixtures establish exact output.  Changes to that vocabulary should
therefore be treated as generated-interface changes rather than casual internal
refactoring.

## Related Decisions

- Builds on ADR-001, which defines the supported documentation/compiler scope.
- Builds on ADR-002, which distinguishes caller-visible parameters from
  conventional local formals.
