# ADR-010: Publish Ephemeral ADR Navigation Across Documentation Paths

Date: 2026-09-09

## Status

Accepted

## Intent and Documentation Posture

This ADR extends the documentation architecture established by ADR-008 and the
stable/canary separation established by ADR-009.  It makes the Architecture
Decision Record corpus the landing page for generated Doxygen documentation by
assembling a linked ADR table of contents into an ephemeral Markdown file before
Doxygen runs.

The generated landing page is navigation, not architectural source.  Maintained
framing remains in separate Markdown fragments, ADRs remain authoritative for
decision rationale, and `doc/decisions.md` remains the concise decision map.

All documentation-generation paths SHALL use the same landing-page assembly so
stable Pages publication, current-source dogfood, and exact-release dogfood do
not silently validate different documentation sites.

## Context

ADR-008 requires generated Doxygen reference documentation to be ephemeral,
requires documentation-only dependencies to be isolated in
`dependencies-docs.txt`, and deliberately keeps `make docs` offline after those
dependencies have been prepared.  It also explicitly permits maintained Markdown
and ADR material to be part of the published Doxygen corpus.

ADR-009 adds two canary paths around that stable publication model.  The
current-source canary substitutes the repository's maintained `doxygen-awk.awk`,
while the released-artifact canary substitutes the exact downloadable release
artifact.  Both are expected to reuse the stable Doxyfile and maintained
documentation corpus as closely as possible.

The current Doxyfile includes the ADR directory, but its main page is the
repository root `README.md`.  The ADR corpus is therefore available as reference
material without providing a useful architectural navigation surface at the site
root.  Related repositories now generate a linked ADR index from maintained
introductory and closing fragments and use that generated composite as the
Doxygen main page.

`adrctl` already owns the public `generate toc` report and is released as a
single versioned Bash artifact with published SHA-256 verification data.  Using a
pinned released artifact lets this repository consume the same public interface a
downstream project would use rather than implementing an independent ADR
enumerator in Make or shell code.

The repository already has a role-specific documentation manifest and a strict
network boundary.  The new dependency and generation step must fit that model
rather than weakening it for convenience.

## Decision Drivers

- Give the generated documentation site a useful architectural landing page.
- Keep ADR titles and links mechanically synchronized with the actual managed ADR
  corpus.
- Keep generated navigation out of Git history.
- Preserve `make docs` as an offline consumer of prepared documentation state.
- Reuse the existing documentation-only bashdeps manifest rather than adding a
  second acquisition mechanism.
- Use adrctl's public released `generate toc` contract instead of maintaining a
  repository-specific ADR parser.
- Preserve the stable/current-source/released-artifact canary architecture from
  ADR-009.
- Ensure every Doxygen path validates the same generated navigation surface.
- Preserve atomic replacement so a failed TOC generation does not leave a
  partially written landing page.
- Keep automatic ADR relationship graphs out of routine documentation builds.

## Decision

### Maintain framing and generate the composite landing page

The repository SHALL maintain these source files:

```text
doc/adr/README.intro.md
doc/adr/README.outro.md
```

The documentation build SHALL generate:

```text
doc/adr/README.md
```

by composing the maintained introduction, adrctl-generated linked ADR table of
contents, and maintained outro.

`doc/adr/README.md` SHALL be generated state.  It SHALL be ignored by Git and
SHALL NOT become a second maintained list of ADRs.

The generated page SHALL be Doxygen's Markdown main page.

### Use a pinned released adrctl documentation dependency

The documentation manifest SHALL include a released `adrctl.bash` artifact at:

```text
vendor/adrctl.bash
```

The initial pin for this decision is:

```text
Repository: wesley-dean/adrctl
Release:    v0.0.13
Artifact:   adrctl.bash
SHA-256:    5b5c34aeeff59cbadda1f9810c64983555013693139eae4746e979a556149e6e
```

The pin SHALL live in `dependencies-docs.txt` and SHALL be synchronized and
verified through the same bashdeps boundary used for the released AWK and Bash
Doxygen filters.

The Makefile SHALL NOT download adrctl independently, infer a moving latest
release, or trust an unverified executable merely because it has the expected
filename.

The released adrctl artifact is documentation tooling only.  It SHALL NOT become
an input to `make build`, the generated `dist/doxygen-awk.awk` artifact, the AWK
runtime, or the filter regression semantics.

### Preserve the explicit network boundary

`make deps-docs` remains the operation that MAY access the network and repair
missing or stale documentation dependencies.

`make deps-docs-check` remains a verification-only operation over already
prepared dependency state.

A new target:

```text
make adr-index
```

SHALL require the prepared `vendor/adrctl.bash`, maintained intro fragment, and
maintained outro fragment.  It SHALL NOT invoke `make deps-docs`, download
anything, or repair dependency state.

`make docs` SHALL remain offline with respect to repository dependency
acquisition.  Its existing `deps-docs-check` prerequisite SHALL continue to
verify all prepared documentation dependencies, including adrctl, before stable
reference generation proceeds.

### Generate the landing page atomically

`make adr-index` SHALL write candidate output to a temporary file in the same
directory as the final `doc/adr/README.md` and replace the final path only after
adrctl completes successfully.

If generation fails, the temporary candidate SHALL be removed and an existing
complete landing page SHALL not be intentionally replaced with partial output.

The target SHALL invoke the released artifact through Bash and the public report
surface:

```text
adrctl generate toc
```

using the maintained intro and outro options supported by the pinned release.
The Makefile SHALL not reproduce ADR discovery, logical numbering, title
extraction, link construction, or sorting independently.

### Use one navigation path for stable and canary documentation

The common `docs-canary` target SHALL invoke `make adr-index` before invoking
Doxygen.

This placement is intentional.  Stable `make docs` already delegates final
Doxygen generation to `docs-canary` with the pinned released AWK and Bash
filters.  The current-source and post-release workflows also call
`docs-canary` with different AWK-filter paths.

Consequently, all three documentation roles SHALL consume the same generated ADR
landing page:

```text
stable Pages publication
current-source AWK filter canary
exact released AWK filter canary
```

A future documentation path that intentionally bypasses this common target must
explicitly decide whether and why it should publish a different documentation
corpus.

### Configure Doxygen around the generated page

The Doxyfile SHALL set:

```text
USE_MDFILE_AS_MAINPAGE = doc/adr/README.md
```

The generated page remains within the existing `doc/adr` input tree.  The root
`README.md`, `AGENTS.md`, `doc/decisions.md`, the AWK documentation standard, the
ADR corpus, maintained source, and other already-selected material remain
available as reference pages unless separately changed by governance.

`README.intro.md` and `README.outro.md` SHALL be excluded from standalone Doxygen
publication because their content is already composed into the generated main
page.

The ADR templates and generated reference output remain excluded under the
existing publication model.

### Keep cleanup ownership explicit

`make docs-clean` SHALL continue to remove the generated Doxygen tree under
`doc/reference/` as required by ADR-008.

`make distclean` SHALL additionally remove `doc/adr/README.md` along with other
generated dependency/build state so a deep cleanup can return the repository to
a fresh-checkout generated-state boundary.

Ordinary `make docs-clean` does not need to remove the generated Markdown
intermediate merely to rebuild HTML.  The next `make adr-index` invocation
replaces the complete page atomically.

### Keep routine documentation graph-free

This decision introduces linked textual ADR navigation only.

Routine `make adr-index`, `make docs`, and `make docs-canary` SHALL NOT invoke
`adrctl generate graph` or automatically compose DOT, Mermaid, SVG, PNG, or
another ADR relationship graph into the landing page.

A repository may still use adrctl's graph report explicitly for another purpose.
Such explicit use is separate from the stable documentation landing-page contract
established here.

## Trust and Failure Model

The adrctl executable is an externally produced documentation dependency and is
therefore treated with the same supply-chain boundary as the existing released
filters.  Its identity is authorized by a reviewed immutable release URL and
committed SHA-256 digest in `dependencies-docs.txt`.

`make adr-index` assumes that dependency preparation and verification have already
established acceptable local bytes.  Stable `make docs` enforces that assumption
through `deps-docs-check`; canary workflows prepare and verify the same manifest
before invoking the common documentation path.

Expected failure cases include:

- missing or non-readable `vendor/adrctl.bash`;
- missing maintained intro or outro fragments;
- digest mismatch detected by `deps-docs-check`;
- adrctl failure while discovering or serializing the ADR corpus;
- Doxygen failure after successful landing-page generation; and
- canary filter substitution failure unrelated to ADR navigation.

A failure in one stage SHALL remain visible rather than being hidden by fallback
to an older hand-maintained index or by silently downloading replacement bytes in
`make adr-index`.

## Considered Alternatives

### Keep the root README as the Doxygen main page

This preserves the current site root, but it leaves the ADR corpus as secondary
navigation and does not address the goal of exposing the project's architectural
history directly.  The root README remains available as a generated reference
page, so changing the main page does not remove it from the documentation corpus.

### Commit doc/adr/README.md

A committed generated index would be visible in ordinary repository browsing,
but it would duplicate information derived from the ADR corpus and create
mechanical synchronization diffs.  ADR-008 already establishes generated
reference documentation as ephemeral state, and the same principle applies to
this generated navigation intermediate.

### Generate the TOC with shell, awk, or Make

The repository could enumerate `doc/adr/ADR-*.md`, extract headings, sort names,
and emit Markdown directly.  That would create another ADR discovery and
serialization implementation even though adrctl already owns and tests that
public behavior.  It was rejected in favor of consuming the released tool.

### Use the current repository's software as the TOC generator

`awk-doxygen` does not implement ADR management, so there is no local product
implementation to reuse.  Introducing bespoke local logic would provide no
self-hosting advantage and would enlarge the repository's documentation code.

### Let make adr-index synchronize dependencies

This would make an apparently generative target perform network access and repair,
contradicting ADR-008's explicit acquisition-versus-consumption boundary.  It was
rejected so missing prepared state remains a clear actionable failure.

### Generate the page only in the Pages workflow

Pages-only assembly would leave local `make docs` and the two ADR-009 canaries
validating a different site.  It was rejected because shared documentation
configuration is a core purpose of the common `docs-canary` target.

### Generate the page only in stable make docs

This would improve Pages while leaving current-source and exact-release canaries
without the same main page.  The canaries would then provide weaker evidence
about the site they are intended to predict.

### Add a relationship graph to the landing page

A graph can be useful for explicit analysis, but routine graph composition adds
rendering and presentation concerns beyond the navigation goal.  The current
cross-repository convention intentionally keeps routine generated documentation
graph-free.

## Consequences

The Pages root becomes an architecture-oriented entry point with mechanically
current links to the managed ADR corpus.

Maintainers edit the intro, outro, ADRs, and decision summaries as source; they do
not maintain the generated ADR list manually.

The documentation manifest gains one executable dependency, increasing the
prepared documentation trust surface by one pinned artifact.  This cost is
accepted because the dependency supplies a public, reusable ADR discovery and TOC
contract that would otherwise be duplicated locally.

Stable and canary documentation generation remain aligned.  A change to the
Doxyfile corpus or landing-page generation affects all three paths, while ADR-009
continues to vary only the AWK filter bytes under test.

A fresh checkout still requires `make deps-docs` before documentation generation.
Once dependencies are prepared, stable and canary generation remain offline with
respect to repository dependency acquisition.

The generated `doc/adr/README.md` may remain in a developer working tree between
documentation builds, but it is ignored and replaceable.  `make distclean`
provides the complete generated-state cleanup boundary.

## Related Decisions

- Extends ADR-008, which governs pinned documentation dependencies, offline
  generation after preparation, ephemeral output, and Pages publication.
- Extends ADR-009, which requires stable, current-source, and exact-release
  documentation paths to share the same Doxyfile and maintained corpus wherever
  practical.
- Relies on ADR-000's requirement for explicit capability and trust boundaries.
- Does not change ADR-004's AWK release artifact contract.
- Does not change ADR-005's focused parser regression strategy.
- Does not change ADR-007's `EXTRACT_STATIC = YES` integration requirement.
