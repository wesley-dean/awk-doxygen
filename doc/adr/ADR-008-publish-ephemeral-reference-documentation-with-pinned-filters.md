# ADR-008: Publish Ephemeral Reference Documentation with Pinned Filters

Date: 2026-09-09

## Status

Accepted

## Context

`awk-doxygen` exists to translate intentionally documented source into a
Doxygen-friendly representation.  The repository should therefore generate and
publish its own reference documentation through the same consumer-facing filter
path used by downstream projects.

The repository contains maintained AWK in `doxygen-awk.awk` and maintained shell
code in `tests/run-tests.sh`.  The AWK source can be documented by a released
`awk-doxygen` artifact, while the shell source can be documented by the related
`bash-doxygen` project.  Using both filters in one reference build provides a
practical integration example without coupling their implementations or release
cadences.

Generated Doxygen HTML is derived output.  Committing the generated tree would
create large mechanical diffs and duplicate information already maintained in
source comments, Markdown documentation, and ADRs.

Documentation filters are executable development dependencies.  Their exact
bytes therefore need the same explicit, reviewable dependency boundary used by
other supply-chain-sensitive tooling.  `bashdeps` already provides immutable URL,
destination, and SHA-256 pinning and supports role-specific manifests.

## Decision Drivers

- Dogfood released filter artifacts through the same path downstream consumers
  use.
- Publish useful HTML reference documentation without committing generated HTML.
- Keep ordinary build and test behavior independent of documentation-only
  dependencies.
- Make dependency byte identity explicit and reviewable.
- Preserve a clear network boundary between dependency acquisition and
  documentation generation.
- Publish the exact documentation generated from the revision being deployed.
- Keep `awk-doxygen` and `bash-doxygen` independently versioned.

## Decision

Reference documentation SHALL be generated under:

```text
doc/reference/
```

`doc/reference/` SHALL be generated state, SHALL be ignored by Git, and SHALL be
removable through `make docs-clean`.

Documentation-only external dependencies SHALL be declared in:

```text
dependencies-docs.txt
```

The repository SHALL bootstrap one pinned released `bashdeps.bash` artifact
directly, verify its committed SHA-256 digest before execution, and use that
bootstrap to synchronize `dependencies-docs.txt` beneath `vendor/`.

The documentation manifest SHALL pin released filter artifacts by immutable
release URL and committed SHA-256 digest.  At the time this decision is adopted,
the stable publication pins are:

```text
wesley-dean/awk-doxygen@0.0.3 -> vendor/doxygen-awk.awk
wesley-dean/bash-doxygen@0.0.14 -> vendor/doxygen-bash.awk
```

The AWK filter used by Doxygen SHALL therefore be the vendored, bashdeps-verified
release artifact, not the repository-local maintained source.  The Bash filter
SHALL likewise be the vendored, bashdeps-verified release artifact.

`make deps-docs` MAY access the network because it synchronizes missing or stale
documentation dependencies.  `make deps-docs-check` SHALL verify prepared
bootstrap and manifest state without network access or repair.

`make docs` SHALL be offline with respect to repository dependency acquisition.
It SHALL require prepared documentation dependencies, verify them through
`make deps-docs-check`, remove prior generated reference output, validate the
pinned filters against representative maintained source, and invoke Doxygen.
It SHALL NOT invoke `make deps-docs` or otherwise repair missing dependency state.

The Doxygen configuration SHALL:

- use `vendor/doxygen-awk.awk` for maintained `.awk` input;
- use `vendor/doxygen-bash.awk` for maintained `.sh` and `.bash` input;
- include maintained Markdown and ADR material where useful;
- enable `EXTRACT_STATIC = YES` so ADR-007 rule entities are visible; and
- exclude `vendor/`, generated distribution output, generated reference output,
  and regression fixtures from published source material.

GitHub Pages publication SHALL regenerate `doc/reference/` from the checked-out
revision rather than publishing committed generated HTML.  The Pages workflow
SHALL explicitly synchronize and verify documentation dependencies before
running `make docs`, then upload `doc/reference/` as the Pages artifact.

## Considered Alternatives

### Use the repository-local AWK filter for published documentation

This would exercise current source, but it would not prove the released consumer
artifact and dependency-acquisition path used by downstream projects.  Current
source is valuable as a canary and is governed separately by ADR-009; stable Pages
publication uses pinned released bytes.

### Download filters directly in the Pages workflow

This duplicates acquisition and checksum logic and creates a CI-only dependency
path.  It was rejected in favor of the same bashdeps manifest used locally.

### Make `make docs` synchronize dependencies automatically

This hides network and repair behavior inside a generation target.  It was
rejected so dependency preparation remains explicit and `make docs` can be used as
an offline validation step after state is prepared.

### Commit generated HTML

This was rejected because the HTML is reproducible derived output and would add
large mechanical diffs without becoming the source of truth.

### Use one filter implementation for both languages

This was rejected because AWK and Bash have distinct source semantics and
independently governed filters.  A shared Pages site does not justify coupling
their implementations.

## Consequences

A fresh checkout must run `make deps-docs` before local reference generation.
Once dependencies are prepared, `make docs` and `make deps-docs-check` operate
without repository dependency acquisition.

The published site demonstrates the released `awk-doxygen` and `bash-doxygen`
consumer artifacts against real maintained source.  A stable pin means Pages does
not change merely because a newer filter release appears; proactive detection of
new-source and new-release breakage is provided separately by ADR-009.

Generated reference output remains disposable and can always be rebuilt from the
maintained revision plus pinned dependency declarations.

## Related Decisions

- ADR-000 requires capability claims to match observed behavior.
- ADR-004 defines the released `doxygen-awk.awk` consumer artifact.
- ADR-005 requires behavior-focused validation of maintained and generated
  filter bytes.
- ADR-007 requires `EXTRACT_STATIC = YES` for generated rule entities.
- ADR-009 defines proactive pre-release and post-release dogfood canaries while
  stable Pages publication remains pinned.
