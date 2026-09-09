#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

AWK_BIN=${AWK_BIN:-awk}
FILTER=${DOXYGEN_AWK_FILTER:-"$ROOT_DIR/doxygen-awk.awk"}
case "$FILTER" in
    /*) ;;
    *) FILTER="$ROOT_DIR/$FILTER" ;;
esac

CASE_COUNT=0

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

normalize_warnings() {
    sed 's/^.*: warning: //' "$1"
}

for expected in "$ROOT_DIR"/tests/awk/expected/*.cpp; do
    name=${expected##*/}
    name=${name%.cpp}
    input="$ROOT_DIR/tests/awk/fixtures/$name.awk"
    actual="$TMP_DIR/$name.cpp"
    errors="$TMP_DIR/$name.err"

    test -f "$input" || fail "missing input fixture for $name"

    if ! "$AWK_BIN" -f "$FILTER" -- --compact "$input" >"$actual" 2>"$errors"; then
        fail "compact output case failed to execute: $name"
    fi
    test ! -s "$errors" || fail "compact output case emitted a diagnostic: $name"
    diff -u "$expected" "$actual" || fail "compact output mismatch: $name"

    CASE_COUNT=$((CASE_COUNT + 1))
    printf 'ok - output: %s\n' "$name"
done

for expected in "$ROOT_DIR"/tests/awk/diagnostics/*.err; do
    name=${expected##*/}
    name=${name%.err}
    input="$ROOT_DIR/tests/awk/diagnostics/$name.awk"
    warning_err="$TMP_DIR/$name.warning.err"
    strict_err="$TMP_DIR/$name.strict.err"
    normalized="$TMP_DIR/$name.normalized.err"

    test -f "$input" || fail "missing diagnostic fixture for $name"

    if ! "$AWK_BIN" -f "$FILTER" -- --compact "$input" \
        >"$TMP_DIR/$name.warning.cpp" 2>"$warning_err"; then
        fail "non-strict diagnostic case exited non-zero: $name"
    fi
    normalize_warnings "$warning_err" >"$normalized"
    diff -u "$expected" "$normalized" || fail "non-strict diagnostic mismatch: $name"

    if "$AWK_BIN" -f "$FILTER" -- --strict --compact "$input" \
        >"$TMP_DIR/$name.strict.cpp" 2>"$strict_err"; then
        fail "strict diagnostic case exited zero: $name"
    fi
    normalize_warnings "$strict_err" >"$normalized"
    diff -u "$expected" "$normalized" || fail "strict diagnostic mismatch: $name"

    CASE_COUNT=$((CASE_COUNT + 1))
    printf 'ok - diagnostic: %s\n' "$name"
done

# Default mode should preserve one output line for every valid source line.
input="$ROOT_DIR/tests/awk/fixtures/function-conventional-locals.awk"
actual="$TMP_DIR/default-lines.cpp"
errors="$TMP_DIR/default-lines.err"
"$AWK_BIN" -f "$FILTER" "$input" >"$actual" 2>"$errors"
test ! -s "$errors" || fail 'default mode emitted a diagnostic'
expected_lines=$(wc -l <"$input" | tr -d ' ')
actual_lines=$(wc -l <"$actual" | tr -d ' ')
test "$actual_lines" -eq "$expected_lines" || fail 'default mode did not preserve source line count'
source_decl_line=$(grep -n '^function normalize' "$input" | cut -d: -f1)
output_decl_line=$(grep -n '^AwkValue normalize' "$actual" | cut -d: -f1)
test "$source_decl_line" = "$output_decl_line" || fail 'generated declaration moved from its source line'
CASE_COUNT=$((CASE_COUNT + 1))
printf '%s\n' 'ok - mode: source line correspondence'

# A deferred opening brace must preserve the original header line and all
# intervening newline/comment lines in default mode.
input="$ROOT_DIR/tests/awk/fixtures/function-brace-after-comment.awk"
actual="$TMP_DIR/multiline-lines.cpp"
errors="$TMP_DIR/multiline-lines.err"
"$AWK_BIN" -f "$FILTER" "$input" >"$actual" 2>"$errors"
test ! -s "$errors" || fail 'multiline function emitted a diagnostic'
expected_lines=$(wc -l <"$input" | tr -d ' ')
actual_lines=$(wc -l <"$actual" | tr -d ' ')
test "$actual_lines" -eq "$expected_lines" || fail 'multiline function did not preserve source line count'
source_decl_line=$(grep -n '^function normalize' "$input" | cut -d: -f1)
output_decl_line=$(grep -n '^AwkValue normalize' "$actual" | cut -d: -f1)
test "$source_decl_line" = "$output_decl_line" || fail 'multiline generated declaration moved from its source header line'
comment_line=$(grep -n '^# Keep the opening brace' "$input" | cut -d: -f1)
brace_line=$(grep -n '^{' "$input" | head -n 1 | cut -d: -f1)
if sed -n "${comment_line}p" "$actual" | grep -q '[^[:space:]]'; then
    fail 'multiline comment placeholder was not blank'
fi
if sed -n "${brace_line}p" "$actual" | grep -q '[^[:space:]]'; then
    fail 'multiline brace placeholder was not blank'
fi
CASE_COUNT=$((CASE_COUNT + 1))
printf '%s\n' 'ok - mode: multiline source line correspondence'

# Undocumented input should remain entirely blank in default mode.
input="$ROOT_DIR/tests/awk/fixtures/undocumented-ignored.awk"
actual="$TMP_DIR/default-blanks.cpp"
errors="$TMP_DIR/default-blanks.err"
"$AWK_BIN" -f "$FILTER" "$input" >"$actual" 2>"$errors"
test ! -s "$errors" || fail 'default mode emitted a diagnostic for ignored lines'
expected_lines=$(wc -l <"$input" | tr -d ' ')
actual_lines=$(wc -l <"$actual" | tr -d ' ')
test "$actual_lines" -eq "$expected_lines" || fail 'ignored input did not preserve line count'
if grep -q '[^[:space:]]' "$actual"; then
    fail 'default mode emitted non-blank content for undocumented input'
fi
CASE_COUNT=$((CASE_COUNT + 1))
printf '%s\n' 'ok - mode: undocumented blank placeholders'

# The maintained/generated filter must satisfy its own governed function metadata.
actual="$TMP_DIR/self.cpp"
errors="$TMP_DIR/self.err"
if ! "$AWK_BIN" -f "$FILTER" -- --strict --compact "$FILTER" >"$actual" 2>"$errors"; then
    fail 'filter self-documentation failed strict validation'
fi
test ! -s "$errors" || fail 'filter self-documentation emitted a diagnostic'
grep -q '^AwkValue parse_function_decl(' "$actual" || fail 'self-documentation omitted parser function'
CASE_COUNT=$((CASE_COUNT + 1))
printf '%s\n' 'ok - self: governed function documentation'

printf 'ok - %s regression cases passed with %s\n' "$CASE_COUNT" "$AWK_BIN"
