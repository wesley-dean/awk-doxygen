# ADR-001: Keep documented and synthesized parameter names aligned

Date: 2026-08-15

## Status

Proposed

## Intent and Documentation Posture

This ADR records the invariant used when Bash-oriented parameter names must be
translated into identifiers that Doxygen can associate with a synthesized
pseudo-C++ declaration.  The decision is deliberately narrow: it governs the
relationship between documented `@param` names and emitted declaration names;
it does not expand the filter into a Bash parser.

## Context

`bash-doxygen` accepts natural Bash documentation and converts documented Bash
declarations into a Doxygen-friendly pseudo-C++ representation.  Bash authors
may describe positional parameters using names such as `$1` and `$2`, while
those strings are not suitable parameter identifiers in the synthesized
pseudo-C++ declaration.

The filter already sanitizes parameter names while constructing a declaration.
For example, `$1` becomes `_1`.  Before this decision, the documentation block
was emitted unchanged, so Doxygen received `@param $1` alongside a declaration
containing `String _1`.  Doxygen validates parameter documentation against the
associated declaration, making that disagreement observable downstream.

The same problem can occur when distinct source names sanitize to the same
identifier.  For example, `--foo` and `foo` both initially sanitize to `foo`;
the declaration generator disambiguates the second occurrence as `foo_2`.
Documentation must use that same resolved name rather than repeating the
sanitization independently.

## Decision Drivers

- Preserve natural Bash documentation such as `@param $1` in source files.
- Emit a representation that Doxygen can associate reliably with the generated
  declaration.
- Keep declaration generation and documentation rewriting deterministic.
- Avoid duplicated sanitization logic that could diverge when names collide.
- Preserve parameter descriptions and ordering while changing only the emitted
  parameter identifier.
- Keep the filter small and inspectable rather than introducing a general Bash
  parser.

## Decision

For each documented function, the filter SHALL resolve every source `@param`
name to one canonical emitted identifier before emitting either the documentation
block or the pseudo-C++ declaration.

The canonical mapping SHALL apply the existing identifier sanitization rules and
the existing uniqueness rules in source order.  Both outputs SHALL consume the
same resolved name:

```text
Source:
@param $1 First value.

Filtered representation:
@param _1 First value.
int example(String _1);
```

The filter SHALL rewrite only the parameter-name token in the emitted
`@param` line.  The source file is not modified, and the remainder of the
parameter documentation is preserved.

When multiple source names sanitize to the same identifier, the documentation
and declaration SHALL use the same deterministic unique names.  For example,
`--foo` followed by `foo` becomes `foo` followed by `foo_2` in both places.

## Considered Alternatives

### Require Doxygen-safe names in Bash source documentation

Downstream projects could write `@param _1` instead of `@param $1`.  This was
rejected because it exposes an implementation detail of the filter and makes
Bash documentation less natural to its authors and readers.

### Rewrite positional parameters only

The immediate defect was observed with `$N` names, so the filter could special
case only positional parameters.  This was rejected because any source name
that requires sanitization or uniqueness can create the same documentation to
declaration mismatch.

### Sanitize documentation independently during emission

The documentation emitter could run the sanitization algorithm again.  This was
rejected because collision handling is order-dependent; resolving names twice
creates an unnecessary opportunity for the declaration and documentation paths
to diverge.

### Suppress parameter names in generated documentation

Removing `@param` directives would avoid name validation, but would discard
useful structured documentation and reduce the value of the generated reference.

## Consequences

Bash authors can continue to document positional parameters and option-like
parameter names using the vocabulary natural to the source code.  The generated
representation becomes internally consistent, allowing Doxygen to associate
parameter documentation with the synthesized declaration.

The filter now maintains a small amount of per-documentation-block mapping
state: source parameter names, their documentation-line positions, and their
resolved emitted names.  That state is reset with the rest of the documentation
block.

Regression coverage must compare both sides of the invariant.  Tests therefore
exercise positional parameters and a sanitization collision, verifying that the
emitted `@param` tokens exactly match the declaration identifiers.

## Open Questions and Follow-Ups

A future integration test may invoke Doxygen itself when the project establishes
a stable Doxygen test environment.  The filter-level regression is the primary
test for this decision because the invariant is fully observable in the
intermediate representation.

If future Doxygen versions support a representation that preserves Bash-native
parameter spelling without a synthesized identifier, this decision may be
revisited.

## Related Decisions

- Related to: ADR-000, which requires capability honesty and evidence-oriented
  reasoning.
- Related to: GitHub issue #12, "Parameterized Bash functions disappear from
  Doxygen output when @param uses $N names."
