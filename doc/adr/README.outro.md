## Documentation Build

This landing page is generated during every stable and canary documentation
build.  `README.intro.md` and `README.outro.md` are maintained source, while the
linked ADR list between them is produced by the pinned released `adrctl` artifact
from `dependencies-docs.txt`.

The composite `doc/adr/README.md` and Doxygen output under `doc/reference/` are
ignored derivative state.  Dependency acquisition remains explicit through
`make deps-docs`; `make adr-index`, `make docs`, and `make docs-canary` consume
already-prepared documentation dependencies and do not repair them.

Routine documentation generation intentionally includes ADR navigation only.  It
does not add an automatic ADR relationship graph.
