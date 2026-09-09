# ADR-009: Continuously Dogfood Current and Released Filters

Date: 2026-09-09

## Status

Accepted

## Context

Stable documentation publication under ADR-008 intentionally uses pinned filter
versions.  That stability is desirable for Pages, but it delays discovery of
regressions introduced by newer maintained source or newly published release
artifacts.

`awk-doxygen` is uniquely positioned to detect its own integration failures early
because its maintained source is substantial, intentionally documented AWK.  The
repository also contains documented shell tooling that exercises `bash-doxygen`.
A generated documentation build therefore provides a realistic end-to-end
consumer scenario in addition to the focused parser regression suite.

There are two materially different failure windows:

1. maintained source can become incompatible before a release is published; and
2. release packaging can produce bytes that differ from what source-level tests
   exercised or omit/misname the expected release artifact.

One canary cannot cover both windows.  A source canary provides earlier feedback,
while a release canary proves the exact artifact consumers can download.

At the same time, Pages should not silently follow the newest release.  Publication
must remain reproducible and reviewable through the pinned dependencies governed
by ADR-008.

## Decision Drivers

- Detect documentation-filter regressions before downstream consumers encounter
  them.
- Detect source-level integration failures before release publication.
- Detect packaging, release-asset, and checksum failures immediately after a
  release is published.
- Keep stable published documentation independent of automatic latest-version
  movement.
- Exercise real repository source rather than only synthetic fixtures.
- Keep canary failures visible in normal GitHub checks.
- Make the approach portable to related filter repositories such as
  `bash-doxygen`.

## Decision

The repository SHALL maintain three distinct documentation validation roles:

```text
stable publication
pre-release canary
post-release canary
```

### Stable publication

Stable Pages generation SHALL remain governed by ADR-008 and SHALL use the
explicit bashdeps-pinned filter versions in `dependencies-docs.txt`.

A newer `awk-doxygen` or `bash-doxygen` release SHALL NOT automatically change the
filter bytes used for published documentation.  Updating the stable pins remains
an ordinary reviewed dependency change.

### Pre-release canary

Pull-request and `main` CI SHALL generate the repository's reference documentation
using the current repository `doxygen-awk.awk` as the AWK filter.  This canary
SHALL run before release publication and SHALL fail when current filter source can
no longer process the maintained documentation corpus or when Doxygen cannot
successfully consume its generated representation.

The pre-release canary SHALL use real maintained repository inputs, including the
filter's own AWK source.  It MAY reuse the stable vendored Bash filter for Bash
inputs because the purpose of this canary is to evaluate current AWK filter
source, not an unreleased Bash implementation.

The canary SHALL NOT modify the stable dependency pin or publish Pages output.
Its generated HTML is disposable validation output.

### Post-release canary

A GitHub `release` event for a newly published `awk-doxygen` release SHALL trigger
a second reference-generation canary.

The post-release canary SHALL:

1. identify the release tag from the release event;
2. download the release's `doxygen-awk.awk` artifact and its checksum companion;
3. verify the downloaded filter against the released checksum before execution;
4. generate the same repository reference documentation using that exact released
   filter for AWK inputs; and
5. fail visibly if the artifact is missing, checksum verification fails, filter
   execution fails, or Doxygen cannot consume the generated representation.

The post-release canary SHALL test the exact downloadable artifact rather than a
checkout path corresponding to the same tag.  This distinction is intentional:
release packaging is part of the consumer contract.

The released filter SHALL be staged in a temporary or generated location and
SHALL NOT replace the stable bashdeps-pinned `vendor/doxygen-awk.awk` declaration.

### Common validation expectations

Both canaries SHOULD exercise the same Doxyfile and maintained documentation
corpus used by stable publication wherever the filter-path substitution permits
it.  Divergence between publication and canary configuration should be minimized
so passing canaries predict real consumer behavior.

Canary validation complements, rather than replaces, focused regression tests.
The parser regression suite remains responsible for narrow behavioral contracts;
the canaries detect integration failures across filter output, maintained source,
and Doxygen.

A canary failure SHALL block or visibly fail its associated CI run.  The project
SHALL NOT silently ignore a failing dogfood build merely because ordinary parser
fixtures still pass.

## Considered Alternatives

### Always publish Pages with the latest release

This would provide rapid feedback but would make stable documentation change
without a reviewed dependency update.  A bad release could break publication for
an otherwise unchanged repository.  It was rejected in favor of stable pins plus
separate canaries.

### Test only the repository-local filter

This detects many implementation regressions early but cannot detect a malformed,
missing, incorrectly named, or otherwise defective release artifact.  It was
rejected as incomplete.

### Test only the newest release on a schedule

A scheduled latest-release probe would eventually detect release problems but
would provide slower feedback and would not cover failures before release.  A
release-event canary is more direct.  A future scheduled probe MAY be added as
additional defense if external release state warrants it.

### Rely only on parser fixtures

Focused fixtures are necessary but cannot prove Doxygen integration, mixed-language
filter configuration, Pages-oriented source selection, or release packaging.
They remain complementary rather than sufficient.

### Update the stable pin automatically after a successful release canary

This would conflate validation with dependency-policy mutation.  It was rejected;
stable pin changes remain explicit reviewed commits.

## Consequences

A current-source regression should appear in PR or `main` CI before the code is
released.  A packaging or release-artifact regression should appear immediately
when the release is published, before normal consumers have much opportunity to
adopt it.

The repository intentionally executes more than one documentation path: stable
pinned publication, current-source validation, and exact-release validation.
That duplication is accepted because each path protects a different failure
boundary.

Pages remains predictable even if the newest release is broken.  Conversely, a
stable Pages site does not create false confidence that the newest source or
release artifact is healthy.

This model is intentionally portable to `bash-doxygen`: substitute its maintained
filter source and release artifact as the primary canary target while retaining
stable publication pins and the same source-versus-release separation.

## Related Decisions

- ADR-000 requires evidence-backed capability claims.
- ADR-004 defines the release artifact whose published bytes are checked by the
  post-release canary.
- ADR-005 defines focused regression fixtures that remain complementary to these
  integration canaries.
- ADR-008 defines stable pinned documentation publication and the shared Doxygen
  corpus used by the canaries.
