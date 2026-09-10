# awk-doxygen

`awk-doxygen` is a documentation-led Doxygen filter for AWK.  It converts
intentionally documented AWK constructs into a small Doxygen-friendly
pseudo-C++ representation without pretending that AWK is C++ or that the
filter is a complete AWK parser.

The project was derived from
[`bash-doxygen`](https://github.com/wesley-dean/bash-doxygen), which provided the
architectural model for documentation buffering, conservative source
recognition, diagnostics, small regression fixtures, generated release
artifacts, and Doxygen-facing intermediate output.  `awk-doxygen` is an
independently governed project whose language contracts, ADRs, tests, releases,
and implementation may diverge wherever AWK semantics require it.

## Documentation standard

The normative, reusable AWK source-documentation standard is:

```text
doc/documentation-standard.md
```

The standard preserves the verbose, intent-oriented documentation philosophy
used by related Bash projects while defining AWK-native contracts for function
return values, caller parameters, conventional local formals, global state,
record processing, `BEGIN`/`END` blocks, and pattern/action rules.

The maintained comment dialect uses contiguous `##` lines:

```awk
## @fn normalize(value)
## @brief Normalizes a supplied value.
## @details
## Converts the value into the canonical representation expected by callers.
##
## @param value Value to normalize.
## @local result Scratch value used while normalizing.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns The normalized value.
function normalize(value,    result) {
    result = value
    return result
}
```

`@param` identifies caller-supplied formal parameters.  `@local` identifies
formal parameters that normal callers intentionally omit so they can serve as
portable AWK function-local storage.  Whitespace may make that convention easier
to read, but whitespace itself does not create an AWK semantic boundary.

## Implemented scope

The filter implements the governed function, global-state, and action-bearing
rule scope from ADRs 001 through 003, ADR-006, and ADR-007:

- file-level `@file` documentation;
- named AWK function headers whose complete parenthesized formal list appears on
  one physical line;
- an opening function brace on the header line or on a later line after only
  newline/comment-only separators;
- zero or more caller-visible `@param` formals;
- zero or more conventional `@local` formals;
- validation of `@fn` names against actual AWK function names;
- validation that every declared formal is documented exactly once as
  `@param` or `@local`;
- declaration-order validation for documented formals;
- rejection of a public `@param` after a documented `@local`;
- standalone `@var` documentation for significant global variables and arrays;
- validation that `@var` names are portable AWK identifiers;
- documented `BEGIN` and `END` rules;
- documented ordinary pattern/action rules whose opening action brace is on the
  rule-header line;
- documented action-only rules;
- validation of tooling-safe `@rule` identities;
- preservation of ordinary Doxygen directives such as `@brief`, `@details`,
  `@returns`, `@retval`, `@note`, `@warning`, and `@see`;
- one authoritative synthesized function signature containing caller-visible
  parameters only;
- Doxygen structural variable declarations using the generic `AwkValue`
  pseudo-type;
- file-local synthetic Doxygen functions representing documented AWK rules; and
- default line-preserving output plus compact output.

Both of these portable function layouts are supported:

```awk
function normalize(value,    result) {
```

```awk
function normalize(value,    result)
{
```

Blank lines or comment-only lines may appear between the function header and the
opening brace.  In default mode they remain blank placeholders in generated
output, while the synthesized Doxygen declaration stays on the original function
header line.

The generated pseudo-type `AwkValue` is deliberately synthetic.  It gives
Doxygen a stable shape to index and is not a claim that AWK has static types.
The same generic type is used for documented globals whether maintained prose
describes them as scalar-like values or arrays.

### Documented globals

AWK does not provide a general source-level variable declaration.  A maintained
`@var` block is therefore an authoritative documentation declaration rather than
metadata attached to the next assignment:

```awk
## @var record_count
## @brief Number of accepted input records.
## @details
## Initialized in BEGIN and incremented after validation succeeds.
```

The filter translates the structural line to the Doxygen-facing equivalent:

```cpp
/// @var AwkValue record_count
```

No following assignment or first use is required.  The filter does not infer
whether the global is scalar or array, numeric or string-like, mutable or
read-only, or where it is initialized.  Those semantics belong in the maintained
`@brief` and `@details` prose unless future governance establishes explicit
machine-readable metadata.

A conventional omitted function formal remains `@local`, not `@var`.

### Documented rules

AWK rules are not functions, so maintained source gives significant rules stable
`@rule` documentation identities without pretending those identities exist in
the AWK language:

```awk
## @rule initialize
## @brief Initializes parsing state.
## @par Trigger
## Runs once during BEGIN processing before the first input record is read.
BEGIN {
    FS = ":"
}
```

For Doxygen indexing, ADR-007 maps a supported rule to a generated file-local
no-argument function.  The source `@rule` line is suppressed, while the synthetic
declaration occupies the actual rule-header line:

```cpp
/// @brief Initializes parsing state.
/// @par Trigger
/// Runs once during BEGIN processing before the first input record is read.
static void awk_doxygen_begin_initialize();
```

Generated prefixes distinguish `BEGIN`, `END`, and ordinary/action-only rules:

```text
awk_doxygen_begin_<identity>
awk_doxygen_end_<identity>
awk_doxygen_rule_<identity>
```

These names and the `static void` declarations are Doxygen-facing indexing
artifacts only.  They do not describe callable AWK functions.

The initial parser recognizes action-bearing rule headers whose opening action
brace is the final token on the same physical line.  This includes `BEGIN`,
`END`, ordinary pattern/action rules, and the action-only `{` form.  The filter
does not parse or reproduce the pattern expression.

Pattern-only rules remain valid AWK and remain documentable under the source
standard, but the current filter does not synthesize Doxygen entities for them.
Supporting arbitrary pattern-only association would require a broader recognition
contract than the conservative action-brace anchor currently provides.

Formal lists split across physical lines remain outside the current function
parser boundary.  POSIX explicitly permits newlines before the opening function
brace, but its function grammar does not make arbitrary newlines part of the
formal list.  The filter therefore does not broaden its portable-AWK claim based
on implementation-specific continuation behavior.

## Manual usage

Run the maintained filter directly with AWK:

```sh
awk -f ./doxygen-awk.awk ./program.awk > ./program.dox.cpp
```

The generated file is an indexing representation for Doxygen.  It is not
intended to be compiled or executed.

The filter accepts two command-line options before source file names:

```sh
awk -f ./doxygen-awk.awk -- --strict ./program.awk
awk -f ./doxygen-awk.awk -- --compact ./program.awk
```

`--strict` exits non-zero when the filter emits a documentation diagnostic.
This is useful in CI when documentation drift should fail validation.

`--compact` suppresses blank placeholder lines.  Default mode emits a
one-for-one line representation for valid translated source wherever practical,
so generated declarations remain on the same line number as their AWK function
headers, maintained `@var` directives, or associated AWK rule headers.

## Doxyfile usage

Associate `.awk` files with the filter and map the generated representation to
C++ for Doxygen indexing:

```ini
PROJECT_NAME = "AWK Project"
INPUT = .
FILE_PATTERNS = *.awk
RECURSIVE = YES
FILTER_PATTERNS = *.awk=./doxygen-awk.awk
EXTENSION_MAPPING = awk=C++
EXTRACT_ALL = NO
EXTRACT_STATIC = YES
QUIET = YES
```

`EXTRACT_STATIC = YES` is required for generated rule entities because ADR-007
uses file-local `static` declarations so natural rule identities may recur in
different AWK files without becoming one apparent global pseudo-function.

When strict validation is required through Doxygen itself, use a small wrapper
that supplies `--strict` to the filter.

## Generated reference documentation

This repository publishes its own Doxygen reference documentation and deliberately
dogfoods both `awk-doxygen` and `bash-doxygen` while doing so.

Stable documentation dependencies are declared separately from the ordinary build
in `dependencies-docs.txt`.  A pinned `bashdeps` release materializes the pinned
filter artifacts and ADR navigation tooling beneath `vendor/`.  The current
stable pins are `awk-doxygen` v0.0.3, `bash-doxygen` v0.0.14, and `adrctl`
v0.0.13.

Prepare the documentation dependencies with:

```sh
make deps-docs
```

Verify them without network access or repair with:

```sh
make deps-docs-check
```

Generate the ephemeral linked ADR landing page from already-prepared dependency
state with:

```sh
make adr-index
```

Generate the stable reference tree with:

```sh
make docs
```

The generated ADR landing page lives at `doc/adr/README.md`; the generated HTML
lives under `doc/reference/`.  Both are ignored by Git and are regenerated from
maintained source and pinned documentation tooling rather than committed.
`make docs` consumes already-prepared dependency state; it does not synchronize
or repair dependencies itself.

Stable Pages generation intentionally uses the released, SHA-256-pinned
`vendor/doxygen-awk.awk`, not the repository-local filter.  This exercises the
same consumer boundary downstream projects use.  The same shared documentation
path generates the ADR landing page before Doxygen for stable publication and
both ADR-009 canaries, so those paths validate the same site structure.

ADR-009 adds two complementary canaries without moving the stable filter pins.
Pull requests and `main` generate the same reference corpus with current
repository `doxygen-awk.awk`, providing pre-release integration feedback.  When a
release is published, a second canary downloads the exact released
`doxygen-awk.awk` asset and checksum, verifies the bytes, and generates the same
reference documentation.  This catches both source-level regressions before
release and packaging failures after release while leaving stable Pages
publication reproducible.

Routine documentation generation includes linked ADR navigation only; it does
not automatically compose an ADR relationship graph.  ADR-010 governs the
landing-page generation and shared stable/canary boundary.

## Diagnostics

Diagnostics are written to standard error.  Current validation detects cases
including:

- an `@fn` name that differs from the following function declaration;
- a documented formal that does not exist in the declaration;
- a declared formal that is not classified as `@param` or `@local`;
- duplicate formal documentation;
- documentation order that differs from declaration order;
- a caller-visible `@param` appearing after a documented `@local`;
- a deferred function header that is not followed by an opening brace;
- an empty or invalid `@var` identity;
- an empty or invalid `@rule` identity;
- a `@rule` block separated from its AWK rule header;
- a `@rule` block not followed by a recognized action-bearing rule header,
  including pattern-only rules in the current implementation;
- a documentation block separated from its function declaration; and
- a documentation block not followed by a recognized function declaration.

Normal mode reports diagnostics while continuing translation.  Strict mode
reports the same diagnostics and exits non-zero.

## Build and release artifact

The maintained filter is:

```text
doxygen-awk.awk
```

`make build` generates the consumer artifact:

```text
dist/doxygen-awk.awk
```

The generated file preserves the AWK shebang and records version, build date,
and source commit provenance as comments so build metadata cannot change AWK
runtime behavior.

`make checksums` produces:

```text
dist/doxygen-awk.awk.sha256
```

Release automation publishes the generated AWK artifact and its checksum when
versioning is enabled.  ADR-004 governs that release boundary, while ADR-009 adds
a post-release canary that verifies and exercises the exact published artifact.

## Testing

Run the complete regression suite from the repository root:

```sh
make test
```

Select a particular AWK implementation with `AWK_BIN`:

```sh
make test AWK_BIN=mawk
make test AWK_BIN=gawk
```

CI exercises both `mawk` and GNU awk.  The active AWK suite uses small
behavior-focused fixtures under `tests/awk/` and runs the same semantic cases
against the maintained source and generated consumer artifact.

The suite covers file documentation, zero-parameter functions, caller-visible
parameters, conventional locals, a conventional local array, portable next-line
function braces, comment-separated opening braces, documented global variables
and arrays, EOF global blocks, global/source non-association, documented `BEGIN`
and `END` rules, ordinary action-bearing and action-only rules, invalid rule
identities, unsupported pattern-only association, descriptive Doxygen directives,
ignored undocumented source, validation failures, default source-line
correspondence, compact output, and strict self-validation of the filter's own
governed documentation.

The inherited Bash fixtures remain in the repository only as inactive historical
scaffolding and are not referenced by the AWK regression harness.

## Governance

Repository work is governed by:

- `AGENTS.md`;
- `doc/documentation-standard.md`;
- ADRs in `doc/adr/`; and
- concise ADR summaries in `doc/decisions.md`.

Accepted ADRs are project governance.  Consequential changes to source
recognition, interfaces, portability, release behavior, or compatibility should
be captured in an ADR unless an existing decision already governs them.

## License

This project is licensed under the Creative Commons License 1.0 Universal
License.  See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome.  Read [CONTRIBUTING.md](CONTRIBUTING.md),
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and [AGENTS.md](AGENTS.md) before
proposing changes.
