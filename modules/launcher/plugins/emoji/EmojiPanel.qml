pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.components.controls
import qs.services

// Right-panel content for the emoji picker (the whole module lives here — no
// left list). Top: category tab bar. Middle: searchable grid of emoji cells.
// Bottom: preview of the selected emoji + its name. `mod` = EmojiModule (drives
// query/activeGroup/filtered/selectedIndex + copy); `store` = its EmojiStore.
Item {
    id: panelRoot

    anchors.fill: parent

    required property var mod
    required property var store

    readonly property bool searching: (mod?.query ?? "").length > 0

    // Index the pointer is currently over (-1 = none). Hover drives the footer
    // preview but NOT the keyboard selection, so hovering never repositions the
    // view (which would otherwise strand a delegate's hover state).
    property int hoverIndex: -1

    // Footer preview: prefer the hovered cell, else the keyboard-selected one.
    readonly property var current: {
        const f = mod?.filtered ?? [];
        if (hoverIndex >= 0 && hoverIndex < f.length)
            return f[hoverIndex];
        const i = mod?.selectedIndex ?? -1;
        return (i >= 0 && i < f.length) ? f[i] : null;
    }

    // Representative glyph per category (used as the tab label).
    readonly property var _groupGlyphs: ({
            "Smileys & Emotion": "😀",
            "People & Body": "🧑",
            "Animals & Nature": "🐻",
            "Food & Drink": "🍔",
            "Travel & Places": "✈️",
            "Activities": "⚽",
            "Objects": "💡",
            "Symbols": "❤️",
            "Flags": "🏁"
        })

    // Tab descriptors: recents (only when non-empty) + each category, in order.
    readonly property var tabs: {
        const out = [];
        if ((store?.recents?.length ?? 0) > 0)
            out.push({
                id: store.recentGroup,
                glyph: "🕘",
                name: "Recently used"
            });
        const gs = store?.groups ?? [];
        for (let i = 0; i < gs.length; i++)
            out.push({
                id: gs[i],
                glyph: panelRoot._groupGlyphs[gs[i]] ?? "🔣",
                name: gs[i]
            });
        return out;
    }

    // Drop a stale hover index when the visible set changes.
    Connections {
        target: panelRoot.mod
        function onFilteredChanged() {
            panelRoot.hoverIndex = -1;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.small

        // ── Category tabs ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Appearance.padding.small
            Layout.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.small

            Repeater {
                model: panelRoot.tabs

                StyledRect {
                    id: tab

                    required property var modelData
                    readonly property bool active: !panelRoot.searching && panelRoot.mod.activeGroup === modelData.id

                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: Appearance.rounding.medium
                    color: active ? Colours.palette.primary_container : "transparent"

                    Behavior on color {
                        CAnim {}
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: tab.modelData.glyph
                        font.pointSize: Appearance.font.size.large
                    }

                    StateLayer {
                        radius: tab.radius

                        function onClicked(): void {
                            panelRoot.mod.setGroup(tab.modelData.id);
                        }
                    }
                }
            }
        }

        // ── Emoji grid ────────────────────────────────────────────────
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.large
            color: Colours.transparency.enabled
                ? Colours.layer(Colours.palette.surface_container, 2)
                : Colours.palette.surface_container

            GridView {
                id: grid

                anchors.fill: parent
                anchors.margins: Appearance.padding.small
                clip: true

                readonly property int columns: Math.max(1, Math.floor(width / 46))
                cellWidth: width / columns
                cellHeight: 46

                model: panelRoot.mod.filtered
                currentIndex: panelRoot.mod.selectedIndex

                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 400

                onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)

                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: GridView.isCurrentItem

                    width: grid.cellWidth
                    height: grid.cellHeight

                    StyledRect {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: parent.height - 4
                        radius: Appearance.rounding.medium
                        color: cell.isCurrent
                            ? Qt.alpha(Colours.palette.primary, 0.18)
                            : (cellHover.hovered ? Qt.alpha(Colours.palette.on_surface, 0.08) : "transparent")

                        Behavior on color {
                            CAnim {}
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: cell.modelData.emoji
                            font.pointSize: Appearance.font.size.extraLarge
                        }

                        // Pointer handlers (not StateLayer/MouseArea) so hover
                        // reverts reliably even as the grid flicks under the
                        // cursor.
                        HoverHandler {
                            id: cellHover
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered)
                                    panelRoot.hoverIndex = cell.index;
                                else if (panelRoot.hoverIndex === cell.index)
                                    panelRoot.hoverIndex = -1;
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: panelRoot.mod.copyEmoji(cell.modelData.emoji, panelRoot.mod.autoPaste)
                        }
                    }
                }
            }

            // Overlay scrollbar (kept out of the GridView so it doesn't flick
            // away with the content).
            StyledScrollBar {
                flickable: grid
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Appearance.padding.small
            }

            // Empty state
            StyledText {
                anchors.centerIn: parent
                visible: (panelRoot.mod.filtered?.length ?? 0) === 0
                text: panelRoot.searching ? qsTr("No emoji found") : qsTr("Nothing here yet")
                color: Qt.alpha(Colours.palette.on_surface, 0.5)
                font: Appearance.font.body.medium
            }
        }

        // ── Preview footer ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Appearance.padding.small
            Layout.rightMargin: Appearance.padding.small
            Layout.preferredHeight: 40
            spacing: Appearance.spacing.medium

            StyledText {
                text: panelRoot.current?.emoji ?? ""
                font.pointSize: Appearance.font.size.extraLarge
                visible: panelRoot.current !== null
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: panelRoot.current?.name ?? qsTr("Search emoji…")
                    font: Appearance.font.body.medium
                    color: Colours.palette.on_surface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: panelRoot.current !== null
                    text: qsTr("Enter — copy") + (panelRoot.mod.autoPaste ? qsTr(" & paste") : "")
                        + qsTr("   ·   Alt+Enter — copy only")
                    font: Appearance.font.label.small
                    color: Qt.alpha(Colours.palette.on_surface, 0.45)
                    elide: Text.ElideRight
                }
            }
        }
    }
}
