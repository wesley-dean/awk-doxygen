# ADR-004: Use small behavior-focused regression fixtures

Date: 2026-08-19

## Status

Proposed

## Intent and Documentation Posture

This ADR records how `bash-doxygen` should structure regression tests for its
source-to-pseudo-C++ translation behavior.  The decision favors many small cases
that each establish a narrow observable contract over a few broad examples that
exercise many parser branches at once.

## Context

The initial regression suite was deliberately small.  It contained one golden
output fixture covering positional-parameter rewriting and a sanitization
collision, plus one strict-mode fixture covering an `@fn` name mismatch.  Those
cases protected regressions that had already occurred, but they did not exercise
most behavior advertised by the project.

The filter recognizes four common Bash function declaration forms, several
variable storage and declaration forms, multiple variable type flags, parameter
identifier normalization, file-level documentation, ignored undocumented input,
normal warning behavior, strict-mode failure, and compact/default output modes.
Most of those branches had no direct regression case.

For a small translator, broad fixtures are inexpensive to write initially but
become difficult to diagnose as the implementation evolves.  When one fixture
contains many unrelated declarations, a failed diff identifies the affected
file without identifying the behavior whose contract changed.  Large expected
files also make accidental changes harder to distinguish from intentional ones.

## Decision Drivers

- Make a failing test identify the affected behavior quickly.
- Cover the declaration forms and diagnostics documented as supported behavior.
- Preserve the existing fixture-and-golden-output testing model.
- Keep individual inputs and expected outputs short enough to inspect directly.
- Avoid adding a test framework or dependency for a portable awk project.
- Exercise maintained source and generated release bytes with the same suite.
- Test diagnostics as observable contracts without depending on temporary file
  paths or line-number prefixes.
- Avoid coupling unrelated parser behaviors into one large integration fixture.

## Decision

Regression coverage SHALL primarily use small, behavior-focused fixtures.

Successful translation cases SHALL live in `tests/fixtures/` and use matching
pseudo-C++ golden files in `tests/expected/`.  File basenames SHALL describe the
behavior under test, such as a function declaration form, parameter
normalization rule, variable characteristic, or documentation behavior.

A fixture MAY contain a few closely related declarations when their purpose is
to test one cohesive classification rule, such as storage classes, indexed-array
recognition, or case-transform flags.  Broad fixtures that mix unrelated parser
concerns SHOULD be avoided.

Diagnostic cases SHALL live in `tests/diagnostics/`.  Each diagnostic input SHALL
have a matching `.err` file containing normalized warning text.  The harness
SHALL verify two contracts for each diagnostic:

1. normal mode emits the expected warning and exits successfully; and
2. `--strict` emits the same warning and exits non-zero.

Path and line-number prefixes SHALL be normalized before comparison because they
are execution context rather than the semantic diagnostic contract.

The suite SHALL include direct coverage for both `--compact` output and the
default blank-placeholder behavior.  It SHALL continue to run against both the
maintained `doxygen-bash.awk` source and the generated `dist/doxygen-bash.awk`
artifact.

The generated artifact test SHALL also verify its build boundary: executable
awk shebang, generated-file notice, source-file identification, and the
`DOXYGEN_BASH_VERSION`, `DOXYGEN_BASH_BUILD_DATE`, and
`DOXYGEN_BASH_BUILD_COMMIT` provenance header fields.

## Considered Alternatives

### Keep the original minimal suite

The existing tests were useful regression guards for two previously observed
problems.  This option was rejected because most documented parser branches and
all variable classification behavior remained untested.

### Add one comprehensive fixture

A single fixture could exercise every supported declaration and option.  This
would minimize file count, but failures would produce large diffs and unrelated
behaviors would share one test boundary.  The maintenance cost would grow as the
translator expands.

### Introduce Bats or another test framework

A framework could provide richer assertions and test reporting.  This was not
selected because the current POSIX shell harness already has the primitives
needed for deterministic fixture comparison, diagnostics, and exit-status
checks.  Adding a dependency would increase setup cost without materially
improving these tests.

### Test internal awk functions directly

The suite could invoke or extract helpers such as `sanitize_identifier` or
`classify_variable`.  This was rejected because those functions are
implementation details.  Tests should protect observable filter behavior so the
internals remain free to change without unnecessary fixture churn.

## Consequences

The repository gains more fixture files, but each file is intentionally small
and named after the behavior it protects.  Failures should therefore be easier
to localize and review.

Coverage becomes substantially broader without modifying production behavior or
adding test dependencies.  The suite directly exercises supported function
forms, parameter normalization, variable classification, documentation
translation, diagnostic behavior, output modes, and generated artifact
metadata.

Golden-output tests can preserve an unintended behavior if expected files are
accepted without review.  New fixtures therefore require semantic review of the
expected pseudo-C++ rather than treating output generated by the current filter
as automatically correct.

The suite remains regression-oriented rather than a formal grammar proof.  New
parser branches, bug fixes, and public behavior should add or refine focused
fixtures as they are introduced.

## Open Questions and Follow-Ups

A future Doxygen integration test could validate a small number of end-to-end
cases against Doxygen itself.  Such tests would complement, rather than replace,
the filter-level fixtures because the intermediate representation remains the
artifact controlled directly by this project.

Coverage measurement for awk is not introduced by this decision.  If the
project later adopts coverage tooling, it should be evaluated separately rather
than using a percentage target as a substitute for behavior-oriented cases.

## Related Decisions

- Related to: ADR-000, which requires evidence-oriented reasoning and explicit
  scope boundaries.
- Builds on: ADR-001 and ADR-002, whose parameter and synthesized-signature
  invariants are exercised by focused fixtures.
- Builds on: ADR-003, which requires the same regression suite to exercise both
  maintained source and generated release bytes.
