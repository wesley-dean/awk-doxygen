## @fn validate(value)
## @brief Validates a value.
## @details
## Keeps ordinary Doxygen directives intact.
## @param value Value to validate.
## @note This is a note.
## @warning This is a warning.
## @see other_function()
## @returns A numeric truth value.
## @retval 1 The value is valid.
## @retval 0 The value is invalid.
function validate(value) {
    return (value != "")
}
