# awk-doxygen

`awk-doxygen` is a documentation-led Doxygen filter for AWK.  It is intended to
convert intentionally documented AWK constructs into a small Doxygen-friendly
intermediate representation that Doxygen can index without pretending that AWK
is C++ or that the filter is a complete AWK parser.

The project is currently in its repository-establishment phase.  The repository
was seeded from [`bash-doxygen`](https://github.com/wesley-dean/bash-doxygen),
which provides the architectural model for documentation buffering, conservative
source recognition, diagnostics, small regression fixtures, generated release
artifacts, and Doxygen-facing pseudo-C++ output.  `awk-doxygen` is an independent
project: its language contracts, ADRs, tests, releases, and implementation are
governed here and may diverge from `bash-doxygen` as AWK semantics require.

The inherited Bash-oriented filter and fixtures remain transitional scaffolding
until the first AWK implementation replaces them.  They must not be treated as
evidence that this repository currently provides a working AWK filter.

## Documentation standard

The normative AWK source-documentation standard is:

```text
doc/documentation-standard.md
```

The standard is intentionally reusable by other AWK projects.  It preserves the
verbose, intent-oriented documentation philosophy used by related Bash projects
while defining AWK-native contracts for function return values, caller
parameters, conventional local formals, global state, record processing,
`BEGIN`/`END` blocks, and pattern/action rules.

The primary documentation style uses contiguous `##` lines:

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
portable AWK function-local storage.  The distinction is documentation metadata
about the intended interface; whitespace in an AWK parameter list is not itself
semantic.

The standard also defines `@var` for significant global state and `@rule` for
stable documentation identities associated with `BEGIN`, `END`, and ordinary
pattern/action rules.  Support for those constructs will be introduced only as
governing ADRs and regression tests establish their exact filter behavior.

## Design posture

`awk-doxygen` is a documentation compiler for an intentionally small subset of
AWK structure.  It is not intended to become a complete AWK parser.

The filter should be conservative:

- emit only intentionally documented constructs;
- prefer explicit documentation metadata over speculative inference;
- validate documented intent against source structure where the source provides
  enough information to do so reliably;
- preserve ordinary Doxygen commands unless translation is required for
  correctness;
- synthesize only the structural representation Doxygen needs; and
- avoid claiming AWK semantics that cannot be established from the source.

Portable AWK is the default compatibility floor unless a governing ADR changes
that decision.  Implementation-specific behavior must be explicit rather than
introduced accidentally.

## Planned filter interface

The intended maintained filter and release artifact are both named:

```text
doxygen-awk.awk
```

The intended manual interface follows the `bash-doxygen` model:

```sh
awk -f ./doxygen-awk.awk ./program.awk > ./program.dox.cpp
```

The generated file is an indexing representation for Doxygen.  It is not
intended to be compiled or executed.

Strict diagnostics and compact output are expected to remain part of the public
filter model, subject to the AWK implementation and regression contracts that
will establish them.

## Intended Doxyfile usage

Once the AWK implementation is complete, a Doxygen configuration will be able
to associate `.awk` files with the filter and map the generated representation
to C++ for indexing, conceptually:

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

The exact tested consumer configuration will be documented when the filter
implementation is established.

## Governance

Repository work is governed by:

- `AGENTS.md`;
- `doc/documentation-standard.md`;
- ADRs in `doc/adr/`; and
- concise ADR summaries in `doc/decisions.md`.

Accepted ADRs are project governance.  Consequential changes to source
recognition, interfaces, portability, release behavior, or compatibility should
be captured in an ADR unless an existing decision already governs them.

## Development status

The current phase establishes the AWK project identity and governance before
language implementation begins.  The next implementation phase will replace the
inherited Bash-oriented filter behavior and fixtures with AWK-oriented behavior,
starting with documented functions and the `@param` / `@local` contract.

Automatic release publication should remain disabled until the maintained AWK
filter, AWK regression suite, generated `doxygen-awk.awk` artifact, checksum, and
release workflow all describe and verify the same consumer contract.

## License

This project is licensed under the Creative Commons License 1.0 Universal
License.  See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome.  Read [CONTRIBUTING.md](CONTRIBUTING.md),
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and [AGENTS.md](AGENTS.md) before
proposing changes.
