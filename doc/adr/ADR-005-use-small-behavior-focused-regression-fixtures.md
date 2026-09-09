# ADR-005: Use small behavior-focused regression fixtures

Date: 2026-09-09

## Status

Accepted

## Context

`bash-doxygen` uses small source fixtures paired with golden pseudo-C++ output,
plus separate diagnostic cases for warning and strict-mode behavior.  That model
is well suited to a documentation compiler because the public contract is the
observable source-to-generated-representation transformation rather than the
implementation of individual helper functions.

The inherited `awk-doxygen` repository currently contains Bash-oriented fixtures
from its seed repository.  Those fixtures are useful evidence about the testing
architecture, but they do not establish AWK behavior.  The AWK implementation
will introduce new parser branches around function declarations, formal
parameters, conventional locals, documentation rewriting, and eventually global
state and rule constructs.

A broad integration fixture could cover many of those paths quickly, but it
would make failures difficult to localize and would encourage accepting large
golden diffs without understanding which behavior changed.

## Decision Drivers

- Make a failing test identify the affected contract quickly.
- Protect observable filter behavior rather than implementation details.
- Keep test inputs and expected output small enough for direct review.
- Exercise documentation validation and generated representation separately when
  useful.
- Preserve a lightweight shell-based harness without requiring a larger test
  framework.
- Test portability claims against multiple AWK implementations where practical.
- Exercise maintained source and generated consumer bytes with the same semantic
  suite.

## Decision

AWK regression coverage SHALL primarily use small, behavior-focused fixtures.

Successful translation cases SHALL use small `.awk` source files with matching
golden Doxygen-facing output.  Fixture names SHALL describe the behavior under
test, such as:

```text
function-no-params
function-public-params
function-conventional-locals
function-local-array
param-order
file-documentation
compact-output
```

A fixture MAY contain several closely related constructs when they jointly test
one classification rule.  Broad fixtures that mix unrelated parser behavior
SHOULD be avoided.

Diagnostic cases SHALL be separate from successful translation fixtures when
practical.  The harness SHALL verify both ordinary warning behavior and strict
failure behavior for diagnostics that form part of the public contract.

Expected diagnostics SHOULD normalize execution-context details such as
absolute paths when those details are not semantically important.  Stable
message content is part of the observable contract; incidental environment text
is not.

Tests SHALL protect public behavior rather than internal AWK helper functions.
The suite SHALL NOT require a particular internal function decomposition merely
because the implementation happens to use one today.

The same semantic fixture suite SHALL exercise the maintained filter source and
the generated `dist/doxygen-awk.awk` artifact once ADR-004's build boundary is
implemented.

Portable-AWK claims SHOULD be supported by running the filter-level suite under
more than one readily available AWK implementation.  At minimum, development
should avoid relying on a single implementation as proof of portability.  The
exact CI matrix MAY be established during implementation based on what the
project can install reproducibly.

The initial AWK fixture set SHALL directly cover the invariants established by
ADRs 001 through 003, including:

- documented file blocks;
- recognized named functions;
- zero-parameter functions;
- caller-visible `@param` formals;
- conventional `@local` formals;
- suppression of locals from generated public signatures;
- source `@fn` name validation;
- parameter/local name validation;
- preservation or intentional translation of descriptive Doxygen commands;
- one authoritative synthesized function signature;
- ordinary warning behavior; and
- strict-mode failure for documentation drift.

Support added later for `@var`, `@rule`, `BEGIN`, `END`, or ordinary
pattern/action rules SHALL add focused fixtures for those public contracts.

Inherited Bash-oriented fixtures SHALL be treated as transitional scaffolding.
They MAY inform AWK test organization, but they SHALL NOT remain in the active
AWK regression suite in a way that makes a passing build appear to verify AWK
semantics.

## Considered Alternatives

### Keep the inherited Bash fixture suite and adapt it gradually in place

This would minimize initial file churn but would create a period in which test
names and successful output could describe the wrong language.  The project
prefers an explicit AWK baseline over ambiguous transitional evidence.

### Use one comprehensive AWK fixture

This would reduce the number of test files, but failures would produce large
diffs spanning unrelated behaviors.  Reviewers would have to determine which
contract changed before they could assess whether the expected output was still
correct.

### Introduce a dedicated test framework

A framework could provide richer assertions, but the filter's primary contracts
are deterministic file transformations, diagnostics, and exit statuses.  A
portable shell harness is sufficient for those contracts and avoids another
runtime dependency.

### Unit-test internal parser helpers

This was rejected because internal helpers are implementation details.  The
project should be free to rewrite parser internals without changing tests when
the public transformation remains identical.

### Test only GNU awk

GNU awk is widely available and useful during development, but a GNU-only suite
would not support the project's default portable-AWK claim.  Multiple
implementations provide stronger evidence and can expose accidental extension
usage.

## Consequences

The repository will contain more small fixture files, but each failure should be
easier to understand and review.  Golden outputs remain manageable enough that
reviewers can assess semantics rather than accepting generated changes blindly.

Portability testing introduces some CI and local-development complexity, but it
provides evidence for a compatibility claim that would otherwise be rhetorical.

The project must explicitly retire or segregate inherited Bash fixtures during
implementation.  A green test run is useful only when the tests describe the
behavior the repository claims to provide.

## Related Decisions

- Builds on ADR-001's intentionally narrow documentation/compiler scope.
- Exercises ADR-002's `@param` / `@local` distinction.
- Exercises ADR-003's authoritative synthesized signature invariant.
- Builds on ADR-004's requirement that maintained source and generated consumer
  artifacts share one semantic regression suite.
