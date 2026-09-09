## @rule comment_lines
## @brief Ignores comment records.
/^[[:space:]]*#/ {
    next
}
