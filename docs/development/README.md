# Development docs

Architecture & internals reference (sibling to [`../config/`](../config/) which
targets end-user configuration).

## Index

- [`architecture.md`](./architecture.md) — rendering tree, Rails system, Wrapper
  contract, module system, config schema, services, plugin modules.
- [`key-files.md`](./key-files.md) — task → file(s) lookup table.
- [`border-zones.md`](./border-zones.md) — 8-zone perimeter partition, rail ↔ zone
  mapping, trigger strip geometry, per-zone SDF присасывание (sink + boost +
  frame smin), `sticks` gating + capsule bridge.
- [`interaction-manager.md`](./interaction-manager.md) — global Singleton for
  per-rail hover/slide/drop stacks; registration recipe, conflict resolution,
  strip state.
- [`input-mask.md`](./input-mask.md) — layershell input mask: bridges,
  resize-union holdover, slot envelope (HoverHandler + DropArea),
  `slotRects/slotHover/slotDragOver`.
- [`settings.md`](./settings.md) — settings module: Config plumbing, presets,
  third-party schema contract, hints, basic/advanced split.
