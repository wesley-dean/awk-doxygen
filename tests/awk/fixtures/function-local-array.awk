## @fn field_count(line)
## @brief Counts comma-delimited fields.
## @param line Input line.
## @local parts Scratch array populated by split().
## @returns The number of fields.
function field_count(line,    parts) {
    return split(line, parts, ",")
}
