# ADR-002: Use synthesized declarations as the emitted function signature

Date: 2026-08-15

## Status

Proposed

## Intent and Documentation Posture

This ADR defines the boundary between source-side structural documentation and
the pseudo-C++ representation emitted for Doxygen.  It builds on ADR-001 by
ensuring that the synthesized declaration is not only internally consistent
with parameter documentation, but is also the single emitted function
signature that Doxygen is asked to interpret.

## Context

`bash-doxygen` accepts Bash-oriented Doxygen blocks and translates documented
Bash functions into pseudo-C++ declarations that Doxygen can index.  Bash
source may use `@fn name()` to make documented intent explicit and to allow the
filter to diagnose cases where the documented function name does not match the
Bash declaration that follows.

ADR-001 established that source `@param` names such as `$1` must be translated
to the same identifiers used by the synthesized declaration.  After that
change, a parameterized function could still produce contradictory structural
information such as:

```text
@fn example()
@param _1 First value.
@param _2 Second value.
int example(String _1, String _2);
```

The source `@fn example()` describes a zero-argument function while the
synthesized declaration describes a two-argument function.  The `@fn`
directive is useful while interpreting the Bash source, but becomes redundant
and potentially contradictory after the filter has generated the declaration
that immediately follows the documentation block.

This distinction matters because the filtered representation is a compilation
target rather than a verbatim copy of the source documentation.  Structural
commands that help the filter understand source intent do not necessarily
belong in the generated representation.

## Decision Drivers

- Preserve `@fn` as useful source-side intent and validation metadata.
- Ensure Doxygen receives one authoritative emitted function signature.
- Avoid contradictory zero-argument and parameterized signatures for the same
  documented function.
- Preserve existing mismatch diagnostics in normal and strict modes.
- Keep descriptive documentation commands such as `@brief`, `@details`,
  `@param`, `@returns`, and custom aliases unchanged unless translation is
  required for correctness.
- Keep the implementation small, explicit, and independent of a full Bash
  parser.

## Decision

For a documentation block that is successfully associated with a recognized
Bash function, `bash-doxygen` SHALL parse source `@fn` directives and use them
for source-side validation, but SHALL NOT emit those `@fn` directives into the
pseudo-C++ documentation block.

The synthesized pseudo-C++ declaration immediately following the documentation
block SHALL be the sole emitted function signature.

For example:

```bash
## @fn example()
## @brief Example parameterized function.
## @param $1 First value.
## @param $2 Second value.
example() {
    :
}
```

shall emit a representation equivalent to:

```cpp
/**
 * @brief Example parameterized function.
 * @param _1 First value.
 * @param _2 Second value.
 */
int example(String _1, String _2);
```

The filter SHALL continue to retain enough source metadata to diagnose a
mismatch such as:

```bash
## @fn documented_name()
actual_name() {
    :
}
```

Omitting `@fn` from the generated function block MUST NOT disable that
diagnostic or alter strict-mode failure behavior.

This decision applies to successfully recognized function documentation.  It
does not change how unmatched documentation blocks or variable documentation
are emitted.

## Considered Alternatives

### Emit a rewritten `@fn` signature

The filter could synthesize an `@fn` directive containing the same resolved
parameter list as the generated declaration.  This was rejected because it
would duplicate structural information and create another representation that
would need to remain synchronized with the declaration.

### Suppress `@fn` only for functions with parameters

The immediate failure is observable for parameterized functions, so the filter
could preserve `@fn name()` for zero-argument functions.  This was rejected
because the source directive is redundant whenever a generated declaration
immediately follows the documentation block.  A single rule is more
predictable and prevents future divergence if declaration synthesis evolves.

### Remove `@fn` during source parsing

The filter could discard the directive as soon as it is read.  This was
rejected because `@fn` remains useful source metadata for checking documented
intent against the actual Bash declaration.

### Require downstream projects to omit `@fn`

Projects using the filter could change their Bash documentation conventions.
This was rejected because the filter already understands `@fn` and can preserve
its validation value without exposing the structural directive to Doxygen.
Requiring downstream workarounds would move a translation concern into every
consumer.

## Consequences

Generated function documentation has one authoritative structural signature:
the synthesized declaration.  This removes the conflict between source
`@fn name()` directives and declarations containing generated parameter lists.

Source authors may continue to use `@fn` for clarity and mismatch detection.
The source documentation format therefore does not need to change in downstream
projects such as `mktext`.

Regression fixtures must verify both sides of the boundary: emitted function
blocks do not contain source `@fn` directives, while strict-mode tests continue
to prove that mismatched `@fn` metadata is parsed and diagnosed.

The implementation introduces no new public option and does not change
parameter-name resolution established by ADR-001.

## Open Questions and Follow-Ups

A future Doxygen integration test could validate the complete consumer-facing
contract by confirming that a parameterized function is indexed in generated
Doxygen output.  The filter-level regression remains necessary because it
captures the exact intermediate representation controlled by this project.

The analogous role of source `@var` directives should be evaluated separately
if evidence shows redundant variable structural commands create a downstream
problem.  This ADR intentionally does not change variable emission.

## Related Decisions

- Related to: ADR-000, which requires evidence-oriented reasoning and explicit
  scope boundaries.
- Builds on: ADR-001, which requires emitted `@param` names and synthesized
  declaration identifiers to remain aligned.
- Related to: GitHub issue #14, "Do not emit source @fn signature when
  synthesized declaration has parameters."
