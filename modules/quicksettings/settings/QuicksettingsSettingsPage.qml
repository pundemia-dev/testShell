pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import qs.modules.settings.components
import qs.modules.quicksettings.content as Qs
import QtQuick
import QtQuick.Layouts

// Config.quicksettings → modules/quicksettings/config/QuicksettingsConfig.qml
// Master toggle, geometry, page/card enable+reorder, quick toggles and the
// news feed list.
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Same manifests the panel itself renders.
    Qs.QsRegistry {
        id: pageRegistry
    }
    Qs.QsCardRegistry {
        id: cardRegistry
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("Quicksettings")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("General")
            icon: "" // tabler adjustments

            SettingRow {
                label: qsTr("Enabled")
                description: qsTr("Master toggle for the quicksettings panel.")
                StyledSwitch {
                    checked: Config.quicksettings.enabled
                    onToggled: Config.quicksettings.enabled = checked
                }
            }

            SettingRow {
                label: qsTr("Content width")
                description: qsTr("Panel content width, in pixels.")
                CustomSpinBox {
                    value: Config.quicksettings.contentWidth
                    min: 280
                    max: 800
                    step: 10
                    onValueModified: v => Config.quicksettings.contentWidth = v
                }
            }

            SettingRow {
                label: qsTr("Page height")
                description: qsTr("Fixed height of the tab-page area, in pixels.")
                CustomSpinBox {
                    value: Config.quicksettings.pageHeight
                    min: 200
                    max: 1200
                    step: 10
                    onValueModified: v => Config.quicksettings.pageHeight = v
                }
            }

            SettingRow {
                label: qsTr("Auto-hide delay")
                description: qsTr("Milliseconds before the panel closes after the cursor leaves.")
                showSeparator: false
                advanced: true
                CustomSpinBox {
                    value: Config.quicksettings.autoHideMs
                    min: 0
                    max: 5000
                    step: 50
                    onValueModified: v => Config.quicksettings.autoHideMs = v
                }
            }
        }

        BackgroundCard {
            cfg: Config.quicksettings
        }

        SettingSection {
            title: qsTr("Pages")
            icon: "" // tabler layout-navbar

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Toggle tab pages on/off and drag the grip to reorder tabs.")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.on_surface_variant
                wrapMode: Text.WordWrap
            }

            ReorderList {
                manifests: pageRegistry.all ?? []
                configOrder: Config.quicksettings.order ?? []
                disabledIds: Config.quicksettings.disabled ?? []
                onReordered: ids => Config.quicksettings.order = ids
                onToggled: (id, on) => {
                    const d = (Config.quicksettings.disabled ?? []).slice();
                    const i = d.indexOf(id);
                    if (on && i >= 0)
                        d.splice(i, 1);
                    else if (!on && i < 0)
                        d.push(id);
                    Config.quicksettings.disabled = d;
                }
            }
        }

        SettingSection {
            title: qsTr("Cards")
            icon: "" // tabler cards

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Toggle the cards shown below the tabs and drag to reorder them.")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.on_surface_variant
                wrapMode: Text.WordWrap
            }

            ReorderList {
                manifests: cardRegistry.all ?? []
                configOrder: Config.quicksettings.cardsOrder ?? []
                disabledIds: Config.quicksettings.cardsDisabled ?? []
                onReordered: ids => Config.quicksettings.cardsOrder = ids
                onToggled: (id, on) => {
                    const d = (Config.quicksettings.cardsDisabled ?? []).slice();
                    const i = d.indexOf(id);
                    if (on && i >= 0)
                        d.splice(i, 1);
                    else if (!on && i < 0)
                        d.push(id);
                    Config.quicksettings.cardsDisabled = d;
                }
            }
        }

        SettingSection {
            title: qsTr("Quick toggles")
            icon: "" // tabler toggle-right

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Toggle buttons on/off and drag to reorder them.")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.on_surface_variant
                wrapMode: Text.WordWrap
            }

            ReorderList {
                manifests: [
                    { id: "wifi", title: qsTr("Wi-Fi"), icon: "", order: 0 },
                    { id: "bluetooth", title: qsTr("Bluetooth"), icon: "", order: 1 },
                    { id: "mic", title: qsTr("Microphone"), icon: "", order: 2 },
                    { id: "dnd", title: qsTr("Do not disturb"), icon: "", order: 3 },
                    { id: "settings", title: qsTr("Settings button"), icon: "", order: 4 }
                ]
                configOrder: Config.quicksettings.togglesOrder ?? []
                disabledIds: ["wifi", "bluetooth", "mic", "dnd", "settings"].filter(k => !Config.quicksettings.toggles[k])
                onReordered: ids => Config.quicksettings.togglesOrder = ids
                onToggled: (id, on) => Config.quicksettings.toggles[id] = on
            }
        }

        SettingSection {
            title: qsTr("News")
            icon: "" // tabler news

            StyledText {
                Layout.fillWidth: true
                text: qsTr("RSS/Atom feed URLs for the News page.")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.on_surface_variant
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: Config.quicksettings.newsFeeds

                delegate: RowLayout {
                    id: feedRow

                    required property int index
                    required property string modelData

                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: feedRow.modelData
                        elide: Text.ElideMiddle
                        color: Colours.palette.on_surface_variant
                    }

                    IconButton {
                        icon: "" // tabler trash
                        isRound: true
                        type: IconButton.Text
                        onClicked: {
                            const f = (Config.quicksettings.newsFeeds ?? []).slice();
                            f.splice(feedRow.index, 1);
                            Config.quicksettings.newsFeeds = f;
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledTextField {
                    id: newFeed

                    Layout.fillWidth: true
                    placeholderText: qsTr("https://example.org/feed.xml")
                    padding: Appearance.padding.small
                    leftPadding: Appearance.padding.medium
                    rightPadding: Appearance.padding.medium
                    background: StyledRect {
                        radius: Appearance.rounding.small
                        color: Colours.palette.surface_container_high
                    }
                }

                IconButton {
                    icon: "" // tabler plus
                    isRound: true
                    type: IconButton.Tonal
                    disabled: !newFeed.text.trim().length
                    onClicked: {
                        const f = (Config.quicksettings.newsFeeds ?? []).slice();
                        f.push(newFeed.text.trim());
                        Config.quicksettings.newsFeeds = f;
                        newFeed.text = "";
                    }
                }
            }

            SettingRow {
                label: qsTr("Refresh interval")
                description: qsTr("Minutes between automatic feed refreshes.")
                advanced: true
                CustomSpinBox {
                    value: Config.quicksettings.newsRefreshMinutes
                    min: 5
                    max: 1440
                    step: 5
                    onValueModified: v => Config.quicksettings.newsRefreshMinutes = v
                }
            }

            SettingRow {
                label: qsTr("Article limit")
                description: qsTr("Maximum articles kept across all feeds.")
                advanced: true
                CustomSpinBox {
                    value: Config.quicksettings.newsLimit
                    min: 5
                    max: 200
                    step: 5
                    onValueModified: v => Config.quicksettings.newsLimit = v
                }
            }

            SettingRow {
                label: qsTr("Preview articles")
                description: qsTr("Articles shown per source while its group is collapsed.")
                showSeparator: false
                advanced: true
                CustomSpinBox {
                    value: Config.quicksettings.newsPreviewNum
                    min: 1
                    max: 10
                    onValueModified: v => Config.quicksettings.newsPreviewNum = v
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }

    // Mutually exclusive pill picker (anchor edge, mode).
    component OptionPills: RowLayout {
        id: pills

        property var options: []
        property string current

        signal picked(string key)

        spacing: Appearance.spacing.small

        Repeater {
            model: pills.options

            delegate: StyledRect {
                id: pill
                required property var modelData
                readonly property bool active: pills.current === modelData.key

                implicitWidth: pillLabel.implicitWidth + Appearance.padding.medium * 2
                implicitHeight: pillLabel.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.small
                color: active ? Colours.palette.secondary_container : Colours.palette.surface_container_high

                StyledText {
                    id: pillLabel
                    anchors.centerIn: parent
                    text: pill.modelData.label
                    font.pointSize: Appearance.font.size.small
                    color: pill.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pills.picked(pill.modelData.key)
                }
            }
        }
    }

    // Enable/disable + drag-to-reorder rows for one registry's units (pages or
    // cards). Same slot mechanics as DashboardSettingsPage: rows are positioned
    // by their slot in `work`; the dragged row follows the cursor and array-moves
    // through `work` so neighbours animate aside; release persists via reordered().
    component ReorderList: Item {
        id: list

        property var manifests: []
        property var configOrder: []
        property var disabledIds: []

        signal reordered(var ids)
        signal toggled(string id, bool on)

        // Map id → manifest (for title/icon in the rows).
        readonly property var manifestById: {
            const m = ({});
            for (const p of manifests ?? [])
                m[p.id] = p;
            return m;
        }

        // All unit ids in effective display order (known-order first, unknown
        // appended by manifest.order). Includes disabled units (settings shows all).
        readonly property var orderedIds: {
            const all = (manifests ?? []).slice().sort((a, b) => a.order - b.order || a.title.localeCompare(b.title));
            const allIds = all.map(p => p.id);
            const order = (configOrder ?? []).filter(id => allIds.includes(id));
            return order.concat(allIds.filter(id => !order.includes(id)));
        }

        readonly property int rowH: 48
        property var work: orderedIds
        property bool dragging: false

        // Stable identity list — one delegate per unit, created once. The
        // Repeater must NOT model `work`: reassigning `work` mid-drag would
        // rebuild every delegate and kill the active drag (the grip's MouseArea
        // dies with its row, so release — and the config write — never happens).
        // Reordering only moves rows through their `slot` binding.
        readonly property var stableIds: (manifests ?? []).map(p => p.id).sort()

        // Re-sync from config unless a drag is mid-flight.
        onOrderedIdsChanged: {
            if (!dragging)
                work = orderedIds;
        }

        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small
        implicitHeight: work.length * rowH

        Repeater {
            model: list.stableIds

            delegate: StyledRect {
                id: row

                required property string modelData
                readonly property var manifest: list.manifestById[modelData] ?? null
                readonly property int slot: list.work.indexOf(modelData)

                property bool held: false

                width: list.width
                height: list.rowH - Appearance.spacing.small
                z: held ? 2 : 1
                radius: Appearance.rounding.large
                color: held ? Colours.palette.surface_container_high
                            : rowHover.containsMouse ? Colours.palette.surface_container
                            : "transparent"

                Component.onCompleted: y = Qt.binding(() => slot * list.rowH)

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
                    const newSlot = Math.max(0, Math.min(list.work.length - 1, Math.round(y / list.rowH)));
                    const cur = list.work.indexOf(modelData);
                    if (newSlot !== cur) {
                        const w = list.work.slice();
                        w.splice(cur, 1);
                        w.splice(newSlot, 0, modelData);
                        list.work = w;
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
                        text: "" // tabler grip-vertical
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
                            drag.maximumY: (list.work.length - 1) * list.rowH
                            onPressed: {
                                row.held = true;
                                list.dragging = true;
                            }
                            onReleased: {
                                row.held = false;
                                list.dragging = false;
                                row.y = Qt.binding(() => row.slot * list.rowH);
                                list.reordered(list.work.slice());
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
                        checked: !(list.disabledIds ?? []).includes(row.modelData)
                        onToggled: list.toggled(row.modelData, checked)
                    }
                }
            }
        }
    }
}
