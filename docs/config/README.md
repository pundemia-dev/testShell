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
- [`border.md`](./border.md) — `Config.border`: visible chrome
  + the 8-zone interaction surface + per-zone SDF присасывание
  (`zoneRoundings`).
- [`stash.md`](./stash.md) — `Config.stash`: file tray + LocalSend
  share panel — storage, hover/drag-trigger, three-state view,
  drop-zone chooser, dashed-border styling.

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
