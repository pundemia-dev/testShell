# Configuration reference

Every page below documents one `Config.*` namespace as exposed in
`~/.config/pShell/shell.json` and backed by a `*Config.qml` schema
under [`../../config/`](../../config/).

Convention: the markdown filename matches the config namespace
(`Config.backgrounds` → `backgrounds.md`).

## Pages

- [`backgrounds.md`](./backgrounds.md) — `Config.backgrounds`:
  rails-system geometry (rounding, margins, paddings) and the
  per-wrapper **fade-aura** halo.

## Conventions used across these pages

Each page covers, in order:

1. **Properties at a glance** — single table listing every option,
   type, default, and which section discusses it. Skim here first.
2. **One section per logical group** — geometry, theming,
   behaviour, etc. Each property gets:
   - one-line summary
   - default value
   - effect description
   - small comparison table for tunable scalars when useful
3. **Implementation pointers** — where the relevant QML / C++
   lives, so a reader can jump from docs to source.

When adding a new page, mirror this structure so navigation stays
predictable. Cross-link related options by Markdown reference.
