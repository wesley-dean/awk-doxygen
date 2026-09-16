# ADR-012: Adopt Shared Coding Standards

Date: 2026-09-15

## Status

Accepted

## Context

The repository already maintains project-specific ADRs, agent guidance,
source documentation, and review practices, while related projects share a
growing set of reusable coding, documentation, architecture, release, and
development-workflow standards in `wesley-dean/coding_standards`.

Keeping independent copies of those reusable rules would create drift and
make it unclear whether a repository-local copy or the shared standard is
authoritative.  In particular, the repository previously carried the AWK
documentation standard at `doc/documentation-standard.md` even though that
standard is now maintained in the shared standards repository.

Adoption must remain inspectable and reproducible.  A normal checkout must
contain the exact standards being applied, and future updates must be
deliberate reviewed changes rather than implicit network synchronization.

## Decision Drivers

- Keep reusable engineering standards consistent across related projects.
- Preserve repository-specific ADRs as the authority for local architecture.
- Make the exact adopted standards release and archive digest reviewable.
- Keep standards available to humans and coding agents offline in a checkout.
- Eliminate duplicate documentation-standard paths that could be interpreted
  as competing authorities.
- Avoid permanent standards downloaders or automatic synchronization logic.

## Decision

The repository SHALL commit the complete released standards snapshot from
`wesley-dean/coding_standards` beneath `doc/standards/` and SHALL record its
provenance in `.codingstandardrc`.

The initial adopted snapshot is `coding_standards@v1.0.9`, whose verified
`coding_standards.tar.gz` SHA-256 digest is
`86e91725f30dc5d91a3c7f7158e17d6a8538519b3be10709440e179027c37a03`.
The release tag resolves to commit
`22e42d2583cc98d4a7db8c48e1ab0c459f76946e`.

Applicable files under `doc/standards/` are governing project requirements.
Accepted repository-specific ADRs and explicit repository policy take
precedence when they intentionally refine or supersede a shared standard.
Presence in the complete snapshot does not make every language-specific
standard applicable.  Content under `doc/standards/examples/` remains
illustrative unless a governing standard explicitly promotes it.

Imported standards SHALL NOT be edited locally.  Shared changes belong in
the upstream `coding_standards` repository.  A future standards update SHALL
replace the complete managed snapshot, update `.codingstandardrc`, and be
reviewed through the repository's normal pull-request process.

The duplicate `doc/documentation-standard.md` file is removed.  Maintained
AWK source documentation is governed directly by
`doc/standards/awk/documentation-standard.md`, leaving one live
documentation-standard path.

No permanent downloader, updater, dependency-manifest entry, Make target, or
GitHub Actions synchronization workflow is introduced for coding standards.

## Alternatives Considered

### Keep the repository-local documentation standard

Rejected because two maintained paths for the same standard create ambiguity
and increase the chance that one copy drifts from the other.

### Import only standards that currently appear applicable

Rejected because partial snapshots make provenance and future updates harder
to reason about and can silently omit a cross-cutting standard introduced by
the released library.

### Fetch standards dynamically during development or CI

Rejected because a moving or network-dependent governance surface is less
inspectable and would make ordinary repository work depend on external state.

## Consequences

A normal checkout contains the exact shared standards snapshot used by the
repository.  Reviewers can identify its source version and digest from
`.codingstandardrc`, while local ADRs remain the place for project-specific
exceptions and architectural decisions.

Standards upgrades create ordinary repository diffs and therefore remain
visible in review.  The repository carries the storage cost of the complete
standards snapshot in exchange for inspectability and deterministic
governance.

## Compatibility

This is a governance and documentation change.  It does not change the
`doxygen-awk.awk` runtime interface, generated filter semantics, release
artifact contract, or supported AWK portability floor.

## Relationships

Existing accepted ADRs remain authoritative for `awk-doxygen` architecture,
behavior, portability, build, test, documentation-generation, and release
contracts.  This ADR establishes the shared-standards governance layer
beneath those repository-specific decisions.
