# ADR-014: Migrate Routine Dependency Updates to Centrally Managed Renovate

Date: 2026-11-26

## Status

Accepted

## Decision

The repository SHALL enroll in the centrally managed self-hosted Renovate service
through a minimal root `renovate.json`.  GitHub Actions routine Dependabot
version updates SHALL be disabled by setting `open-pull-requests-limit: 0`
on the existing `github-actions` ecosystem.  The remaining ecosystem,
schedule, cooldown, grouping, and commit-message configuration SHALL remain
available for historical interpretation and security-update compatibility.

GitHub Dependabot alerts, dependency graph, and security updates SHALL remain
enabled independently of scheduled version updates.  The existing
`dependabot[bot]`-scoped, non-major auto-merge workflow SHALL remain for
security-related Dependabot PRs.  Renovate SHALL NOT inherit its automation or
bypass CODEOWNERS, required checks, human approval, or existing branch rules.

This decision **supersedes ADR-013 only with respect to the scheduled
Dependabot version-update provider, its weekly schedule and grouping as an
active policy, and its prohibition on a low pull-request limit**.  ADR-013's
security response separation, release-risk review, and control boundaries
remain governing.  The historical ADR is retained as a record of the prior
strategy.

## Context and Constraints

The weekly grouped Dependabot policy was adopted to reduce review noise but
still requires repository-scoped scheduled maintenance.  A working Jenkins-run
Renovate service now provides central scheduling, signed commits, dependency
update policy, and native auto-merge subject to normal protections.
Repository enrollment must be explicit.  Existing GitHub Actions reference
pins and SHA-256-verified build inputs are part of the supply-chain trust
boundary.  This repository consumes a committed, versioned shared coding
standards snapshot that must not be edited as part of this migration.

## Assumptions

- The external Jenkins runner is already configured for `wesley-dean/*`.
- The Renovate machine account must have accepted write-level repository
  access; discovery alone is insufficient.
- Native auto-merge does not remove required review or CI gates.
- GitHub security settings are separately enabled; YAML changes do not
  prove their status.

These are deployment assumptions, not verified outcomes.

## Alternatives

1. **Keep Dependabot for routine updates:** rejected because it duplicates
   centrally managed maintenance and review.
2. **Delete Dependabot YAML:** rejected because preserving security update
   behavior, ecosystem metadata, and a reversible history is preferable.
3. **Run Renovate through repository-specific Actions:** rejected due to
   duplicated scheduling, authentication, and administration.
4. **Replace the existing Dependabot auto-merge workflow wholesale:**
   rejected because security-update PRs still use Dependabot and the
   workflow's identity-specific behavior must not be applied to Renovate.
5. **Replace immutable action SHAs with moving version tags:** rejected as
   a regression in dependency trust.

## Consequences and Migration

The migration PR introduces an explicit Renovate enrollment file and disables
routine Dependabot proposals without modifying application behavior.  The
existing open routine Dependabot PRs remain open until the migration lands;
they may be closed with an explanatory comment once replacement by Renovate
is established.  Any pinned action annotations may be corrected only after
their commit-to-upstream-tag mapping has been independently verified.  No
executable pin or SHA-256 manifest digest changes as part of a comment-only
normalization.

Access, protections, vulnerability alerts, security-update operation, and
successful Jenkins execution require separate operational verification.
If the machine account lacks write permission, merge must not be represented
as complete operational enrollment.  Changes to executable dependencies
require separate testing and review.

## Risks and Mitigations

Renovate or its credentials could exercise repository write privileges.
External releases may be malicious or incompatible, and grouped updates
can conceal individual breakages.  Retain SHA pins, code-owner review,
required CI, risk-based examination of privileged release actions,
and separate advisory-driven security maintenance.  Review upstream changes
when an existing pin has no verifiable tagged release; never fabricate version
metadata.

## Related Decisions

- ADR-008: Pinned, verified documentation dependencies.
- ADR-009: Current-source and released-filter canaries.
- ADR-011: Build and release validation.
- ADR-012: Committed shared coding standards.
- ADR-013: Prior grouped Dependabot maintenance policy, partially superseded.
