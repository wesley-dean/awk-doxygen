## @var cache
## @brief Maps normalized keys to cached values.
## @details
## Keys are normalized identifiers; entries persist for the process lifetime.
BEGIN { cache["ready"] = 1 }
