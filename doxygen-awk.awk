#!/usr/bin/awk -f
## @file doxygen-awk.awk
## @brief Converts documented AWK constructs into Doxygen-friendly declarations.
## @details
## Implements the documentation-led subset governed by ADRs 001 through 003,
## ADR-006, and ADR-007.  The filter recognizes file blocks, portable named AWK
## function declarations, explicitly documented global variables or arrays, and
## documented action-bearing AWK rules.  It validates @fn, @param, @local, @var,
## and @rule metadata and emits line-based Doxygen comments plus synthetic
## declarations.  Function opening braces may follow newline/comment-only lines;
## rule opening braces remain on the rule-header line.  Pattern-only rules are
## outside the current recognition boundary.  The implementation uses portable
## AWK language features; diagnostics are written to /dev/stderr on Unix-like
## hosts.

## @rule initialize_filter
## @brief Initializes filter options and documentation-buffer state.
## @details
## Resolves strict and compact command-line flags before source records are
## translated and establishes the initial empty documentation state.
##
## @par STDIN
## Nothing is read directly from STDIN by this rule.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
BEGIN {
    strict = (strict ? strict : 0)
    keep_blanks = (compact ? 0 : 1)
    pending_function = 0
    pending_gap_count = 0

    for (arg_index = 1; arg_index < ARGC; arg_index++) {
        if (ARGV[arg_index] == "--strict") {
            strict = 1
            ARGV[arg_index] = ""
        } else if (ARGV[arg_index] == "--compact") {
            keep_blanks = 0
            ARGV[arg_index] = ""
        }
    }

    reset_doc()
}

## @fn clear_array(array)
## @brief Removes every entry from an array using portable AWK syntax.
## @details
## Portable AWK guarantees deletion of individual array elements but does not
## require the whole-array `delete array` extension.  This helper preserves the
## project's portability floor when resetting parser state.
##
## @param array Array whose entries will be removed.
## @local key Current array key during iteration.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns No meaningful value; callers use the function for its side effect.
function clear_array(array,    key) {
    for (key in array) {
        delete array[key]
    }
}

## @fn reset_doc()
## @brief Clears buffered documentation and per-block metadata.
## @details
## Resets all state owned by the current documentation block before processing
## the next source construct.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns No meaningful value; callers use the function for its side effect.
function reset_doc() {
    doc_count = 0
    doc_kind = ""
    doc_name = ""
    formal_doc_count = 0
    clear_array(doc_lines)
    clear_array(formal_doc_names)
    clear_array(formal_doc_kinds)
    clear_array(formal_doc_lines)
}

## @fn trim(value)
## @brief Removes leading and trailing ASCII whitespace used by AWK syntax.
## @details
## Normalizes spaces, tabs, carriage returns, and newlines around parser tokens.
##
## @param value Text to trim.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns The trimmed text.
function trim(value) {
    sub(/^[ \t\r\n]+/, "", value)
    sub(/[ \t\r\n]+$/, "", value)
    return value
}

## @fn emit_blank()
## @brief Emits one placeholder line when source-line preservation is enabled.
## @details
## Default mode preserves ignored source lines with blank output.  Compact mode
## suppresses those placeholders.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Writes one blank line when compact mode is disabled.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns No meaningful value; callers use the function for output.
function emit_blank() {
    if (keep_blanks) {
        print ""
    }
}

## @fn warn(message)
## @brief Emits one filter diagnostic.
## @details
## Prefixes the supplied message with the current source file and record number.
## The implementation writes to `/dev/stderr`, which assumes a Unix-like host.
##
## @param message Diagnostic message without source-location prefix.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Writes one source-located warning line.
##
## @returns No meaningful value; callers use the function for its side effect.
function warn(message) {
    print FILENAME ":" FNR ": warning: " message > "/dev/stderr"
    warning_count++
}

## @fn fail_or_warn(message)
## @brief Records a diagnostic and marks strict-mode failure when enabled.
## @details
## Normal mode reports the warning while allowing translation to continue.
## Strict mode additionally records a failure that causes a non-zero process
## status from the END rule.
##
## @param message Diagnostic message without source-location prefix.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Writes one source-located warning line.
##
## @returns No meaningful value; callers use the function for its side effect.
function fail_or_warn(message) {
    warn(message)
    if (strict) {
        error_count++
    }
}

## @fn is_blank(line)
## @brief Determines whether a source line contains only horizontal whitespace.
## @details
## Used to distinguish separators from executable or documentation content.
##
## @param line Source line to inspect.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 The line is blank.
## @retval 0 The line contains non-whitespace content.
function is_blank(line) {
    return (line ~ /^[ \t]*$/)
}

## @fn is_comment_only(line)
## @brief Determines whether a source line contains only an AWK comment.
## @details
## Leading horizontal whitespace is accepted.  While a documented function is
## waiting for its opening brace, comment-only lines are treated as intervening
## newlines rather than as new documentation blocks.
##
## @param line Source line to inspect.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 The line contains only a comment.
## @retval 0 The line contains non-comment source content.
function is_comment_only(line) {
    return (line ~ /^[ \t]*#/)
}

## @fn is_open_brace_line(line)
## @brief Determines whether a source line is an opening function brace.
## @details
## Accepts horizontal whitespace and an optional trailing AWK comment around a
## brace that otherwise occupies the line by itself.
##
## @param line Source line to inspect.
## @local source Mutable copy used while removing comments and whitespace.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 The line is a standalone opening brace.
## @retval 0 The line contains other source content.
function is_open_brace_line(line,    source) {
    source = line
    sub(/[ \t]*#.*/, "", source)
    source = trim(source)
    return (source == "{")
}

## @fn is_doc_line(line)
## @brief Determines whether a source line uses the maintained `##` dialect.
## @details
## Leading indentation is accepted, but documentation still begins with exactly
## two hash characters followed by whitespace or end of line.
##
## @param line Source line to inspect.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 The line is a Doxygen documentation line.
## @retval 0 The line is not a Doxygen documentation line.
function is_doc_line(line) {
    return (line ~ /^[ \t]*##([ \t]|$)/)
}

## @fn strip_doc_marker(line)
## @brief Removes the maintained `##` documentation marker from one source line.
## @details
## Preserves the documentation content after the marker for later structural
## parsing and Doxygen emission.
##
## @param line Documentation source line.
## @local value Mutable copy of the source line.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns Documentation content without indentation or the leading marker.
function strip_doc_marker(line,    value) {
    value = line
    sub(/^[ \t]*##[ \t]?/, "", value)
    return value
}

## @fn parse_doc_symbol(meta, directive)
## @brief Extracts the documented identity from a structural Doxygen directive.
## @details
## Removes the directive token, surrounding whitespace, and any parenthesized
## function signature so source `@fn name(args)` resolves to `name`.  A
## structural directive with no identity resolves to the empty string.
##
## @param meta Trimmed documentation line.
## @param directive Structural directive such as `@fn`, `@var`, or `@rule`.
## @local value Mutable text used while extracting the symbol.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns The documented symbol name, or the empty string when absent.
function parse_doc_symbol(meta, directive,    value) {
    value = meta
    sub("^" directive "([ \t]+|$)", "", value)
    value = trim(value)
    sub(/[ \t].*$/, "", value)
    sub(/\(.*/, "", value)
    return value
}

## @fn is_valid_identifier(name)
## @brief Determines whether a name is a portable AWK identifier.
## @details
## Applies the identifier boundary governed by ADR-006 for documented globals.
## The same lexical shape is also used by the function parser.
##
## @param name Candidate identifier.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 The name is a valid portable AWK identifier.
## @retval 0 The name is empty or contains unsupported characters.
function is_valid_identifier(name) {
    return (name ~ /^[A-Za-z_][A-Za-z0-9_]*$/)
}

## @fn is_valid_rule_identity(name)
## @brief Determines whether an @rule identity maps safely to generated C++.
## @details
## Applies ADR-007's tooling-safe lexical form.  The accepted spelling matches
## portable AWK identifiers for lossless translation, but a rule identity remains
## documentation metadata rather than an AWK source identifier.
##
## @param name Candidate rule identity.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 The identity can be embedded in a generated C++ identifier.
## @retval 0 The identity is empty or contains unsupported characters.
function is_valid_rule_identity(name) {
    return (name ~ /^[A-Za-z_][A-Za-z0-9_]*$/)
}

## @fn parse_formal_name(meta, directive)
## @brief Extracts a formal name from an `@param` or `@local` line.
## @details
## Captures only the first token after the structural directive; descriptive
## prose remains in the buffered documentation line.
##
## @param meta Trimmed documentation line.
## @param directive Either `@param` or `@local`.
## @local value Mutable text used while extracting the name.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns The documented formal name, or the empty string when absent.
function parse_formal_name(meta, directive,    value) {
    value = meta
    sub("^" directive "[ \t]+", "", value)
    value = trim(value)
    sub(/[ \t].*$/, "", value)
    return value
}

## @fn add_doc_line(line)
## @brief Buffers one documentation line and records structural metadata.
## @details
## Recognizes `@file`, `@fn`, `@param`, `@local`, `@var`, and `@rule` for
## implemented behavior.
##
## @param line Documentation source line.
## @local content Documentation content without the `##` marker.
## @local meta Trimmed content used for structural recognition.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns No meaningful value; callers use the function for state changes.
function add_doc_line(line,    content, meta) {
    content = strip_doc_marker(line)
    doc_lines[++doc_count] = content
    meta = trim(content)

    if (meta ~ /^@file([ \t]|$)/) {
        if (doc_kind == "") {
            doc_kind = "file"
        }
    } else if (meta ~ /^@fn[ \t]+/) {
        doc_kind = "fn"
        doc_name = parse_doc_symbol(meta, "@fn")
    } else if (meta ~ /^@var([ \t]|$)/) {
        doc_kind = "var"
        doc_name = parse_doc_symbol(meta, "@var")
    } else if (meta ~ /^@rule([ \t]|$)/) {
        doc_kind = "rule"
        doc_name = parse_doc_symbol(meta, "@rule")
    } else if (meta ~ /^@param[ \t]+/) {
        formal_doc_count++
        formal_doc_names[formal_doc_count] = parse_formal_name(meta, "@param")
        formal_doc_kinds[formal_doc_count] = "param"
        formal_doc_lines[formal_doc_count] = doc_count
    } else if (meta ~ /^@local[ \t]+/) {
        formal_doc_count++
        formal_doc_names[formal_doc_count] = parse_formal_name(meta, "@local")
        formal_doc_kinds[formal_doc_count] = "local"
        formal_doc_lines[formal_doc_count] = doc_count
    }
}

## @fn parse_function_decl(line, info)
## @brief Parses the governed portable AWK function declaration forms.
## @details
## Accepts a complete parenthesized formal list on one physical line.  The
## opening brace may appear on that same line or on a later line after only
## newline/comment-only separators, matching the portable AWK grammar.  Newlines
## within the formal list are intentionally outside this parser boundary.
## Stores the function name, formal count, declaration-order names, and whether
## the opening brace is present or pending in the supplied metadata array.
##
## @param line Source line that may contain an AWK function declaration.
## @param info Array populated with parsed declaration metadata.
## @local source Mutable copy of the declaration.
## @local name Parsed AWK function name.
## @local open_pos Position of the opening parenthesis.
## @local close_pos Position of the closing parenthesis.
## @local params Raw formal-parameter text.
## @local tail Text following the closing parenthesis.
## @local count Number of parsed formal parameters.
## @local idx Current formal index.
## @local formal Current formal name.
## @local parts Scratch array populated by `split()`.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 The line is a recognized function declaration or function header.
## @retval 0 The line is outside the governed declaration forms.
function parse_function_decl(line, info,    source, name, open_pos, close_pos, params, tail, count, idx, formal, parts) {
    clear_array(info)
    source = line
    sub(/[ \t]*#.*/, "", source)
    source = trim(source)

    if (source !~ /^function[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/) {
        return 0
    }

    sub(/^function[ \t]+/, "", source)
    name = source
    sub(/[ \t]*\(.*/, "", name)
    if (name !~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
        return 0
    }

    open_pos = index(source, "(")
    close_pos = index(source, ")")
    if (open_pos == 0 || close_pos < open_pos) {
        return 0
    }

    tail = trim(substr(source, close_pos + 1))
    if (tail == "{") {
        info["brace"] = "same"
    } else if (tail == "") {
        info["brace"] = "pending"
    } else {
        return 0
    }

    params = trim(substr(source, open_pos + 1, close_pos - open_pos - 1))
    info["name"] = name
    info["count"] = 0

    if (params == "") {
        return 1
    }

    count = split(params, parts, /,/)
    for (idx = 1; idx <= count; idx++) {
        formal = trim(parts[idx])
        if (formal !~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
            clear_array(info)
            return 0
        }
        info["formal:" idx] = formal
    }
    info["count"] = count
    return 1
}

## @fn parse_rule_header(line, info)
## @brief Recognizes the governed action-bearing AWK rule-header forms.
## @details
## Classifies BEGIN, END, ordinary pattern/action, and action-only rules without
## parsing the pattern expression.  The opening action brace must be the final
## non-whitespace token on the physical header line.  Pattern-only rules remain
## outside the ADR-007 implementation boundary.
##
## @param line Source line that may contain an AWK rule header.
## @param info Array populated with the recognized rule kind.
## @local source Trimmed copy of the source line.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 The line is a recognized action-bearing rule header.
## @retval 0 The line is outside the governed rule-header forms.
function parse_rule_header(line, info,    source) {
    clear_array(info)
    source = trim(line)

    if (source ~ /^function[ \t]+/) {
        return 0
    }

    if (source ~ /^BEGIN([ \t]|$)/) {
        if (source ~ /^BEGIN[ \t]*[{][ \t]*$/) {
            info["kind"] = "begin"
            return 1
        }
        return 0
    }

    if (source ~ /^END([ \t]|$)/) {
        if (source ~ /^END[ \t]*[{][ \t]*$/) {
            info["kind"] = "end"
            return 1
        }
        return 0
    }

    if (source == "{") {
        info["kind"] = "rule"
        return 1
    }

    if (source ~ /[{][ \t]*$/) {
        info["kind"] = "rule"
        return 1
    }

    return 0
}

## @fn docs_are_file_only()
## @brief Determines whether the current buffer is a standalone file block.
## @details
## File documentation is emitted without requiring a following function
## declaration.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 The buffer contains a file documentation block.
## @retval 0 The buffer is not a file-only block.
function docs_are_file_only() {
    return (doc_count > 0 && doc_kind == "file")
}

## @fn docs_are_var_only()
## @brief Determines whether the current buffer is a standalone global block.
## @details
## A `@var` block is authoritative documentation under ADR-006 and does not
## require a following AWK assignment or declaration.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 The buffer contains a documented global variable or array.
## @retval 0 The buffer is not a standalone `@var` block.
function docs_are_var_only() {
    return (doc_count > 0 && doc_kind == "var")
}

## @fn emit_doc_lines(suppress_structural)
## @brief Emits buffered documentation as line-oriented Doxygen comments.
## @details
## Preserves one output line per source documentation line in default mode.
## Source `@fn`, `@local`, and `@rule` directives are structural metadata and
## are suppressed from Doxygen where the generated declaration is authoritative;
## blank placeholders preserve their line positions when compact mode is off.
##
## @param suppress_structural Whether source-only directives are suppressed.
## @local idx Current documentation-line index.
## @local line Buffered documentation content.
## @local meta Trimmed content used to identify structural directives.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Writes translated Doxygen line comments and optional blank placeholders.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns No meaningful value; callers use the function for output.
function emit_doc_lines(suppress_structural,    idx, line, meta) {
    for (idx = 1; idx <= doc_count; idx++) {
        line = doc_lines[idx]
        meta = trim(line)
        if (suppress_structural &&
            (meta ~ /^@fn([ \t]|$)/ || meta ~ /^@local([ \t]|$)/ ||
             meta ~ /^@var([ \t]|$)/ || meta ~ /^@rule([ \t]|$)/)) {
            emit_blank()
        } else if (line == "") {
            print "///"
        } else {
            print "/// " line
        }
    }
}

## @fn emit_var_docs()
## @brief Emits one documented AWK global as a Doxygen structural variable.
## @details
## Rewrites the maintained `@var name` line to `@var AwkValue name` so Doxygen
## receives an explicit pseudo-declaration without requiring an AWK assignment.
## The generic pseudo-type makes no scalar-versus-array claim.  Invalid names are
## diagnosed and replaced by an inline Doxygen warning so default-mode line
## correspondence remains intact.
##
## @local idx Current documentation-line index.
## @local line Buffered documentation content.
## @local meta Trimmed content used to locate the structural `@var` directive.
## @local valid Numeric flag indicating whether the documented name is valid.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Writes the translated variable documentation one source line at a time.
## @par STDERR
## Writes a diagnostic when the documented variable identity is invalid.
##
## @returns No meaningful value; callers use the function for output.
function emit_var_docs(    idx, line, meta, valid) {
    valid = is_valid_identifier(doc_name)
    if (!valid) {
        if (doc_name == "") {
            fail_or_warn("invalid @var name")
        } else {
            fail_or_warn("invalid @var name " doc_name)
        }
    }

    for (idx = 1; idx <= doc_count; idx++) {
        line = doc_lines[idx]
        meta = trim(line)
        if (meta ~ /^@var([ \t]|$)/) {
            if (valid) {
                print "/// @var AwkValue " doc_name
            } else {
                print "/// @warning Invalid @var declaration was not emitted."
            }
        } else if (line == "") {
            print "///"
        } else {
            print "/// " line
        }
    }
}

## @fn build_rule_symbol(info, identity)
## @brief Builds the generated file-local symbol for a documented AWK rule.
## @details
## Uses ADR-007's distinct BEGIN, END, and ordinary-rule prefixes.  The returned
## name is generated pseudo-C++ vocabulary and is not an AWK source identifier.
##
## @param info Parsed rule metadata from `parse_rule_header()`.
## @param identity Maintained `@rule` documentation identity.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns The synthetic C++ identifier used for Doxygen indexing.
function build_rule_symbol(info, identity) {
    if (info["kind"] == "begin") {
        return "awk_doxygen_begin_" identity
    }
    if (info["kind"] == "end") {
        return "awk_doxygen_end_" identity
    }
    return "awk_doxygen_rule_" identity
}

## @fn emit_rule(info)
## @brief Emits one documented AWK rule as a file-local synthetic function.
## @details
## Suppresses source `@rule` metadata and emits the ADR-007 `static void`
## declaration on the real AWK rule-header line.  Invalid identities are
## diagnosed and replaced by an inline Doxygen warning so line correspondence
## remains intact.
##
## @param info Parsed rule metadata from `parse_rule_header()`.
## @local valid Numeric flag indicating whether the rule identity is valid.
## @local symbol Generated file-local pseudo-C++ function name.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Writes translated rule documentation and one synthetic declaration.
## @par STDERR
## Writes a diagnostic when the documented rule identity is invalid.
##
## @returns No meaningful value; callers use the function for output.
function emit_rule(info,    valid, symbol) {
    valid = is_valid_rule_identity(doc_name)
    if (!valid) {
        if (doc_name == "") {
            fail_or_warn("invalid @rule identity")
        } else {
            fail_or_warn("invalid @rule identity " doc_name)
        }
    }

    emit_doc_lines(1)

    if (valid) {
        symbol = build_rule_symbol(info, doc_name)
        print "static void " symbol "();"
    } else {
        print "/// @warning Invalid @rule declaration was not emitted."
    }
}

## @fn validate_function_docs(info)
## @brief Validates formal documentation against a parsed AWK declaration.
## @details
## Requires every declared formal to be classified exactly once as `@param` or
## `@local`, requires documentation order to match declaration order, and
## prevents a public parameter from appearing after a conventional local.
## Reports all observed drift so strict mode can reject the translation.
##
## @param info Parsed function metadata from `parse_function_decl()`.
## @local idx Current declaration or documentation index.
## @local name Current formal name.
## @local kind Current documentation classification.
## @local expected Expected declaration-order name.
## @local seen_local Numeric flag set after the first documented local.
## @local seen Scratch map of documented formal names.
## @local documented Scratch map from formal name to `param` or `local`.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Writes diagnostics for documentation drift.
##
## @returns No meaningful value; callers use the function for validation.
function validate_function_docs(info,    idx, name, kind, expected, seen_local, seen, documented) {
    clear_array(seen)
    clear_array(documented)
    seen_local = 0

    for (idx = 1; idx <= formal_doc_count; idx++) {
        name = formal_doc_names[idx]
        kind = formal_doc_kinds[idx]

        if (name == "" || name !~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
            fail_or_warn("invalid @" kind " formal name")
            continue
        }
        if (seen[name]) {
            fail_or_warn("formal " name " is documented more than once")
            continue
        }
        seen[name] = 1
        documented[name] = kind

        if (kind == "local") {
            seen_local = 1
        } else if (seen_local) {
            fail_or_warn("@param " name " appears after a documented @local")
        }

        if (formal_exists(info, name) && idx <= info["count"]) {
            expected = info["formal:" idx]
            if (name != expected) {
                fail_or_warn("documented formal order expects " expected " but found " name)
            }
        }
    }

    for (idx = 1; idx <= formal_doc_count; idx++) {
        name = formal_doc_names[idx]
        if (name != "" && !formal_exists(info, name)) {
            fail_or_warn("documented formal " name " is not declared by function " info["name"])
        }
    }

    for (idx = 1; idx <= info["count"]; idx++) {
        name = info["formal:" idx]
        if (!(name in documented)) {
            fail_or_warn("formal " name " is not documented as @param or @local")
        }
    }
}

## @fn formal_exists(info, name)
## @brief Determines whether a parsed declaration contains a named formal.
## @details
## Searches declaration-order metadata populated by `parse_function_decl()`.
##
## @param info Parsed function metadata.
## @param name Formal name to locate.
## @local idx Current formal index.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 The declaration contains the named formal.
## @retval 0 The declaration does not contain the named formal.
function formal_exists(info, name,    idx) {
    for (idx = 1; idx <= info["count"]; idx++) {
        if (info["formal:" idx] == name) {
            return 1
        }
    }
    return 0
}

## @fn formal_kind(name)
## @brief Returns the documented classification for a formal parameter.
## @details
## Searches the current block's `@param` and `@local` metadata.  Duplicate
## documentation is diagnosed elsewhere; the first matching classification is
## sufficient for generated-signature construction.
##
## @param name Formal name to classify.
## @local idx Current documented-formal index.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns `param`, `local`, or empty text when the formal is undocumented.
function formal_kind(name,    idx) {
    for (idx = 1; idx <= formal_doc_count; idx++) {
        if (formal_doc_names[idx] == name) {
            return formal_doc_kinds[idx]
        }
    }
    return ""
}

## @fn build_public_param_list(info)
## @brief Builds the caller-visible synthetic parameter list for Doxygen.
## @details
## Walks the AWK declaration in source order and includes only formals whose
## maintained documentation classifies them as `@param`.
##
## @param info Parsed function metadata.
## @local idx Current declaration-order formal index.
## @local name Current formal name.
## @local joined Accumulated pseudo-C++ parameter list.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Nothing is written to STDOUT.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A comma-separated list of synthetic `AwkValue` parameters.
function build_public_param_list(info,    idx, name, joined) {
    joined = ""
    for (idx = 1; idx <= info["count"]; idx++) {
        name = info["formal:" idx]
        if (formal_kind(name) == "param") {
            if (joined != "") {
                joined = joined ", "
            }
            joined = joined "AwkValue " name
        }
    }
    return joined
}

## @fn emit_function(info)
## @brief Emits one documented AWK function as Doxygen-facing pseudo-C++.
## @details
## Validates source metadata, suppresses source-only structural directives, and
## emits the single authoritative signature required by ADR-003.
##
## @param info Parsed function metadata.
## @local params Synthetic caller-visible parameter list.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Writes translated documentation and one synthetic function declaration.
## @par STDERR
## Writes diagnostics when documentation and source structure disagree.
##
## @returns No meaningful value; callers use the function for output.
function emit_function(info,    params) {
    validate_function_docs(info)
    params = build_public_param_list(info)
    emit_doc_lines(1)
    print "AwkValue " info["name"] "(" params ");"
}

## @fn flush_file_docs()
## @brief Emits a standalone file documentation block when one is buffered.
## @details
## File-level documentation does not require a following function declaration.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Writes the buffered file documentation as Doxygen line comments.
## @par STDERR
## Nothing is written to STDERR.
##
## @returns A numeric truth value.
## @retval 1 File documentation was emitted and the buffer was reset.
## @retval 0 The current buffer was not file documentation.
function flush_file_docs() {
    if (docs_are_file_only()) {
        emit_doc_lines(0)
        reset_doc()
        return 1
    }
    return 0
}

## @fn flush_var_docs()
## @brief Emits a standalone documented global variable or array block.
## @details
## `@var` is authoritative under ADR-006, so the block is translated when it
## ends rather than waiting for an AWK assignment or other declaration anchor.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Writes the buffered variable documentation as Doxygen line comments.
## @par STDERR
## Writes a diagnostic when the documented variable name is invalid.
##
## @returns A numeric truth value.
## @retval 1 Variable documentation was emitted and the buffer was reset.
## @retval 0 The current buffer was not a standalone `@var` block.
function flush_var_docs() {
    if (docs_are_var_only()) {
        emit_var_docs()
        reset_doc()
        return 1
    }
    return 0
}

## @fn flush_unmatched_docs(reason)
## @brief Reports documentation that could not be associated with a construct.
## @details
## Preserves the source documentation for downstream visibility and appends a
## generated Doxygen warning explaining that no governed AWK construct was
## associated with the block.
##
## @param reason Diagnostic reason reported by the filter.
##
## @par STDIN
## Nothing is read directly from STDIN.
## @par STDOUT
## Writes unmatched documentation and one generated Doxygen warning line.
## @par STDERR
## Writes the filter diagnostic.
##
## @returns No meaningful value; callers use the function for its side effects.
function flush_unmatched_docs(reason) {
    if (doc_count > 0) {
        if (reason != "") {
            fail_or_warn(reason)
        }
        emit_doc_lines(1)
        print "/// @warning No recognized AWK construct was associated with this documentation block."
        reset_doc()
    }
}

## @rule translate_source_record
## @brief Translates one AWK source record into the Doxygen-facing stream.
## @details
## Owns the top-level documentation association state machine.  It resolves
## pending function braces, standalone file/global blocks, documented functions,
## and supported documented rules while leaving ordinary source as blank output.
##
## @par STDIN
## Processes the current AWK source record supplied by the AWK execution engine.
## @par STDOUT
## Writes translated documentation, declarations, or blank placeholders.
## @par STDERR
## Writes diagnostics through helper functions when documentation drifts.
{
    source_line = $0

    if (pending_function) {
        if (is_blank(source_line) || is_comment_only(source_line)) {
            pending_gap_count++
            next
        }

        if (is_open_brace_line(source_line)) {
            emit_function(function_info)
            for (pending_index = 0; pending_index <= pending_gap_count; pending_index++) {
                emit_blank()
            }
            clear_array(function_info)
            reset_doc()
            pending_function = 0
            pending_gap_count = 0
            next
        }

        flush_unmatched_docs("function declaration " function_info["name"] " was not followed by an opening brace")
        for (pending_index = 0; pending_index <= pending_gap_count; pending_index++) {
            emit_blank()
        }
        clear_array(function_info)
        pending_function = 0
        pending_gap_count = 0
    }

    if (is_doc_line(source_line)) {
        add_doc_line(source_line)
        next
    }

    if (doc_count > 0) {
        if (is_blank(source_line)) {
            if (flush_file_docs() || flush_var_docs()) {
                emit_blank()
                next
            }
            if (doc_kind == "rule") {
                flush_unmatched_docs("documentation block was separated from its AWK rule header")
            } else {
                flush_unmatched_docs("documentation block was separated from its function declaration")
            }
            emit_blank()
            next
        }

        if (flush_file_docs() || flush_var_docs()) {
            emit_blank()
            next
        }

        if (doc_kind == "" || doc_kind == "fn") {
            if (parse_function_decl(source_line, function_info)) {
                if (doc_name != "" && doc_name != function_info["name"]) {
                    fail_or_warn("@fn documents " doc_name " but declaration is " function_info["name"])
                }

                if (function_info["brace"] == "same") {
                    emit_function(function_info)
                    clear_array(function_info)
                    reset_doc()
                } else {
                    pending_function = 1
                    pending_gap_count = 0
                }
                next
            }
        } else if (doc_kind == "rule") {
            if (parse_rule_header(source_line, rule_info)) {
                emit_rule(rule_info)
                clear_array(rule_info)
                reset_doc()
                next
            }

            flush_unmatched_docs("documentation block was not followed by a recognized action-bearing AWK rule header")
            emit_blank()
            next
        } else {
            flush_unmatched_docs("@" doc_kind " documentation is not supported by this implementation")
            emit_blank()
            next
        }

        flush_unmatched_docs("documentation block was not followed by a recognized AWK function declaration")
    }

    emit_blank()
}

## @rule finalize_filter
## @brief Flushes pending documentation and resolves strict-mode status.
## @details
## Handles incomplete deferred functions and documentation buffered at end of
## input, then exits non-zero when strict mode observed documentation warnings.
##
## @par STDIN
## Nothing is read directly from STDIN by this rule.
## @par STDOUT
## May write final buffered documentation and blank placeholders.
## @par STDERR
## May write final diagnostics through helper functions.
END {
    if (pending_function) {
        flush_unmatched_docs("function declaration " function_info["name"] " reached end of file before an opening brace")
        for (pending_index = 0; pending_index <= pending_gap_count; pending_index++) {
            emit_blank()
        }
        clear_array(function_info)
        pending_function = 0
        pending_gap_count = 0
    }

    if (doc_count > 0) {
        if (!flush_file_docs() && !flush_var_docs()) {
            if (doc_kind == "rule") {
                flush_unmatched_docs("@rule documentation reached end of file without a recognized action-bearing AWK rule header")
            } else {
                flush_unmatched_docs("documentation block reached end of file without a recognized AWK construct")
            }
        }
    }

    if (strict && (warning_count > 0 || error_count > 0)) {
        exit 1
    }
}
