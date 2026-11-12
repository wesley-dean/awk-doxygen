# ADR-013: Consolidate Scheduled GitHub Actions Dependency Updates

Date: 2026-11-12

## Status

Accepted

## Context

The repository currently checks GitHub Actions dependencies weekly with a
seven-day cooldown.  The active Dependabot group includes only minor and patch
releases.  A major release therefore produces an independent PR while a
minor/patch group can also be open, increasing review work for related
maintenance changes.  The shared coding standards v3.2.0 now include a
consolidated Dependabot maintenance standard.

The existing Dependabot auto-merge workflow uses the documented
`dependabot/fetch-metadata` highest-semver output to exclude
`version-update:semver-major`, so a group containing a major change is
expected to require human review.  CODEOWNERS and branch protection are
independent GitHub controls, not proved by having files in the repository.

The project's filter release, documentation canary, and pinned documentation
dependency workflows are security-sensitive.  Passing a source regression
test does not automatically prove an updated release or publishing action is
safe or compatible.

## Decision Drivers

- Reduce repeated routine Dependabot PR reviews.
- Preserve weekly cadence and seven-day cooldown.
- Keep advisory-driven security fixes independent.
- Maintain independent review and CI boundaries for high-risk actions.
- Protect the source filter's existing release and publication contracts.
- Avoid limiting new updates behind an arbitrary low open-PR cap.
- Preserve local accepted ADR authority over shared policy.

## Decision

The GitHub Actions ecosystem SHALL retain its existing directory,
weekly schedule, seven-day cooldown, and commit-message conventions.

A single group named `actions-version-updates` SHALL have
`applies-to: version-updates` and `patterns: ["*"]` and SHALL NOT
restrict `update-types`.  The configuration SHALL NOT add a restrictive
`open-pull-requests-limit` as a substitute for backlog management.

Security updates SHALL remain outside this group and its routine scheduling
policy.  Their availability depends on the separate dependency graph,
alerts, and GitHub security-update settings, which must be checked
independently.  This change SHALL NOT presume those settings are enabled.

The existing non-major-only Dependabot auto-merge workflow SHALL remain
unchanged.  A grouped PR whose highest semantic version change is major
is expected to remain outside automated merge requests.  Normal required
checks, CODEOWNERS enforcement, and permissions remain separately effective
only insofar as GitHub is configured to enforce them.

Reviews SHALL assess the highest-risk update within a group, particularly
actions able to write tags, publish release artifacts, use credentials, or
run untrusted code.  Relevant test evidence must be requested when current
CI does not exercise the changed release path.  A narrowly documented
dependency exclusion or separate group MAY be introduced when that risk
requires isolation.

The existing open Dependabot PRs remain open until later evidence establishes
that an observed new group supersedes them.  Grouping does not guarantee
exactly one PR per week, mixed-major bundling in every cycle, or reduced
risk from upstream dependencies.

## Alternatives Considered

### Retain minor/patch grouping

This keeps major releases isolated but perpetuates duplicate review effort
and does not follow the newly accepted portfolio-wide default.  Rejected
as a universal rule; individually justified exceptions remain possible.

### Merge major updates automatically

Would reduce clicks but could merge breaking or high-authority dependency
updates without adequate scrutiny.  Rejected.

### Group security updates with scheduled changes

Could delay vulnerability fixes and obscure their priority.  Rejected.

### Set a low open-PR limit

Could suppress fresh updates while stale PRs occupy the available limit.
Rejected without supporting operational evidence.

### Change to monthly frequency or group across ecosystems

Changes update latency and risk grouping beyond the scope of the present
GitHub Actions maintenance problem.  Deferred.

## Threats and Tradeoffs

A grouped update can obscure which dependency caused a failure and can contain
a compromised or breaking release.  CI may not exercise the publishing path.
An unenforced CODEOWNERS file is not an approval gate.  A disabled GitHub
security feature is not fixed by this YAML.  These risks are mitigated by
retained SHA pins, human review of high-authority changes, independent
GitHub protections, and targeted validation; they are not eliminated.

A single review can cover more updates, but larger groups may be harder
to debug.  Existing open PRs are not automatically closed, and actual
PR volume can be measured only after Dependabot runs.

## Compatibility and Migration

The change is confined to routine GitHub Actions dependency-update generation,
alongside this ADR and maintained repository documentation.  It does not
change AWK filter semantics, release artifact names, test expectations,
Doxygen documentation paths, workflow permissions, or existing auto-merge
conditions.  Retain older PRs until a replacement is observed and verified.

## Relationships

ADR-008 through ADR-011 govern pinned documentation inputs, current/released
canaries, ephemeral ADR navigation, and release validation.  ADR-012 governs
the immutable imported standards snapshot.  This decision implements the
applicable v3.2.0 Dependabot policy without superseding those local contracts.
