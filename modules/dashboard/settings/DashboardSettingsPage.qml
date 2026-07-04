pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.modules.dashboard.content as Dash
import QtQuick
import QtQuick.Layouts
import qs.components.containers

// Config.dashboard → modules/dashboard/config/DashboardConfig.qml
// Lets the user enable/disable the whole dashboard, choose its anchor, and
// enable/disable + reorder the modular pages (drag rows by the grip handle).
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Discovers the same page manifests the dashboard itself renders.
    Dash.DashboardRegistry {
        id: registry
    }

    // Map id → manifest (for title/icon in the reorder list).
    readonly property var manifestById: {
        const m = ({});
        for (const p of registry.all ?? [])
            m[p.id] = p;
        return m;
    }

    // All page ids in effective display order (known-order first, unknown
    // appended by manifest.order). Includes disabled pages (settings shows all).
    readonly property var orderedIds: {
        const all = (registry.all ?? []).slice().sort((a, b) => a.order - b.order || a.title.localeCompare(b.title));
        const allIds = all.map(p => p.id);
        const order = (Config.dashboard.order ?? []).filter(id => allIds.includes(id));
        const rest = allIds.filter(id => !order.includes(id));
        return order.concat(rest);
    }

    function pageEnabled(id: string): bool {
        return !(Config.dashboard.disabled ?? []).includes(id);
    }
    function setPageEnabled(id: string, on: bool): void {
        const d = (Config.dashboard.disabled ?? []).slice();
        const i = d.indexOf(id);
        if (on && i >= 0)
            d.splice(i, 1);
        else if (!on && i < 0)
            d.push(id);
        Config.dashboard.disabled = d;
    }

    // ── Anchor helpers ─────────────────────────────────────────────
    readonly property string currentEdge: {
        const a = Config.dashboard.anchors;
        if (a.top) return "top";
        if (a.bottom) return "bottom";
        if (a.left) return "left";
        if (a.right) return "right";
        return "top";
    }
    function setEdge(edge: string): void {
        const a = Config.dashboard.anchors;
        a.top = edge === "top";
        a.bottom = edge === "bottom";
        a.left = edge === "left";
        a.right = edge === "right";
        a.horizontalCenter = edge === "top" || edge === "bottom";
        a.verticalCenter = edge === "left" || edge === "right";
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("Dashboard")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("General")
            icon: "\uea87" // tabler dashboard

            SettingRow {
                label: qsTr("Enabled")
                description: qsTr("Master toggle for the hover dashboard.")
                StyledSwitch {
                    checked: Config.dashboard.enabled
                    onToggled: Config.dashboard.enabled = checked
                }
            }

            SettingRow {
                label: qsTr("Padding")
                description: qsTr("Inner padding around the content, in pixels.")
                CustomSpinBox {
                    value: Config.dashboard.padding
                    min: 0
                    max: 60
                    onValueModified: v => Config.dashboard.padding = v
                }
            }

            SettingRow {
                label: qsTr("Rounding")
                description: qsTr("Corner radius (-1 = follow backgrounds).")
                CustomSpinBox {
                    value: Config.dashboard.rounding
                    min: -1
                    max: 80
                    onValueModified: v => Config.dashboard.rounding = v
                }
            }

            SettingRow {
                label: qsTr("Auto-hide delay")
                description: qsTr("Milliseconds before the panel closes after the cursor leaves.")
                showSeparator: false
                advanced: true
                CustomSpinBox {
                    value: Config.dashboard.autoHideMs
                    min: 0
                    max: 5000
                    step: 50
                    onValueModified: v => Config.dashboard.autoHideMs = v
                }
            }
        }

        SettingSection {
            title: qsTr("Position")
            icon: "\uea87"

            SettingRow {
                label: qsTr("Anchor edge")
                description: qsTr("Which screen edge the dashboard drops from.")
                showSeparator: false

                RowLayout {
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: [
                            { key: "top", label: qsTr("Top") },
                            { key: "bottom", label: qsTr("Bottom") },
                            { key: "left", label: qsTr("Left") },
                            { key: "right", label: qsTr("Right") }
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
        }

        // ── Pages: enable/disable + drag to reorder ────────────────
        SettingSection {
            title: qsTr("Pages")
            icon: "\uea87"

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Toggle pages on/off and drag the grip to reorder tabs.")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.on_surface_variant
                wrapMode: Text.WordWrap
            }

            // Reorder list. Rows are absolutely positioned by their slot in
            // `work`; the dragged row follows the cursor and, as it crosses a
            // slot boundary, we array-move it in `work` so neighbours animate
            // out of the way. On release we persist Config.dashboard.order.
            Item {
                id: reorder
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.small

                readonly property int rowH: 48
                property var work: root.orderedIds
                property bool dragging: false

                // Stable identity list — one delegate per page, created once.
                // The Repeater must NOT model `work`: reassigning `work`
                // mid-drag would rebuild every delegate and kill the active
                // drag (the grip's MouseArea dies with its row, so release —
                // and the Config.dashboard.order write — never happens).
                // Reordering only moves rows through their `slot` binding.
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
                        id: row

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
                            enabled: !row.held
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
                                    drag.target: row
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: 0
                                    drag.maximumY: (reorder.work.length - 1) * reorder.rowH
                                    onPressed: {
                                        row.held = true;
                                        reorder.dragging = true;
                                    }
                                    onReleased: {
                                        row.held = false;
                                        reorder.dragging = false;
                                        row.y = Qt.binding(() => row.slot * reorder.rowH);
                                        Config.dashboard.order = reorder.work.slice();
                                    }
                                }
                            }

                            StyledText {
                                text: row.manifest?.icon ?? ""
                                font.family: Appearance.font.family.tabler
                                font.pointSize: Appearance.font.size.large
                                color: Colours.palette.on_surface
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: row.manifest?.title ?? row.modelData
                                font.pointSize: Appearance.font.size.normal
                                color: Colours.palette.on_surface
                                elide: Text.ElideRight
                            }

                            StyledSwitch {
                                checked: root.pageEnabled(row.modelData)
                                onToggled: root.setPageEnabled(row.modelData, checked)
                            }
                        }
                    }
                }
            }
        }

        SettingSection {
            title: qsTr("Performance widgets")
            icon: "\uea87"

            SettingRow {
                label: qsTr("CPU")
                StyledSwitch {
                    checked: Config.dashboard.performance.showCpu
                    onToggled: Config.dashboard.performance.showCpu = checked
                }
            }
            SettingRow {
                label: qsTr("GPU")
                StyledSwitch {
                    checked: Config.dashboard.performance.showGpu
                    onToggled: Config.dashboard.performance.showGpu = checked
                }
            }
            SettingRow {
                label: qsTr("Memory")
                StyledSwitch {
                    checked: Config.dashboard.performance.showMemory
                    onToggled: Config.dashboard.performance.showMemory = checked
                }
            }
            SettingRow {
                label: qsTr("Storage")
                StyledSwitch {
                    checked: Config.dashboard.performance.showStorage
                    onToggled: Config.dashboard.performance.showStorage = checked
                }
            }
            SettingRow {
                label: qsTr("Network")
                StyledSwitch {
                    checked: Config.dashboard.performance.showNetwork
                    onToggled: Config.dashboard.performance.showNetwork = checked
                }
            }
            SettingRow {
                label: qsTr("Battery")
                StyledSwitch {
                    checked: Config.dashboard.performance.showBattery
                    onToggled: Config.dashboard.performance.showBattery = checked
                }
            }
            SettingRow {
                label: qsTr("Fahrenheit")
                description: qsTr("Show temperatures in \u00b0F instead of \u00b0C.")
                showSeparator: false
                StyledSwitch {
                    checked: Config.dashboard.performance.useFahrenheit
                    onToggled: Config.dashboard.performance.useFahrenheit = checked
                }
            }
        }

        SettingSection {
            title: qsTr("Weather")
            icon: "\uea87"
            advanced: true

            SettingRow {
                label: qsTr("Location")
                description: qsTr("Empty = auto (IP). Otherwise a city name or \"lat,lon\".")
                StyledTextField {
                    implicitWidth: 160
                    text: Config.dashboard.weatherLocation
                    onEditingFinished: Config.dashboard.weatherLocation = text
                    padding: Appearance.padding.small
                    leftPadding: Appearance.padding.medium
                    rightPadding: Appearance.padding.medium
                    background: StyledRect {
                        radius: Appearance.rounding.small
                        color: Colours.palette.surface_container_high
                    }
                }
            }

            SettingRow {
                label: qsTr("Fahrenheit")
                description: qsTr("Show temperatures in °F instead of °C.")
                showSeparator: false
                StyledSwitch {
                    checked: Config.dashboard.useFahrenheit
                    onToggled: Config.dashboard.useFahrenheit = checked
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
