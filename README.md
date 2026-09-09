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

The initial filter implements the governed function-focused scope from ADRs 001
through 003:

- file-level `@file` documentation;
- single-line named AWK declarations shaped as `function name(formals) {`;
- zero or more caller-visible `@param` formals;
- zero or more conventional `@local` formals;
- validation of `@fn` names against actual AWK function names;
- validation that every declared formal is documented exactly once as
  `@param` or `@local`;
- declaration-order validation for documented formals;
- rejection of a public `@param` after a documented `@local`;
- preservation of ordinary Doxygen directives such as `@brief`, `@details`,
  `@returns`, `@retval`, `@note`, `@warning`, and `@see`;
- one authoritative synthesized function signature containing caller-visible
  parameters only; and
- default line-preserving output plus compact output.

The generated pseudo-type `AwkValue` is deliberately synthetic.  It gives
Doxygen a stable shape to index and is not a claim that AWK has static types.

The documentation vocabulary also defines `@var` and `@rule`, but those
constructs are not emitted by this implementation yet.  A documented `@var` or
`@rule` association therefore produces a diagnostic rather than speculative
Doxygen structure.

Multiline function declarations are also outside the current parser boundary.
Expanding that boundary should be governed and regression-tested rather than
introduced incidentally.

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
so generated declarations remain on the same line number as their AWK
function declarations.

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
QUIET = YES
```

When strict validation is required through Doxygen itself, use a small wrapper
that supplies `--strict` to the filter.

## Diagnostics

Diagnostics are written to standard error.  Current validation detects cases
including:

- an `@fn` name that differs from the following function declaration;
- a documented formal that does not exist in the declaration;
- a declared formal that is not classified as `@param` or `@local`;
- duplicate formal documentation;
- documentation order that differs from declaration order;
- a caller-visible `@param` appearing after a documented `@local`;
- a documentation block separated from its function declaration;
- a documentation block not followed by a recognized function declaration; and
- currently unsupported `@var` or `@rule` associations.

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

Automatic release publication remains disabled during active development.  The
workflow and artifact naming are nevertheless kept aligned with the governed
AWK release contract so release publication can be enabled deliberately rather
than repaired during a release.

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

The suite currently covers file documentation, zero-parameter functions,
caller-visible parameters, conventional locals, a conventional local array,
descriptive Doxygen directives, ignored undocumented source, validation
failures, default source-line correspondence, compact output, and strict
self-validation of the filter's own governed function documentation.

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
