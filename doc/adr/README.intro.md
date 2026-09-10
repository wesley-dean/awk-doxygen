# awk-doxygen Architecture and Reference Documentation

`awk-doxygen` is a documentation-led Doxygen filter for AWK.  It translates an
intentionally small, explicitly documented subset of AWK structure into a
Doxygen-friendly representation while keeping source semantics, generated
indexing structures, portability claims, and unsupported syntax boundaries
explicit.

The repository separates documentation by responsibility:

- [`README.md`](../../README.md) provides project orientation, supported behavior,
  usage, build, release, and testing guidance.
- [`doc/documentation-standard.md`](../documentation-standard.md) defines the
  reusable AWK source-documentation standard.
- [`doc/decisions.md`](../decisions.md) provides concise summaries of the
  architecture decisions represented below.
- ADRs preserve the context, rationale, alternatives, constraints, and
  consequences behind durable project decisions.
- Generated Doxygen pages document the maintained AWK filter and shell test
  harness through the same released-filter integration used by downstream
  consumers.

The ADRs remain authoritative for architectural intent.  Generated navigation
and generated Doxygen output are derivative documentation state.

## Architecture Decision Records
