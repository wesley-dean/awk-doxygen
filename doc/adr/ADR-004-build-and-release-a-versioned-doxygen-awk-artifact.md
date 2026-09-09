# ADR-004: Build and release a versioned doxygen-awk artifact

Date: 2026-09-09

## Status

Accepted

## Context

The repository was seeded from `bash-doxygen`, whose release model separates the
maintained filter source from a generated consumer artifact carrying provenance
metadata and a SHA-256 checksum.  That boundary is useful for `awk-doxygen` as
well: consumers should be able to download one explicit filter artifact, inspect
its provenance, and verify the released bytes without reconstructing the build
from repository state.

The inherited repository currently still contains Bash-oriented source,
fixtures, Makefile variables, and release names.  During repository
establishment those files are transitional scaffolding rather than a valid AWK
consumer contract.  Release automation must therefore remain disabled until the
AWK implementation and its tests replace the inherited behavior.

As with `bash-doxygen`, build provenance in an AWK source file requires care.
Bare top-level assignments can participate in AWK record processing, so metadata
must not be injected in a form that changes runtime behavior merely to make a
released file self-describing.

## Decision Drivers

- Preserve a clear boundary between maintained source and released consumer
  bytes.
- Publish one obvious AWK filter artifact.
- Record version, build date, and source commit provenance without changing AWK
  runtime behavior.
- Publish a standard SHA-256 checksum for the exact release artifact.
- Use the same regression suite against maintained source and generated output.
- Prevent inherited Bash scaffolding from being published as if it were an AWK
  release.
- Keep local development and release automation on one canonical build path.

## Decision

The maintained AWK filter and generated consumer artifact SHALL be named:

```text
doxygen-awk.awk
```

The generated artifact SHALL live under `dist/` and SHALL preserve an executable
AWK shebang if the maintained source uses one.  Build provenance SHALL be
inserted as comments immediately after the shebang or at the beginning of the
file when no shebang is present.

The provenance header SHALL identify the generated-file boundary, maintained
source, and these fields:

```text
# DOXYGEN_AWK_VERSION=<version>
# DOXYGEN_AWK_BUILD_DATE=<date>
# DOXYGEN_AWK_BUILD_COMMIT=<commit>
```

These values SHALL remain comments.  They are provenance metadata rather than
runtime configuration and MUST NOT introduce executable AWK patterns,
assignments, or namespace solely for build identification.

`make build` SHALL become the canonical local and CI interface for producing
`dist/doxygen-awk.awk`.  `make checksums` SHALL generate:

```text
dist/doxygen-awk.awk.sha256
```

in standard `sha256sum` format.

The regression harness SHALL accept or otherwise exercise both the maintained
source and generated consumer artifact so that build transformation is proven
not to change filter behavior.

Automatic release publication SHALL remain disabled during repository
establishment and SHALL NOT be re-enabled until all of the following are true:

1. the maintained filter implements the governed AWK behavior;
2. inherited Bash-oriented regression fixtures have been replaced or explicitly
   segregated from the AWK suite;
3. maintained source and generated `doxygen-awk.awk` pass the same AWK-oriented
   regression contracts;
4. checksum generation and verification use the AWK artifact names; and
5. release automation publishes only the AWK artifact and its checksum.

The generated `dist/` directory SHALL remain untracked repository state unless a
later decision explicitly changes that model.

## Considered Alternatives

### Release the maintained source directly

This would reduce build machinery but would remove the explicit generated
artifact boundary and provenance pattern already proven useful by the parent
project.  It was rejected in favor of a self-describing consumer artifact.

### Inject provenance as AWK assignments

This was rejected because top-level AWK expressions can affect record
processing.  Provenance must not change semantics.

### Add a dedicated BEGIN block for build metadata

A generated `BEGIN` block could initialize metadata variables safely, but that
would still create runtime state the filter does not consume.  Comments express
provenance without expanding the executable namespace.

### Keep doxygen-bash.awk as the artifact name temporarily

This was rejected as a final contract because consumers should not need to know
the repository's origin to identify the AWK artifact.  The inherited name may
remain in transitional scaffolding only until implementation converts the build
and tests coherently.

### Enable releases during repository establishment

This was rejected because the inherited filter still implements Bash behavior.
Publishing it from `awk-doxygen` would create a misleading consumer artifact and
violate ADR-000's capability-honesty requirements.

## Consequences

Consumers will eventually receive an independently versioned AWK filter whose
filename, provenance metadata, and checksum all agree with the repository's
identity.

The project accepts a temporary state in which the intended artifact contract is
documented but the inherited Makefile and filter have not yet been converted.
That transition is explicit and must not be represented as completed support.

The implementation phase must update build variables, test harness environment
names, checksums, and release workflow references together so there is no mixed
Bash/AWK release boundary.

## Related Decisions

- Related to ADR-000, which prohibits misrepresenting inherited scaffolding as a
  working AWK capability.
- Builds on ADR-001, which defines the filter's governed AWK scope.
- ADR-005 requires the same behavior-focused suite to exercise maintained and
  generated filter bytes.
