pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.utils

// Declarative popout trigger. Drop one inside a bar/dock widget (or any
// sub-element of it) — it tracks its `anchorItem` (the parent by default) and
// opens a popout on the chosen edge while that item is hovered. Multiple
// handles can coexist on one edge: in reuse mode they share the same
// background, which slides + morphs between them. A handle with no content
// (e.g. an empty tray) never opens a popout.
//
//   PopoutHandle {
//       edge: "top"
//       popoutContent: Component { ClockPopout {} }
//       contentReady: model.count > 0     // optional dynamic guard
//   }
//
// Layout-safe: the handle itself is invisible and zero-size (so it never grabs
// a slot in a FlexboxLayout / RowLayout); the HoverHandler is reparented onto
// `anchorItem` and geometry is measured from it. The downward bridge
// (host → popout) is built for free by WindowSlot and lives in the backgrounds
// tree, so a parent's `clip: true` can't eat it.
Item {
    id: handle

    visible: false
    width: 0
    height: 0

    // The widget to track + measure. Defaults to the parent; set explicitly to
    // scope the trigger to a sub-element.
    property Item anchorItem: parent

    // Resolved from the containing Quickshell window — no prop-drilling needed.
    property ShellScreen screen: QsWindow.window?.screen ?? null

    property string edge: "top"

    // The popout UI. Null → this handle is inert (never active).
    property Component popoutContent: null
    // Dynamic content guard: set false to keep a space-occupying-but-empty
    // widget (e.g. tray) from summoning an empty popout.
    property bool contentReady: true

    // Per-handle contract overrides (gap/padding/rounding/mode/...), merged
    // over Config.popouts defaults by EdgeChannel.
    property var overrides: ({})

    // Higher wins when several hovered handles share an edge (e.g. a
    // sub-element handle over its parent's handle). Ties → last-registered.
    property int priority: 0

    readonly property bool hasContent: contentReady && popoutContent !== null

    HoverHandler {
        id: hover
        parent: handle.anchorItem
    }

    // hovering folds in hasContent so an inert handle never registers as active.
    // Suppressed while the bar layout editor is on, so dragging / hovering
    // widgets in edit mode never summons a popout.
    readonly property bool hovering: hover.hovered && handle.hasContent && !BarEditManager.editing
    onHoveringChanged: Popouts.refresh(handle)
    onHasContentChanged: Popouts.refresh(handle)
    onScreenChanged: Popouts.refresh(handle)

    Component.onCompleted: Popouts.register(handle)
    Component.onDestruction: Popouts.unregister(handle)
}
