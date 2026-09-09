# ADR-007: Represent AWK rules as file-local synthetic functions

Date: 2026-09-09

## Status

Accepted

## Context

A substantial portion of AWK behavior exists outside named functions.  AWK
programs are composed primarily of pattern/action rules, including the special
`BEGIN` and `END` patterns, ordinary pattern/action pairs, pattern-only rules,
and action-only rules.  These constructs are executable program structure, but
they are not functions and do not have source-level names.

The AWK documentation standard therefore defines `@rule` as maintained-source
metadata that assigns a stable documentation identity to a significant AWK rule.
For example:

```awk
## @rule initialize
## @brief Initializes parsing state before input records are processed.
BEGIN {
    FS = ":"
}
```

and:

```awk
## @rule comment_lines
## @brief Ignores source comment records.
/^[[:space:]]*#/ {
    next
}
```

The identity after `@rule` is documentation metadata.  It does not create an AWK
identifier and does not change runtime behavior.

ADR-001 reserves `@rule` for this purpose and explicitly rejects pretending that
AWK rules are source-level functions.  It also permits the filter to synthesize a
Doxygen-facing entity later, provided the maintained source model remains a
rule.  ADR-005 requires focused regression fixtures when rule support is added.

Doxygen has structural entities for functions, variables, types, files, and
related C/C++ concepts, but it has no native AWK rule or process entity.  The
filter therefore needs a generated representation that Doxygen can index without
changing the meaning of the maintained AWK documentation.

Doxygen also distinguishes static file members from global functions.  Static
file members are appropriate for generated AWK-rule entities because the same
natural documentation identity, such as `initialize`, may legitimately occur in
more than one AWK file.  Doxygen requires `EXTRACT_STATIC = YES` for static file
members to appear in generated documentation.

The first implementation also needs a conservative source-recognition boundary.
Portable AWK permits both pattern-only and action-only rules, and ordinary
patterns may be arbitrary expressions or ranges.  Attempting to parse every
legal pattern would move `awk-doxygen` toward the general AWK parser rejected by
ADR-001.

## Decision Drivers

- Preserve `@rule` as an AWK-source concept rather than a source-level function.
- Give Doxygen one indexable entity for each supported documented rule.
- Keep generated rule entities file-local so natural identities can recur in
  different AWK source files.
- Preserve source-line correspondence wherever practical.
- Avoid parsing or normalizing arbitrary AWK patterns merely to create
  documentation.
- Distinguish implemented action-bearing rule support from future pattern-only
  support.
- Keep generated vocabulary visibly synthetic and isolated from maintained AWK
  semantics.
- Support `BEGIN`, `END`, ordinary pattern/action rules, and action-only rules
  without requiring source authors to encode pseudo-C++ details.
- Make Doxygen configuration requirements explicit.

## Decision

A maintained `@rule` block SHALL assign one stable documentation identity to the
AWK rule immediately following the contiguous documentation block.

The identity SHALL use this tooling-safe lexical form:

```text
[A-Za-z_][A-Za-z0-9_]*
```

This lexical restriction exists so the identity can map losslessly into a
synthetic C++ identifier.  It SHALL NOT be described as making the `@rule`
identity an AWK variable, function, or other source-level identifier.

The source `@rule` directive SHALL be parsed for association and validation but
SHALL NOT be emitted directly to Doxygen.

For each successfully recognized documented rule, the filter SHALL synthesize a
file-local no-argument function declaration on the AWK rule-header source line.
The generated declaration SHALL use `static void` and a reserved synthetic name
whose prefix identifies it as `awk-doxygen` rule metadata.

The initial generated naming forms SHALL be:

```text
static void awk_doxygen_begin_<identity>();
static void awk_doxygen_end_<identity>();
static void awk_doxygen_rule_<identity>();
```

`BEGIN` rules SHALL use the `awk_doxygen_begin_` prefix.  `END` rules SHALL use
the `awk_doxygen_end_` prefix.  Ordinary pattern/action and action-only rules
SHALL use the `awk_doxygen_rule_` prefix.

For example:

```awk
## @rule initialize
## @brief Initializes parsing configuration.
BEGIN {
    FS = ":"
}
```

shall produce a Doxygen-facing representation equivalent in structure to:

```cpp

/// @brief Initializes parsing configuration.
static void awk_doxygen_begin_initialize();


```

The blank line corresponding to source `@rule initialize` is intentional.  The
source structural directive is metadata for the filter; the synthetic
declaration on the real AWK rule-header line is the sole Doxygen structural
entity for the rule.

Similarly:

```awk
## @rule comment_lines
## @brief Ignores source comment records.
/^[[:space:]]*#/ {
    next
}
```

shall generate a declaration equivalent to:

```cpp
static void awk_doxygen_rule_comment_lines();
```

The generated function is an indexing representation only.  It SHALL NOT be
described as callable AWK behavior, a user-defined AWK function, or evidence that
AWK rules have return values or formal parameters.

## File-Local Representation

Generated rule declarations SHALL be `static` so their pseudo-C++ linkage is
file-local.  This allows separate AWK files to use the same natural source
identity without intentionally describing one shared global rule entity.

Consumers that want documented rules to appear in Doxygen output SHALL enable:

```ini
EXTRACT_STATIC = YES
```

The project README and reusable documentation standard SHALL make this
integration requirement visible once `@rule` support is implemented.

The generated prefixes `awk_doxygen_begin_`, `awk_doxygen_end_`, and
`awk_doxygen_rule_` are reserved generated vocabulary.  They exist only in the
Doxygen-facing representation and MUST NOT be presented as source naming
requirements for ordinary AWK code.

## Initial Recognition Boundary

The first `@rule` implementation SHALL support action-bearing rules whose
opening action brace appears on the same physical line as the rule header.

This includes:

```awk
BEGIN {
```

```awk
END {
```

```awk
/^[[:space:]]*#/ {
```

```awk
NR == 1 {
```

and the action-only form:

```awk
{
```

The filter SHALL NOT attempt to parse or reproduce the pattern expression.  For
an ordinary action-bearing rule, it is sufficient to establish conservatively
that the documented top-level source line ends with the opening action brace and
is not a function declaration or malformed `BEGIN`/`END` special pattern.

The filter SHALL classify recognized rules only to the extent needed for the
generated name:

- `BEGIN`;
- `END`; or
- ordinary/action-only rule.

The filter SHALL NOT infer the meaning of a regular expression, expression
pattern, range, field comparison, or other pattern text.

## Pattern-Only Rules

AWK permits a rule whose action is omitted.  Its default action prints the
current record.  The maintained documentation standard continues to permit and
require meaningful documentation of significant pattern-only rules.

The first filter implementation SHALL NOT synthesize Doxygen entities for
pattern-only rules.

A pattern-only rule has no opening action brace to provide the conservative
association anchor used by this decision, and arbitrary AWK expression patterns
can resemble other top-level expression text.  Supporting them honestly requires
a separate recognition contract rather than treating every non-function source
line after `@rule` as a valid pattern.

When a `@rule` block is followed by source that is not recognized as an
action-bearing rule, the filter SHALL diagnose that no supported action-bearing
rule was found.  Documentation and README text SHALL state that pattern-only
rules remain outside the implemented parser boundary.

A later ADR MAY add pattern-only support without changing the source `@rule`
vocabulary or the file-local synthetic representation established here.

## Association and Adjacency

Unlike `@var`, a `@rule` block is not standalone documentation.  It SHALL be
associated with the immediately following supported AWK rule header.

A blank line between the documentation block and rule header SHALL break the
association, consistent with the function adjacency model.

An ordinary source comment between the documentation block and rule header SHALL
also break the association.  Maintained Doxygen documentation is expected to be
contiguous with the construct it documents.

The filter SHALL NOT scan forward through arbitrary source searching for a rule
that appears to match the documentation identity.

The `@rule` identity is author-supplied metadata and therefore cannot be compared
to a source-level rule name because AWK rules have no such names.  Validation
SHALL instead verify that:

- the identity is present;
- the identity has the governed lexical form; and
- the immediately following source line is a supported action-bearing rule
  header.

## Source-Line Correspondence

In default mode, the generated static declaration SHALL occupy the same output
line as the associated AWK rule header.

The source `@rule` line SHALL be replaced by a blank placeholder because its
structural role has been consumed by the filter.  Other descriptive Doxygen
lines SHALL retain their ordinary one-for-one translation.

Rule body lines remain ordinary undocumented AWK source and SHALL continue to
produce blank placeholders in default mode, just as function bodies do.

Compact mode MAY omit all blank placeholders while preserving the same semantic
Doxygen structure.

## Doxygen Configuration

The documented rule entity is intentionally a static file member.  The standard
Doxygen integration SHALL therefore include:

```ini
EXTRACT_STATIC = YES
```

This requirement is part of the `@rule` consumer contract rather than an
incidental project preference.

The existing mapping remains otherwise unchanged:

```ini
FILTER_PATTERNS = *.awk=./doxygen-awk.awk
EXTENSION_MAPPING = awk=C++
EXTRACT_ALL = NO
```

## Validation and Diagnostics

The initial implementation SHALL diagnose at least:

- an empty `@rule` identity;
- an identity outside the governed lexical form;
- a `@rule` block separated from its rule by a blank line;
- a `@rule` block followed by a function declaration;
- a `@rule` block followed by malformed or unsupported `BEGIN`/`END` source; and
- a `@rule` block not followed by a recognized action-bearing rule header,
  including pattern-only rules in this implementation stage.

Normal mode SHALL report the diagnostic while preserving usable generated
output where practical.  Strict mode SHALL report the same diagnostic and cause
a non-zero filter status under the existing strict-mode contract.

This ADR does not require project-wide duplicate-rule-identity detection.  The
file-local generated representation avoids cross-file linkage collisions, and a
later structural-validation decision may add duplicate checks if they prove
useful.

## Considered Alternatives

### Treat source @rule as @fn

The filter could rewrite `@rule initialize` directly to `@fn` and make the
source documentation look function-shaped.  This was rejected because it would
blur the semantic distinction established by the documentation standard and
ADR-001.  Source authors should document an AWK rule as a rule.

### Emit a non-static synthetic function

A global synthetic function would be simpler, but identical natural rule
identities in separate files could describe one apparent global function to
Doxygen.  File-local static declarations better match the actual ownership of an
AWK rule.

### Use @page or @section

A page or section could represent rule prose without pretending to be a
function, but it would make rules top-level narrative documentation rather than
file members and would weaken the direct source-entity relationship.  It would
also make a small rule behave like a standalone manual page rather than a member
of its AWK source file.

### Use @var

A synthetic variable would avoid function syntax but would represent executable
behavior as data.  A no-argument `void` function is a closer Doxygen indexing
analogy while remaining explicitly synthetic.

### Parse all AWK patterns now

A richer parser could identify pattern-only rules and validate arbitrary
patterns.  This was rejected for the initial implementation because it expands
scope toward the general parser ADR-001 explicitly avoids.

### Treat any line after @rule as a rule

This would maximize apparent coverage but would make documentation metadata an
excuse to accept source structure the filter has not recognized.  The project
prefers a false negative and explicit diagnostic to a false semantic claim.

### Require globally unique @rule identities

Project-wide uniqueness would avoid generated-name collisions for global
functions, but it would burden source authors with artificial naming conventions
such as file prefixes.  File-local generated functions allow natural identities
to remain local to the file that owns the rule.

## Consequences

Significant `BEGIN`, `END`, ordinary pattern/action, and action-only rules can be
indexed by Doxygen without changing the maintained source model.

Doxygen output will display generated function-shaped entities for rules.  The
README and documentation standard must explain that these are indexing
artifacts, not callable AWK functions.

Consumers must enable `EXTRACT_STATIC = YES` to expose the generated entities.
This is an additional Doxyfile requirement introduced by rule support.

Pattern-only rules remain documentable in maintained AWK source but are not yet
emitted by the filter.  That limitation is deliberate and visible rather than
hidden behind speculative pattern parsing.

The filter gains modest rule-header recognition but still does not need to parse
rule bodies or understand pattern semantics.

Regression coverage must include `BEGIN`, `END`, ordinary action-bearing rules,
action-only rules, invalid identities, unsupported pattern-only rules, adjacency
failures, source-line correspondence, strict-mode behavior, and both maintained
and generated filter artifacts.

## Related Decisions

- Builds on ADR-000's requirement for capability honesty and explicit limits.
- Builds on ADR-001's documentation-led scope and its distinct `@rule` source
  vocabulary.
- Does not change ADR-002 or ADR-003 function contracts; generated rule
  functions are indexing entities only.
- Does not change ADR-006's standalone `@var` association model; `@rule` remains
  adjacency-based because it documents executable source structure.
- Regression coverage follows ADR-005's small behavior-focused fixture model.
