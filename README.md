# bash-doxygen

`bash-doxygen` is a documentation-led Doxygen filter for Bash.  It converts
Doxygen-style Bash comments and the Bash declaration that follows them into a
small pseudo-C++ representation that Doxygen can index.

The filter is intentionally conservative about what it documents: a function or
variable is only emitted when it is decorated with a Doxygen comment block.
Undocumented helper functions and implementation details are ignored.

The implementation lives in a single portable awk file:

```text
./doxygen-bash.awk
```

## Comment style

The primary supported style is a contiguous block of `##` comments immediately
before the declaration being documented:

```bash
## @brief Read a file from disk.
## @details
## The caller is responsible for validating the path before calling this
## function.
## @param path File path to read.
## @returns 0 on success; non-zero otherwise.
read_file() {
    cat -- "$1"
}
```

For variables, use `@var` when you want the filter to validate that the comment
matches the declaration:

```bash
## @var CACHE_DIR
## @brief Directory used for cached data.
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/example"
```

The filter preserves normal Doxygen commands such as `@brief`, `@details`,
`@param`, `@returns`, `@retval`, `@note`, `@warning`, `@see`, and custom aliases.
It only interprets a small structural subset: `@file`, `@fn`, `@var`, and
`@param` names.

## Manual usage

Run the filter directly with awk:

```sh
awk -f ./doxygen-bash.awk ./script.bash > ./script.dox.cpp
```

The generated file is not intended to be compiled.  It is a Doxygen-friendly
intermediate representation.

You can also make the filter executable:

```sh
chmod +x ./doxygen-bash.awk
./doxygen-bash.awk ./script.bash > ./script.dox.cpp
```

### Options

The filter accepts simple command-line options before file names:

```sh
awk -f ./doxygen-bash.awk -- --strict ./script.bash > ./script.dox.cpp
awk -f ./doxygen-bash.awk -- --compact ./script.bash > ./script.dox.cpp
```

`--strict` exits with a non-zero status when the filter emits a diagnostic.
This is useful in CI when documentation drift should fail the build.

`--compact` suppresses blank placeholder lines in the generated output.  By
default, blank lines are emitted for ignored source lines so Doxygen diagnostics
remain closer to the original Bash source locations.

## Doxyfile usage

Use the filter with Doxygen by adding it to `FILTER_PATTERNS`:

```ini
FILTER_PATTERNS = *.sh=./doxygen-bash.awk \
                  *.bash=./doxygen-bash.awk
```

A minimal configuration might look like this:

```ini
PROJECT_NAME = "Bash Project"
INPUT = .
FILE_PATTERNS = *.sh *.bash
RECURSIVE = YES
FILTER_PATTERNS = *.sh=./doxygen-bash.awk \
                  *.bash=./doxygen-bash.awk
EXTENSION_MAPPING = sh=C++ bash=C++
EXTRACT_ALL = NO
QUIET = YES
```

When using strict mode through Doxygen, wrap the filter in a small script:

```sh
#!/bin/sh
awk -f ./doxygen-bash.awk -- --strict "$@"
```

Then reference that wrapper from `FILTER_PATTERNS`.

## Supported declarations

The filter recognizes documented functions using common Bash forms:

```bash
name() {
name () {
function name {
function name() {
```

It recognizes documented variables using common assignment and declaration
forms:

```bash
NAME=value
NAME=(one two three)
readonly NAME=value
export NAME=value
local NAME=value
declare -r NAME=value
declare -a NAME=(one two three)
declare -A NAME=([key]=value)
declare -i COUNT=0
declare -n REF=NAME
declare -l LOWER=value
declare -u UPPER=value
```

Variable output is enriched with inferred Bash characteristics, including
read-only/read-write, exported, local, indexed array, associative array,
integer, nameref, lowercase transform, and uppercase transform.

## Diagnostics

Diagnostics are written to standard error.  The filter warns when:

- a documentation block is not followed by a recognized declaration;
- an `@fn` block precedes a variable declaration;
- an `@var` block precedes a function declaration;
- an `@fn` name differs from the function declaration;
- an `@var` name differs from the variable declaration.

With `--strict`, any warning causes the filter to exit non-zero.

## Testing

Run the complete test suite from the repository root:

```sh
make test
```

The suite uses small, behavior-focused fixtures.  Successful translations in
`tests/fixtures/` are compared with golden pseudo-C++ output in `tests/expected/`.
Diagnostic cases in `tests/diagnostics/` verify both normal warning behavior and
strict-mode failure.  The suite also covers compact/default blank-line behavior
and runs against both the maintained source and the generated distribution
artifact.

To exercise the maintained source directly without building `dist/`, run:

```sh
./tests/run-tests.sh
```

## Design notes

This project is not a full Bash parser.  It is a documentation compiler for the
small subset of Bash declarations that can reasonably follow a Doxygen block.
The parser is permissive about whitespace and declaration style, but strict
about documented intent when `@fn` or `@var` is provided.

## License

This project is licensed under the Creative Commons License 1.0 Universal
License.  See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
