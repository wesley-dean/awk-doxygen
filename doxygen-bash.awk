#!/usr/bin/awk -f
#
# doxygen-bash-docfilter.awk
#
# Documentation-led Doxygen preprocessor for Bash, implemented as a single
# portable awk file.
#
# The filter intentionally documents only symbols with Doxygen-style Bash
# comment blocks.  It is permissive about Bash formatting so author intent is
# not lost because of whitespace, indentation, or a harmless declaration style
# variation.
#
# Supported primary comment style:
#   ## @brief ...
#   ## @details
#   ## ...
#
# Supported documented declarations include:
#   name() {
#   name () {
#   function name() {
#   function name {
#   readonly NAME=value
#   declare -r NAME=value
#   declare -a NAME=(...)
#   declare -A NAME=(...)
#   export NAME=value
#   local NAME=value
#   NAME=value
#   NAME=(...)
#
# This is not a shell parser.  It is a documentation compiler for the subset of
# Bash declarations that can reasonably follow a Doxygen block.

BEGIN {
    strict = (strict ? strict : 0)
    keep_blanks = (compact ? 0 : 1)

    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] == "--strict") {
            strict = 1
            ARGV[i] = ""
        } else if (ARGV[i] == "--compact") {
            keep_blanks = 0
            ARGV[i] = ""
        }
    }

    reset_doc()
}

function reset_doc(    i) {
    doc_count = 0
    doc_kind = ""
    doc_name = ""
    param_count = 0
    delete doc_lines
    delete param_names
    delete param_doc_lines
    delete emitted_param_names
}

function trim(s) {
    sub(/^[ \t\r\n]+/, "", s)
    sub(/[ \t\r\n]+$/, "", s)
    return s
}

function emit_blank() {
    if (keep_blanks) {
        print ""
    }
}

function warn(message) {
    print FILENAME ":" FNR ": warning: " message > "/dev/stderr"
    warning_count++
}

function fail_or_warn(message) {
    warn(message)
    if (strict) {
        error_count++
    }
}

function is_blank(line) {
    return (line ~ /^[ \t]*$/)
}

function is_doc_line(line) {
    return (line ~ /^[ \t]*##([ \t]|$)/)
}

function strip_doc_marker(line,    s) {
    s = line
    sub(/^[ \t]*##[ \t]?/, "", s)
    return s
}

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
    } else if (meta ~ /^@var[ \t]+/) {
        doc_kind = "var"
        doc_name = parse_doc_symbol(meta, "@var")
    } else if (meta ~ /^@param[ \t]+/) {
        param_count++
        param_names[param_count] = parse_param_name(meta)
        param_doc_lines[param_count] = doc_count
    }
}

function parse_doc_symbol(meta, directive,    s) {
    s = meta
    sub("^" directive "[ \t]+", "", s)
    s = trim(s)
    sub(/[ \t].*$/, "", s)
    sub(/\(.*$/, "", s)
    return s
}

function parse_param_name(meta,    s) {
    s = meta
    sub(/^@param[ \t]+/, "", s)
    s = trim(s)
    sub(/[ \t].*$/, "", s)
    return s
}

function sanitize_identifier(name, fallback,    s) {
    s = name
    gsub(/^[.][.][.]/, "", s)
    gsub(/^--/, "", s)
    gsub(/\[\]$/, "", s)
    gsub(/=$/, "", s)
    gsub(/-/, "_", s)
    gsub(/[^A-Za-z0-9_:]/, "_", s)

    if (s == "") {
        s = fallback
    }
    if (s ~ /^[0-9]/) {
        s = "p_" s
    }

    return s
}

function unique_param_name(name,    base, n) {
    base = name
    n = 1
    while (param_seen[name]) {
        n++
        name = base "_" n
    }
    param_seen[name] = 1
    return name
}

function prepare_param_names(    i, clean) {
    delete param_seen
    delete emitted_param_names

    for (i = 1; i <= param_count; i++) {
        clean = sanitize_identifier(param_names[i], "arg")
        emitted_param_names[i] = unique_param_name(clean)
    }
}

function rewrite_param_name(line, old_name, new_name,    pos, tail, name_pos) {
    pos = index(line, "@param")
    if (pos == 0) {
        return line
    }

    tail = substr(line, pos + 6)
    if (!match(tail, /[^ \t]/)) {
        return line
    }

    name_pos = RSTART
    return substr(line, 1, pos + 5) \
           substr(tail, 1, name_pos - 1) \
           new_name \
           substr(tail, name_pos + length(old_name))
}

function rewrite_param_doc_lines(    i, line_number) {
    for (i = 1; i <= param_count; i++) {
        line_number = param_doc_lines[i]
        doc_lines[line_number] = rewrite_param_name(doc_lines[line_number], param_names[i], emitted_param_names[i])
    }
}

function build_param_list(    i, joined) {
    joined = ""

    for (i = 1; i <= param_count; i++) {
        if (joined != "") {
            joined = joined ", "
        }
        joined = joined "String " emitted_param_names[i]
    }

    return joined
}

function emit_doc_block(extra_line, suppress_fn,    i, line, meta) {
    print "/**"
    for (i = 1; i <= doc_count; i++) {
        line = doc_lines[i]
        meta = trim(line)
        if (suppress_fn && meta ~ /^@fn([ \t]|$)/) {
            continue
        }
        if (line == "") {
            print " *"
        } else {
            print " * " line
        }
    }
    if (extra_line != "") {
        print " * " extra_line
    }
    print " */"
}

function normalize_func_decl(line,    s, name) {
    s = line
    sub(/#.*/, "", s)
    s = trim(s)

    if (s ~ /^function[ \t]+/) {
        sub(/^function[ \t]+/, "", s)
    }

    sub(/[ \t]*\{[ \t;]*$/, "", s)
    s = trim(s)
    sub(/[ \t]*\(\)[ \t]*$/, "", s)
    s = trim(s)

    if (s ~ /^[A-Za-z_][A-Za-z0-9_:]*$/) {
        return s
    }

    return ""
}

function is_probable_function_decl(line) {
    return (normalize_func_decl(line) != "") && \
           (line ~ /^[ \t]*(function[ \t]+)?[A-Za-z_][A-Za-z0-9_:]*[ \t]*(\(\))?[ \t]*(\{|$)/)
}

function emit_function(name,    params) {
    prepare_param_names()
    rewrite_param_doc_lines()
    params = build_param_list()
    emit_doc_block("", 1)
    print "int " name "(" params ");"
}

function classify_variable(raw_line, info,    line, prefix, opts, name, value, eqpos, token, rest) {
    delete info
    line = raw_line
    sub(/#.*/, "", line)
    line = trim(line)

    info["storage"] = "global"
    info["readonly"] = "no"
    info["exported"] = "no"
    info["declared"] = "no"
    info["array"] = "scalar"
    info["integer"] = "no"
    info["nameref"] = "no"
    info["case_transform"] = "none"
    info["name"] = ""
    info["type"] = "string"

    if (line ~ /^local([ \t]|$)/) {
        info["storage"] = "local"
        sub(/^local[ \t]+/, "", line)
    } else if (line ~ /^readonly([ \t]|$)/) {
        info["readonly"] = "yes"
        sub(/^readonly[ \t]+/, "", line)
    } else if (line ~ /^export([ \t]|$)/) {
        info["exported"] = "yes"
        sub(/^export[ \t]+/, "", line)
    } else if (line ~ /^(declare|typeset)([ \t]|$)/) {
        info["declared"] = "yes"
        sub(/^(declare|typeset)[ \t]+/, "", line)
    }

    while (line ~ /^-[A-Za-z]+([ \t]|$)/) {
        token = line
        sub(/[ \t].*$/, "", token)
        opts = substr(token, 2)

        if (index(opts, "r")) info["readonly"] = "yes"
        if (index(opts, "x")) info["exported"] = "yes"
        if (index(opts, "a")) info["array"] = "indexed_array"
        if (index(opts, "A")) info["array"] = "associative_array"
        if (index(opts, "i")) info["integer"] = "yes"
        if (index(opts, "n")) info["nameref"] = "yes"
        if (index(opts, "l")) info["case_transform"] = "lowercase"
        if (index(opts, "u")) info["case_transform"] = "uppercase"

        sub(/^-[A-Za-z]+[ \t]*/, "", line)
        line = trim(line)
    }

    if (line == "") {
        return 0
    }

    eqpos = index(line, "=")
    if (eqpos > 0) {
        name = trim(substr(line, 1, eqpos - 1))
        value = trim(substr(line, eqpos + 1))
    } else {
        if (info["declared"] != "yes") {
            return 0
        }
        name = line
        value = ""
    }

    sub(/[ \t].*$/, "", name)
    sub(/^[-+][A-Za-z]+[ \t]+/, "", name)

    if (name !~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
        return 0
    }

    if (info["array"] == "scalar" && value ~ /^\(/) {
        info["array"] = "indexed_array"
    }

    if (info["array"] == "associative_array") {
        info["type"] = "associative_array"
    } else if (info["array"] == "indexed_array") {
        info["type"] = "indexed_array"
    } else if (info["nameref"] == "yes") {
        info["type"] = "nameref"
    } else if (info["integer"] == "yes") {
        info["type"] = "integer"
    } else {
        info["type"] = "string"
    }

    info["name"] = name
    return 1
}

function is_probable_variable_decl(line,    ok) {
    ok = classify_variable(line, tmp_info)
    delete tmp_info
    return ok
}

function variable_meta(info,    meta) {
    meta = "@details Bash variable: "

    if (info["storage"] == "local") {
        meta = meta "local "
    }
    if (info["exported"] == "yes") {
        meta = meta "exported "
    }
    if (info["readonly"] == "yes") {
        meta = meta "readonly "
    } else {
        meta = meta "read-write "
    }

    meta = meta info["type"]

    if (info["case_transform"] == "lowercase") {
        meta = meta " lowercase-transform"
    } else if (info["case_transform"] == "uppercase") {
        meta = meta " uppercase-transform"
    }

    return meta
}

function variable_pseudo_type(info,    type) {
    type = ""

    if (info["storage"] == "local") type = type "Local"
    if (info["exported"] == "yes") type = type "Exported"
    if (info["readonly"] == "yes") type = type "Readonly"

    if (info["type"] == "associative_array") {
        type = type "AssociativeArray"
    } else if (info["type"] == "indexed_array") {
        type = type "IndexedArray"
    } else if (info["type"] == "nameref") {
        type = type "NameReference"
    } else if (info["type"] == "integer") {
        type = type "Integer"
    } else {
        type = type "String"
    }

    return type
}

function emit_variable(info,    type) {
    emit_doc_block(variable_meta(info))
    type = variable_pseudo_type(info)
    print type " " info["name"] ";"
}

function docs_are_file_only() {
    return (doc_count > 0 && doc_kind == "file")
}

function flush_file_docs_if_needed() {
    if (docs_are_file_only()) {
        emit_doc_block("")
        reset_doc()
        return 1
    }
    return 0
}

function flush_unmatched_docs(reason) {
    if (doc_count > 0) {
        if (reason != "") {
            fail_or_warn(reason)
        }
        emit_doc_block("@warning No recognized Bash declaration was associated with this documentation block.")
        reset_doc()
    }
}

{
    line = $0

    if (is_doc_line(line)) {
        add_doc_line(line)
        next
    }

    if (doc_count > 0) {
        if (is_blank(line)) {
            if (flush_file_docs_if_needed()) {
                emit_blank()
            }
            next
        }

        if (flush_file_docs_if_needed()) {
            emit_blank()
        }

        if (doc_count > 0 && is_probable_function_decl(line)) {
            fn_name = normalize_func_decl(line)
            if (doc_kind == "var") {
                fail_or_warn("@var block precedes function declaration " fn_name)
            }
            if (doc_name != "" && doc_name != fn_name) {
                fail_or_warn("@fn documents " doc_name " but declaration is " fn_name)
            }
            emit_function(fn_name)
            reset_doc()
            next
        }

        if (doc_count > 0 && classify_variable(line, var_info)) {
            if (doc_kind == "fn") {
                fail_or_warn("@fn block precedes variable declaration " var_info["name"])
            }
            if (doc_name != "" && doc_name != var_info["name"]) {
                fail_or_warn("@var documents " doc_name " but declaration is " var_info["name"])
            }
            emit_variable(var_info)
            delete var_info
            reset_doc()
            next
        }

        flush_unmatched_docs("documentation block was not followed by a recognized declaration")
    }

    emit_blank()
}

END {
    if (doc_count > 0) {
        flush_unmatched_docs("documentation block reached end of file without a declaration")
    }

    if (strict && (warning_count > 0 || error_count > 0)) {
        exit 1
    }
}
