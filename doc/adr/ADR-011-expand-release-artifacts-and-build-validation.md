# ADR-011: Expand Release Artifacts and Build Validation

Date: 2026-09-14

## Status

Accepted

## Context

ADR-004 established the initial `awk-doxygen` release boundary around one
consumer artifact, `dist/doxygen-awk.awk`, plus one SHA-256 checksum.  That
contract was appropriate while the repository was establishing the AWK filter,
replacing inherited Bash scaffolding, and proving that maintained and generated
bytes shared one regression contract.

The project now needs a richer distribution boundary.  Maintained source is
intentionally verbose and heavily documented, which is valuable for review and
maintenance but not necessary for every downstream consumer.  A development
artifact should preserve that documentation and build provenance, an ordinary
artifact should remove full-line comments while preserving executable behavior,
and a minified artifact should provide the smallest governed consumer form.

Issue #10 also requires GNU awk linting as an explicit development and release
validation step and requires regression output to be TAP-compliant.  Issue #11
requires all three generated AWK artifacts to run through the same semantic test
suite and requires each artifact to have its own SHA-256 checksum companion.

Minification introduces an executable build dependency.  `awk-minifier` is a
separately released project and therefore must cross an explicit dependency and
verification boundary rather than being downloaded ad hoc during a build.

The existing documentation publication and canary contracts in ADR-008 and
ADR-009 depend specifically on the ordinary release filename
`doxygen-awk.awk`.  Expanding the artifact matrix must preserve that filename so
stable documentation pins and exact-release canaries remain compatible.

## Decision Drivers

- Preserve the verbose maintained source and a fully documented development
  artifact for review and debugging.
- Provide an ordinary consumer artifact without full-line documentation comments.
- Provide a minified consumer artifact using a separately released, pinned tool.
- Verify the exact bytes of every release artifact independently.
- Exercise every executable artifact with the same behavior-focused regression
  contract.
- Emit standards-compliant TAP from the regression harness.
- Add GNU awk linting without changing the project's portable-AWK runtime floor.
- Keep linting separate from `make test` so tests remain semantic regression
  checks rather than a compound lint-and-test command.
- Preserve the existing `doxygen-awk.awk` ordinary release filename used by
  downstream documentation consumers and ADR-009 canaries.
- Keep dependency acquisition explicit and keep `make build` free of implicit
  network access.

## Decision

### Release artifact matrix

Normal builds and releases SHALL produce these executable AWK artifacts:

```text
dist/doxygen-awk.dev.awk
dist/doxygen-awk.awk
dist/doxygen-awk.min.awk
```

Each SHALL have a SHA-256 companion:

```text
dist/doxygen-awk.dev.awk.sha256
dist/doxygen-awk.awk.sha256
dist/doxygen-awk.min.awk.sha256
```

The six files together form the governed release artifact set.

This decision supersedes ADR-004 only where ADR-004 requires exactly one
consumer artifact and one checksum.  ADR-004 remains authoritative for the
maintained source name, generated-artifact boundary, comment-only provenance
principle, untracked `dist/` state, and requirement that release automation test
what it publishes.

### Development artifact

`dist/doxygen-awk.dev.awk` SHALL be the full generated form of the maintained
`doxygen-awk.awk` source.  It SHALL preserve the executable AWK shebang and all
maintained source documentation while adding generated provenance comments.

The development artifact SHALL carry the build metadata established by ADR-004:

```text
DOXYGEN_AWK_VERSION
DOXYGEN_AWK_BUILD_DATE
DOXYGEN_AWK_BUILD_COMMIT
```

Those values SHALL remain comments and SHALL NOT create executable AWK state.

### Ordinary artifact

`dist/doxygen-awk.awk` SHALL be generated from the development artifact by
removing full-line comments while preserving the first-line AWK shebang and
executable behavior.

This transformation deliberately removes Doxygen blocks, ordinary implementation
comments, and generated provenance comments from the ordinary artifact.  The
ordinary artifact remains the compatibility filename for existing consumers,
stable documentation dependency pins, and ADR-009 release canaries.

The transformation SHALL NOT attempt semantic rewriting, arbitrary whitespace
minification, or removal of comment-like text inside AWK string or regular
expression literals.  Its responsibility is limited to full-line comments.

### Minified artifact

`dist/doxygen-awk.min.awk` SHALL be produced by processing the ordinary artifact
through the pinned released `awk-minifier.awk` dependency.

The build SHALL execute the minifier with the selected AWK interpreter rather
than copying a moving latest release or invoking an unverified network download.
The resulting minified file SHALL preserve the executable behavior protected by
the regression suite.

### Build dependency boundary

Ordinary build dependencies SHALL be declared in:

```text
dependencies.txt
```

The initial minifier pin for this decision is:

```text
Repository: wesley-dean/awk-minifier
Release:    v0.2.4
Artifact:   awk-minifier.awk
Destination: vendor/awk-minifier.awk
SHA-256:    9668287c394a48e6143b63074fea8ab9fed240ef0637ac169780e08e30661803
```

The existing directly bootstrapped, SHA-256-pinned `bashdeps.bash` SHALL
synchronize and verify this manifest.

`make deps` MAY access the network because it prepares ordinary build
dependencies.  `make deps-check` SHALL verify prepared dependency state without
network access or repair.

`make build` SHALL NOT acquire or repair dependencies.  It SHALL require a
prepared and verified `vendor/awk-minifier.awk`.  `make all` MAY provide the
convenience path that prepares dependencies before invoking the offline build.

The documentation-only dependency boundary in `dependencies-docs.txt` remains
separate.  Adding AWK Minifier to the ordinary build SHALL NOT make it part of
the stable Doxygen publication dependency set.

### Checksums

Each generated AWK artifact SHALL receive its own standard SHA-256 checksum file.
The checksum line SHALL name the corresponding artifact basename so ordinary
`sha256sum -c` verification works from inside `dist/`.

Release automation SHALL verify all three checksum companions before publication
and SHALL publish all six governed files together.

### Regression testing and TAP

The behavior-focused test architecture established by ADR-005 remains
authoritative.  The same semantic suite SHALL exercise:

```text
doxygen-awk.awk
dist/doxygen-awk.dev.awk
dist/doxygen-awk.awk
dist/doxygen-awk.min.awk
```

The maintained source is included so source behavior remains directly visible;
the three generated artifacts are included so each build transformation is
proven behavior-preserving.

The shell regression harness SHALL emit TAP version 13 on standard output.  Test
records SHALL be numbered and SHALL end with a TAP plan.  Detailed diffs and
other diagnostic evidence MAY be written to standard error so they do not make
normal standard output invalid TAP.

Distribution artifacts are allowed to omit their own Doxygen documentation.
Self-documentation regression therefore means that each executable filter
artifact SHALL successfully process the maintained documented
`doxygen-awk.awk` source.  The test SHALL NOT require stripped or minified
artifacts to contain documentation that their artifact contract intentionally
removes.

### GNU awk linting

The Makefile SHALL provide:

```text
make check
```

`make check` SHALL run maintained root AWK source through GNU awk with
`--lint=fatal` and SHALL fail when GNU awk reports a lint condition at fatal
severity.

GNU awk is a development validation dependency for this target; it is not the
runtime compatibility floor.  Production filter source remains governed by the
portable-AWK requirements in ADR-001 and AGENTS.md, and the semantic CI matrix
continues to exercise both `mawk` and GNU awk.

`make test` SHALL NOT implicitly run `make check`.  CI and release automation
SHALL invoke linting explicitly so the two validation responsibilities remain
separate and failures remain attributable.

### CI and release integration

Pull-request and main-branch test automation SHALL prepare the build dependency,
run GNU awk linting, and run the semantic suite under both supported AWK
implementations.

Release automation SHALL:

1. prepare and verify the pinned build dependency;
2. run `make check` and maintained-source regression tests;
3. build and test all three generated AWK artifacts;
4. verify all three SHA-256 companions; and
5. publish all six governed release files.

The ordinary `doxygen-awk.awk` plus `doxygen-awk.awk.sha256` pair SHALL remain
present so ADR-009's exact-release documentation canary continues to test the
same downstream compatibility surface.

## Considered Alternatives

### Keep only the single ordinary artifact

This would preserve ADR-004 exactly but would force maintainers and consumers to
choose between fully documented source and a single distribution form.  It would
also leave no governed minified release artifact.  The project now has a concrete
need for distinct development, ordinary, and minimized forms.

### Publish maintained source directly as the development artifact

The repository could publish `doxygen-awk.awk` directly and reserve generated
filenames only for stripped/minified output.  This was rejected because the
existing generated boundary records immutable build provenance and allows tests
to distinguish maintained source from released bytes.

### Strip all comments with a lexical transformer

A lexical transformer could attempt more aggressive comment removal.  This is
unnecessary for the ordinary artifact and increases the risk of treating
comment-like characters inside strings or regular expressions as comments.
Full-line removal is inspectable and intentionally narrow; semantic compaction is
owned by AWK Minifier.

### Download AWK Minifier inside make build

This would make the build more convenient from a completely fresh checkout, but
it would hide network access and repair inside the canonical generation target.
The project already uses explicit acquisition-versus-verification boundaries for
documentation dependencies, so ordinary build tooling follows the same design.

### Add AWK Minifier to dependencies-docs.txt

AWK Minifier is required to build release artifacts, not to generate stable
reference documentation.  Combining the manifests would blur independent trust
and lifecycle boundaries and make documentation preparation acquire a tool it
does not use.

### Run linting from make test

This would provide one command for all validation, but issue #10 explicitly
requires linting to remain outside `test`.  Separating the targets also keeps
portable semantic regression failures distinct from GNU-specific lint feedback.

### Test only the ordinary artifact

Testing one generated flavor would not prove that the development assembly or
minifier transformation preserved behavior.  The cost of running the same small
fixture suite against all three artifacts is accepted because each build step is
a separate consumer boundary.

### Give every artifact an independent semantic fixture set

Separate fixture sets could encode artifact-specific expectations, but executable
semantics are intended to be identical.  One behavior suite better protects that
invariant and follows ADR-005's public-contract orientation.

## Consequences

Consumers receive three explicit distribution choices with independently
verifiable bytes.  The development form favors inspectability, the ordinary form
preserves the long-standing compatibility filename while dropping full-line
comments, and the minified form favors compact distribution.

The build now depends on one pinned executable external artifact.  A completely
fresh checkout must prepare that dependency with `make deps` or use `make all`
before invoking `make build`.  Once prepared, the canonical build is offline
with respect to dependency acquisition.

Regression runtime increases because the same suite executes against maintained
source plus three generated artifacts and does so under both `mawk` and GNU awk
in CI.  That cost is accepted because the added transformations otherwise create
untested release boundaries.

GNU awk becomes required for `make check`, while portable AWK remains the
production implementation floor.  This distinction must remain explicit in
documentation so lint tooling is not misrepresented as a runtime requirement.

ADR-008 and ADR-009 remain compatible because the ordinary artifact keeps the
existing `doxygen-awk.awk` filename and checksum companion.

## Related Decisions

- Partially supersedes ADR-004's single-artifact and single-checksum release
  shape while preserving its generated-boundary and provenance principles.
- Extends ADR-005 by requiring the same behavior-focused suite to exercise all
  generated artifact flavors and by standardizing harness output as TAP.
- Preserves ADR-008's separate documentation-only dependency boundary.
- Preserves ADR-009's exact ordinary release-artifact canary contract.
- Relies on ADR-000's requirements for explicit capability, trust, and evidence
  boundaries.
