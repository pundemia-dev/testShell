pragma ComponentBehavior: Bound

import qs.components
import qs.config
import qs.services
import Quickshell
import QtQuick

// The toast stack. A non-interactive ListView over Toaster.toasts via a
// ScriptModel — ScriptModel diffs the array by element identity, so appending a
// toast (Toaster reassigns the array wholesale) only spawns ONE new delegate and
// leaves existing delegates (and their expiry timers) untouched. Each delegate
// owns its lifecycle: an expiry Timer that pauses while hovered (the pShell take
// on caelestia's lock/unlock), click-to-dismiss, and enter/exit/reflow anims.
Item {
    id: root

    // Reported up to the wrapper so hovering the stack blocks nothing here — the
    // wrapper is event-driven off Toaster.toasts.length, not hover — but exposed
    // for symmetry with the other content components.
    property bool panelHovered: false

    implicitWidth: Config.toasts.toastWidth
    implicitHeight: list.contentHeight

    // Animate the stack's height so the rails background shrinks/grows smoothly
    // instead of snapping — and clip the list (below) so a toast mid-exit is cut
    // at the panel edge rather than spilling past the shrinking background.
    Behavior on implicitHeight {
        Anim {}
    }

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        interactive: false
        spacing: Appearance.spacing.small
        cacheBuffer: 0
        reuseItems: false

        model: ScriptModel {
            values: Toaster.toasts
        }

        delegate: MouseArea {
            id: del

            required property var modelData

            width: ListView.view?.width ?? 0
            implicitHeight: card.implicitHeight

            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.panelHovered = true
            onExited: root.panelHovered = false
            onClicked: if (del.modelData)
                Toaster.dismiss(del.modelData.id)

            // Auto-dismiss, paused while hovered (lock-on-hover). Toggling
            // running restarts the full interval, so a hovered toast gets its
            // whole lifetime again once the cursor leaves. Guard against the
            // transient null modelData while ScriptModel is removing a delegate.
            Timer {
                interval: del.modelData?.timeout ?? Config.toasts.defaultTimeout
                running: !del.containsMouse && !!del.modelData
                onTriggered: if (del.modelData)
                    Toaster.dismiss(del.modelData.id)
            }

            ToastItem {
                id: card
                modelData: del.modelData
            }
        }

        add: Transition {
            Anim {
                properties: "opacity"
                from: 0
                to: 1
            }
            Anim {
                properties: "scale"
                from: 0.85
                to: 1
            }
        }

        remove: Transition {
            Anim {
                type: Anim.DefaultEffects
                properties: "opacity"
                to: 0
            }
            Anim {
                properties: "scale"
                to: 0.85
            }
        }

        displaced: Transition {
            Anim {
                properties: "x,y"
            }
        }
    }
}
