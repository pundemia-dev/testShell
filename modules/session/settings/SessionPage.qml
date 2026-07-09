pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.modules.session.content as Session
import QtQuick
import QtQuick.Layouts
import qs.components.containers

// Config.session → modules/session/config/SessionConfig.qml
// Lets the user enable/disable the whole session menu, pick its anchor edge,
// and enable/disable + reorder the modular action buttons (drag rows by the
// grip handle).
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Discovers the same action manifests the menu itself renders.
    Session.SessionRegistry {
        id: registry
    }

    // Map id → manifest (for title/icon in the reorder list).
    readonly property var manifestById: {
        const m = ({});
        for (const p of registry.all ?? [])
            m[p.id] = p;
        return m;
    }

    // All action ids in effective display order (known-order first, unknown
    // appended by manifest.order). Includes disabled buttons (settings shows all).
    readonly property var orderedIds: {
        const all = (registry.all ?? []).slice().sort((a, b) => a.order - b.order || a.title.localeCompare(b.title));
        const allIds = all.map(p => p.id);
        const order = (Config.session.order ?? []).filter(id => allIds.includes(id));
        const rest = allIds.filter(id => !order.includes(id));
        return order.concat(rest);
    }

    function buttonEnabled(id: string): bool {
        return !(Config.session.disabled ?? []).includes(id);
    }
    function setButtonEnabled(id: string, on: bool): void {
        const d = (Config.session.disabled ?? []).slice();
        const i = d.indexOf(id);
        if (on && i >= 0)
            d.splice(i, 1);
        else if (!on && i < 0)
            d.push(id);
        Config.session.disabled = d;
    }

    // ── Anchor helpers ─────────────────────────────────────────────
    readonly property string currentEdge: {
        const a = Config.session.anchors;
        if (a.left) return "left";
        if (a.right) return "right";
        if (a.top) return "top";
        if (a.bottom) return "bottom";
        return "right";
    }
    function setEdge(edge: string): void {
        const a = Config.session.anchors;
        a.left = edge === "left";
        a.right = edge === "right";
        a.top = edge === "top";
        a.bottom = edge === "bottom";
        a.horizontalCenter = edge === "top" || edge === "bottom";
        a.verticalCenter = edge === "left" || edge === "right";
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("Session")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("General")
            icon: "\ueb0d" // tabler power

            SettingRow {
                label: qsTr("Enabled")
                description: qsTr("Master toggle for the session menu.")
                StyledSwitch {
                    checked: Config.session.enabled
                    onToggled: Config.session.enabled = checked
                }
            }

            SettingRow {
                label: qsTr("Button size")
                description: qsTr("Diameter of each action button, in pixels.")
                CustomSpinBox {
                    value: Config.session.buttonSize
                    min: 40
                    max: 160
                    step: 4
                    onValueModified: v => Config.session.buttonSize = v
                }
            }

            SettingRow {
                label: qsTr("Spacing")
                description: qsTr("Gap between buttons, in pixels.")
                CustomSpinBox {
                    value: Config.session.spacing
                    min: 0
                    max: 48
                    onValueModified: v => Config.session.spacing = v
                }
            }

            SettingRow {
                label: qsTr("Padding")
                description: qsTr("Inner padding around the buttons, in pixels.")
                CustomSpinBox {
                    value: Config.session.padding
                    min: 0
                    max: 60
                    onValueModified: v => Config.session.padding = v
                }
            }

            SettingRow {
                label: qsTr("Rounding")
                description: qsTr("Corner radius (-1 = follow backgrounds).")
                CustomSpinBox {
                    value: Config.session.rounding
                    min: -1
                    max: 80
                    onValueModified: v => Config.session.rounding = v
                }
            }

            SettingRow {
                label: qsTr("Vim keybinds")
                description: qsTr("Ctrl+J/K (or N/P) to move between buttons.")
                showSeparator: false
                advanced: true
                StyledSwitch {
                    checked: Config.session.vimKeybinds
                    onToggled: Config.session.vimKeybinds = checked
                }
            }
        }

        SettingSection {
            title: qsTr("Position")
            icon: "\ueb0d" // tabler power

            SettingRow {
                label: qsTr("Anchor edge")
                description: qsTr("Which screen edge the menu pushes in from.")

                RowLayout {
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: [
                            { key: "right", label: qsTr("Right") },
                            { key: "left", label: qsTr("Left") },
                            { key: "top", label: qsTr("Top") },
                            { key: "bottom", label: qsTr("Bottom") }
                        ]

                        delegate: StyledRect {
                            id: edgePill
                            required property var modelData
                            readonly property bool active: root.currentEdge === modelData.key

                            implicitWidth: edgeLabel.implicitWidth + Appearance.padding.medium * 2
                            implicitHeight: edgeLabel.implicitHeight + Appearance.padding.small * 2
                            radius: Appearance.rounding.small
                            color: active ? Colours.palette.secondary_container : Colours.palette.surface_container_high

                            StyledText {
                                id: edgeLabel
                                anchors.centerIn: parent
                                text: edgePill.modelData.label
                                font.pointSize: Appearance.font.size.small
                                color: edgePill.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setEdge(edgePill.modelData.key)
                            }
                        }
                    }
                }
            }

            // Orientation override. "Auto" derives the stack direction from the
            // anchor edge (horizontal on top/bottom or dead-centre, else
            // vertical); the other two force it.
            SplitButtonRow {
                label: qsTr("Orientation")
                active: {
                    const o = Config.session.orientation ?? "auto";
                    return o === "vertical" ? orientVertical
                         : o === "horizontal" ? orientHorizontal
                         : orientAuto;
                }
                menuItems: [orientAuto, orientVertical, orientHorizontal]
                onSelected: item => Config.session.orientation = item.value

                MenuItem { id: orientAuto; text: qsTr("Auto"); value: "auto" }
                MenuItem { id: orientVertical; text: qsTr("Vertical"); value: "vertical" }
                MenuItem { id: orientHorizontal; text: qsTr("Horizontal"); value: "horizontal" }
            }
        }

        // ── Buttons: enable/disable + drag to reorder ──────────────
        SettingSection {
            title: qsTr("Buttons")
            icon: "\ueb0d" // tabler power

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Toggle buttons on/off and drag the grip to reorder them.")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.on_surface_variant
                wrapMode: Text.WordWrap
            }

            // Reorder list. Rows are absolutely positioned by their slot in
            // `work`; the dragged row follows the cursor and, as it crosses a
            // slot boundary, we array-move it in `work` so neighbours animate
            // out of the way. On release we persist Config.session.order.
            Item {
                id: reorder
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.small

                readonly property int rowH: 48
                property var work: root.orderedIds
                property bool dragging: false

                // Stable identity list — one delegate per button, created once.
                // The Repeater must NOT model `work`: reassigning `work`
                // mid-drag would rebuild every delegate and kill the active
                // drag. Reordering only moves rows through their `slot` binding.
                readonly property var stableIds: (registry.all ?? []).map(p => p.id).sort()

                // Re-sync from config unless a drag is mid-flight.
                Connections {
                    target: root
                    function onOrderedIdsChanged() {
                        if (!reorder.dragging)
                            reorder.work = root.orderedIds;
                    }
                }

                implicitHeight: work.length * rowH

                Repeater {
                    model: reorder.stableIds

                    delegate: StyledRect {
                        id: rowItem

                        required property int index
                        required property string modelData
                        readonly property var manifest: root.manifestById[modelData] ?? null
                        readonly property int slot: reorder.work.indexOf(modelData)

                        property bool held: false

                        width: reorder.width
                        height: reorder.rowH - Appearance.spacing.small
                        z: held ? 2 : 1
                        radius: Appearance.rounding.large
                        color: held ? Colours.palette.surface_container_high
                                    : rowHover.containsMouse ? Colours.palette.surface_container
                                    : "transparent"

                        Component.onCompleted: y = Qt.binding(() => slot * reorder.rowH)

                        Behavior on y {
                            enabled: !rowItem.held
                            NumberAnimation {
                                duration: Appearance.anim.durations.small
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.anim.curves.standard
                            }
                        }

                        onYChanged: {
                            if (!held)
                                return;
                            const newSlot = Math.max(0, Math.min(reorder.work.length - 1, Math.round(y / reorder.rowH)));
                            const cur = reorder.work.indexOf(modelData);
                            if (newSlot !== cur) {
                                const w = reorder.work.slice();
                                w.splice(cur, 1);
                                w.splice(newSlot, 0, modelData);
                                reorder.work = w;
                            }
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Appearance.padding.small
                            anchors.rightMargin: Appearance.padding.medium
                            spacing: Appearance.spacing.medium

                            // Grip handle — the only draggable region.
                            StyledText {
                                text: "\uec01" // tabler grip-vertical
                                font.family: Appearance.font.family.tabler
                                font.pointSize: Appearance.font.size.large
                                color: Colours.palette.on_surface_variant

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -Appearance.padding.small
                                    cursorShape: Qt.SizeVerCursor
                                    drag.target: rowItem
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: 0
                                    drag.maximumY: (reorder.work.length - 1) * reorder.rowH
                                    onPressed: {
                                        rowItem.held = true;
                                        reorder.dragging = true;
                                    }
                                    onReleased: {
                                        rowItem.held = false;
                                        reorder.dragging = false;
                                        rowItem.y = Qt.binding(() => rowItem.slot * reorder.rowH);
                                        Config.session.order = reorder.work.slice();
                                    }
                                }
                            }

                            StyledText {
                                text: rowItem.manifest?.icon ?? ""
                                font.family: Appearance.font.family.tabler
                                font.pointSize: Appearance.font.size.large
                                color: Colours.palette.on_surface
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: rowItem.manifest?.title ?? rowItem.modelData
                                font.pointSize: Appearance.font.size.normal
                                color: Colours.palette.on_surface
                                elide: Text.ElideRight
                            }

                            StyledSwitch {
                                checked: root.buttonEnabled(rowItem.modelData)
                                onToggled: root.setButtonEnabled(rowItem.modelData, checked)
                            }
                        }
                    }
                }
            }
        }
    }
}
