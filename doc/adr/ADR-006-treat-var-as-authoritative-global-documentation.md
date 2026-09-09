# ADR-006: Treat @var as authoritative global documentation

Date: 2026-09-09

## Status

Accepted

## Context

AWK variables and arrays are created through use rather than through dedicated
source-level declarations.  A global value may first appear in `BEGIN`, inside
an ordinary rule, inside a function, through command-line assignment, or through
a built-in variable supplied by the AWK implementation.  There is therefore no
single general-purpose declaration line that `awk-doxygen` can require or infer
without imposing semantics the language does not provide.

The AWK documentation standard already defines `@var` as the maintained-source
vocabulary for significant global variables and arrays.  It deliberately does
not require a fictitious AWK declaration line after the documentation block.
The standard also requires authors to describe important shape, lifecycle,
ownership, and mutation semantics in prose rather than pretending that AWK has a
stronger static type system than it actually provides.

ADR-001 reserves `@var` for significant documented globals and requires its
semantics to be governed explicitly before the filter begins emitting variable
structure.  The implementation must therefore decide whether source `@var`
metadata is authoritative, whether a following assignment is required, how a
documented global is represented to Doxygen, and how much scalar-versus-array
or lifecycle information the filter may infer.

Doxygen provides a `@var` structural command whose argument is a variable
declaration.  This permits `awk-doxygen` to synthesize a Doxygen-facing
pseudo-declaration directly on the source `@var` line without inventing an AWK
declaration or adding a generated line after the documentation block.

## Decision Drivers

- Preserve the documentation-led model established by ADR-001.
- Represent significant AWK globals without inventing source declarations.
- Avoid treating arbitrary assignments as declarations.
- Avoid inferring scalar-versus-array shape from incomplete source evidence.
- Preserve source-line correspondence wherever practical.
- Keep generated vocabulary clearly synthetic rather than claiming static AWK
  types.
- Allow significant built-in or command-line-provided globals to be documented
  even when no source assignment exists.
- Keep conventional function-local formals under `@local` rather than allowing
  `@var` to blur the local/global contract.

## Decision

A maintained `@var` block SHALL be an authoritative documentation declaration
for one significant AWK global variable or array.

The filter SHALL NOT require a following assignment, first use, initializer, or
other AWK source construct before accepting the block.  The contiguous
Doxygen block itself establishes the documentation identity.

For example:

```awk
## @var record_count
## @brief Number of accepted input records.
## @details
## Initialized in BEGIN and incremented only after validation succeeds.
```

and:

```awk
## @var cache
## @brief Maps normalized identifiers to cached values.
## @details
## Keys are lowercase identifiers.  Entries persist for the lifetime of the
## AWK process.
```

are complete documented-global constructs even if the next source line is not an
assignment to `record_count` or `cache`.

The name supplied to `@var` SHALL be a valid portable AWK identifier:

```text
[A-Za-z_][A-Za-z0-9_]*
```

The filter SHALL diagnose an empty or invalid documented name.

`@var` SHALL represent global state.  A conventional omitted formal used as
function-local storage SHALL continue to be documented with `@local` under
ADR-002 rather than `@var`.

## Doxygen Representation

The generated representation SHALL rewrite the source structural directive into
a Doxygen variable declaration using the existing synthetic `AwkValue` type:

```cpp
/// @var AwkValue record_count
/// @brief Number of accepted input records.
/// @details
/// Initialized in BEGIN and incremented only after validation succeeds.
```

The source `@var` line and generated Doxygen `@var` line SHALL occupy the same
line position in default mode.  The remaining documentation lines SHALL retain
their existing one-for-one translation behavior.

`AwkValue` is deliberately generic.  It SHALL NOT be interpreted as a claim
that the documented global is a scalar, string, number, array, reference, or
other static type.  The maintained prose remains authoritative for shape and
usage semantics.

The filter SHALL NOT synthesize separate `AwkArray`, numeric, string, Boolean,
readonly, mutable, or other pseudo-types unless a later ADR establishes explicit
source metadata and representation contracts for those distinctions.

## Association and Block Boundaries

A `@var` block is standalone documentation.  It SHALL be emitted when its
contiguous documentation block ends because of a blank line, a following
non-documentation source line, or end of file.

The source line following a completed `@var` block SHALL be processed according
to the ordinary filter rules.  It is not implicitly associated with the
variable merely because it is adjacent.

This means code such as:

```awk
## @var record_count
## @brief Number of accepted records.
record_count = 0
```

is valid, but the assignment is ordinary undocumented AWK source from the
filter's perspective.  The filter SHALL NOT compare the assignment name with the
`@var` name or infer initialization semantics from it.

## Inference Boundary

The filter SHALL NOT infer any of the following from arbitrary AWK source:

- whether a documented global is scalar or array;
- whether it is numeric, string-like, or Boolean-like;
- whether it is read-only or mutable;
- where it is initialized;
- whether initialization comes from `BEGIN`, command-line assignment, `ARGV`,
  `ENVIRON`, or another mechanism;
- which functions or rules own or mutate it; or
- whether a first assignment is semantically its declaration.

Those properties belong in maintained documentation unless a later architectural
decision introduces explicit machine-readable metadata for them.

## Validation

The initial `@var` implementation SHALL validate only properties supported by
explicit maintained-source evidence:

- a `@var` structural directive exists;
- the documented identity is non-empty;
- the identity is a valid portable AWK identifier; and
- the block can be translated without being confused with function-local
  `@local` metadata.

The filter MAY later diagnose duplicate or conflicting structural directives in
a single documentation block if that behavior is introduced as a general
structural-documentation contract.  This ADR does not require expanding the
scope of function-block validation merely to implement `@var`.

## Considered Alternatives

### Require @var immediately before an assignment

This would provide an apparent declaration anchor, but AWK assignments are
ordinary executable operations rather than declarations.  Significant globals
may be initialized in multiple places, populated incrementally, supplied by the
execution environment, or never assigned by project source at all.  Requiring
adjacency would encode a false language model.

### Infer variables from assignments

The filter could treat assignments such as `name = value` or `array[key] = value`
as declarations.  This was rejected because such assignments occur throughout
normal processing and do not establish scope, ownership, lifecycle, or intended
documentation significance.

### Infer arrays from indexed use

Indexed syntax can demonstrate that a name is being used as an array at one
point in the source, but scanning arbitrary use would move the filter toward
partial semantic analysis.  The documentation standard already requires array
shape and lifecycle to be explained when significant, so inference is
unnecessary for the initial representation.

### Emit a synthetic declaration after the documentation block

The filter could emit `AwkValue name;` after the block.  This would force an
additional generated line for a source construct that has no declaration line,
weakening source-line correspondence.  Doxygen's structural `@var` command
allows the declaration to live on the existing source `@var` line instead.

### Preserve source @var unchanged

A bare source directive such as `@var record_count` does not provide the
pseudo-C++ declaration shape used by Doxygen's structural command.  Rewriting it
to `@var AwkValue record_count` gives Doxygen an explicit declaration while
keeping maintained AWK documentation free from pseudo-language details.

### Introduce scalar and array pseudo-types now

This would make generated output appear richer, but the maintained source does
not contain a machine-readable scalar-versus-array declaration.  Guessing from
usage or prose would violate ADR-000 and ADR-001.  One generic pseudo-type is a
more honest representation.

## Consequences

Significant AWK globals can be documented and indexed without requiring the
filter to parse assignments or discover declarations that the language does not
have.

The maintained source remains natural AWK documentation: authors write
`@var name`, while pseudo-C++ vocabulary exists only in generated output.

Source-line correspondence remains exact for well-formed variable blocks because
the structural `@var` line itself becomes the Doxygen-facing declaration.

Generated documentation intentionally does not encode scalar-versus-array shape.
Readers depend on `@brief` and `@details` for that semantic information until a
future decision establishes explicit structural metadata.

Regression coverage must include standalone scalar-like and array-like globals,
variables followed by unrelated source, end-of-file variable blocks, invalid
names, and source-line correspondence.

## Related Decisions

- Builds on ADR-000's requirement for capability honesty and resistance to
  speculative claims.
- Builds on ADR-001's documentation-led scope and its reservation of `@var` for
  significant globals.
- Preserves ADR-002's distinction between global state and conventional
  function-local formals.
- Uses the synthetic `AwkValue` vocabulary established by ADR-003 without
  changing function-signature semantics.
- Regression coverage follows ADR-005's small behavior-focused fixture model.
