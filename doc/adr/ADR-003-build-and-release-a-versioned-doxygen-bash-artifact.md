# ADR-003: Build and release a versioned doxygen-bash artifact

Date: 2026-08-18

## Status

Proposed

## Intent and Documentation Posture

This ADR defines the boundary between the maintained `doxygen-bash.awk` source
file and the file distributed to consumers through GitHub Releases. It records
why the release file is generated, what provenance it carries, how integrity is
represented, and which behaviors the build process must preserve.

## Context

`bash-doxygen` is maintained as a single portable awk source file named
`doxygen-bash.awk`. Before this decision, the semantic-versioning workflow
created GitHub Releases but did not attach a consumer artifact. A release could
therefore identify a source revision without providing one explicit file for
consumers to download and verify.

Related projects such as Bootstrap, mktext, and adrctl establish a stronger
release boundary. Maintained source is transformed into a generated consumer
artifact carrying version, build date, and source-commit provenance. A checksum
is generated for the exact bytes that are released. That pattern makes the
relationship between source, build, and release observable without requiring a
consumer to reconstruct it from repository state.

The awk implementation requires one language-specific constraint. In a Bash
artifact, lines such as `PRODUCT_VERSION=value` are ordinary assignments. At awk
top level, an assignment expression can act as a pattern and therefore risks
changing record-processing behavior through awk's default action. Build metadata
must not alter the filter's runtime semantics merely to imitate Bash syntax.

## Decision Drivers

- Preserve `doxygen-bash.awk` as the maintained source filename.
- Publish `doxygen-bash.awk` as the release artifact filename.
- Make released bytes self-describing with version, date, and commit provenance.
- Preserve the existing executable awk shebang.
- Avoid introducing runtime behavior or awk namespace solely for build metadata.
- Generate a SHA-256 checksum for the exact artifact attached to the release.
- Use a self-describing `.sha256` suffix for newly published checksum assets.
- Exercise the same regression suite against maintained source and generated
  consumer output.
- Keep artifact generation deterministic for a fixed source revision and set of
  build metadata inputs.

## Decision

The project SHALL provide a Makefile as the canonical build interface.

`make build` SHALL generate `dist/doxygen-bash.awk` from the maintained root-level
`doxygen-bash.awk`. The generated file SHALL preserve `#!/usr/bin/awk -f` as its
first line and SHALL insert a provenance header immediately after the shebang.
The header SHALL identify the generated-file boundary, the maintained source,
and these build fields:

```text
# DOXYGEN_BASH_VERSION=<version>
# DOXYGEN_BASH_BUILD_DATE=<date>
# DOXYGEN_BASH_BUILD_COMMIT=<commit>
```

These values SHALL remain comments. They are provenance metadata rather than
runtime configuration, and representing them as comments prevents the build
header from altering awk execution.

`VERSION`, `BUILD_DATE`, and `BUILD_COMMIT` SHALL be Make inputs. Their defaults
SHALL be derived from Git where possible, following the build pattern used by
related projects. Release automation MAY override `VERSION` with the calculated
semantic version while retaining commit-derived defaults for build date and
commit.

`make checksums` SHALL generate `dist/doxygen-bash.awk.sha256` in standard
`sha256sum` format. New releases SHALL publish the `.sha256` checksum filename
only. The longer suffix is intentionally self-describing and avoids ambiguity
with unrelated uses of `.256`.

Consumers that support historical releases SHOULD prefer an `.sha256` checksum
asset and MAY fall back to the legacy `.256` name only when the preferred asset
is absent. They MUST NOT use the legacy name as a fallback for checksum mismatch,
malformed checksum data, authentication failure, TLS failure, timeout, or server
errors.

The regression harness SHALL accept an alternate filter path so the same tests
can validate both the maintained source and `dist/doxygen-bash.awk`. The normal
CI test workflow SHALL run both paths.

The semantic-versioning workflow SHALL build and validate the consumer artifact,
generate and verify its checksum, and attach both files to the GitHub Release:

```text
dist/doxygen-bash.awk
dist/doxygen-bash.awk.sha256
```

Generated `dist/` content remains untracked repository state.

## Considered Alternatives

### Continue publishing `.256`

The shorter suffix works technically, but it does not identify the checksum
algorithm clearly and can be associated with unrelated file types. This was
rejected in favor of the explicit `.sha256` suffix.

### Publish both `.256` and `.sha256`

Publishing both names would ease transition for consumers, but it would create
permanent duplicate release assets and leave two producer conventions in active
use. This was rejected in favor of a single producer convention plus read-side
compatibility in downstream consumers.

### Release the maintained source file directly

The workflow could attach the root-level `doxygen-bash.awk` and checksum it
without a build step. This was rejected because it would omit the provenance
metadata pattern already used by related projects and would leave no explicit
build boundary between maintained source and consumer artifact.

### Add bare awk assignments matching the Bash artifact header

The generated file could contain unguarded lines such as
`DOXYGEN_BASH_VERSION=value`. This was rejected because top-level awk expressions
participate in record processing and can trigger the default action. Provenance
metadata must not change filter behavior.

### Add a dedicated awk BEGIN block containing metadata variables

A generated `BEGIN` block could initialize `DOXYGEN_BASH_*` variables safely.
This would avoid the default-action problem, but it would still add runtime state
that the filter does not consume. Comments express provenance without expanding
the program's namespace or execution model.

### Assemble release files entirely in GitHub Actions

The semantic-versioning workflow could create the header and checksum directly.
This was rejected because local development and release automation would then
have different build interfaces. A Makefile provides one reproducible entry
point for both contexts.

## Consequences

Consumers receive a clearly identified `doxygen-bash.awk` release artifact whose
header records the version, source commit, and commit date associated with its
build. The corresponding `.sha256` file can be verified with standard SHA-256
tooling.

Historical releases that already contain `.256` assets remain unchanged.
Downstream tools can preserve compatibility with those releases by trying the
preferred `.sha256` asset first and falling back to `.256` only when the new name
is not present.

The root-level source remains concise and hand-maintained. Generated provenance
is present only in `dist/`, which is already ignored by the repository.

The project gains a Makefile and a small amount of build-specific test plumbing.
CI performs the regression suite twice, once against maintained source and once
against generated output. This increases test work slightly while proving that
the build transformation preserves observable filter behavior.

The generated artifact differs byte-for-byte from the maintained source by
design. Any dependency process that pins release checksums must therefore use
the checksum attached to the corresponding release rather than hashing the
root-level repository file.

## Open Questions and Follow-Ups

If consumers later need programmatic access to build metadata at awk runtime, a
separate decision should define that public interface rather than promoting
provenance comments into variables incidentally.

Artifact attestations may be considered separately. This decision establishes
the generated artifact and checksum contract without expanding release
permissions or supply-chain features beyond the requested scope.

## Related Decisions

- Related to: ADR-000, which requires evidence-oriented reasoning and explicit
  capability boundaries.
- Related to: ADR-001, which preserves consistency in generated Doxygen-facing
  output.
- Related to: ADR-002, which defines another source-to-generated-representation
  boundary within the filter.
