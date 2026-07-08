pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
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

    readonly property string currentEdge: {
        const a = Config.quicksettings.anchors;
        if (a.top) return "top";
        if (a.bottom) return "bottom";
        if (a.left) return "left";
        if (a.right) return "right";
        return "right";
    }
    function setEdge(edge: string): void {
        const a = Config.quicksettings.anchors;
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
            text: qsTr("Quicksettings")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        SettingSection {
            title: qsTr("General")
            icon: "\ueb3f" // tabler toggle-right

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
                label: qsTr("Padding")
                description: qsTr("Inner padding around the content, in pixels.")
                advanced: true
                CustomSpinBox {
                    value: Config.quicksettings.padding
                    min: 0
                    max: 60
                    onValueModified: v => Config.quicksettings.padding = v
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

        SettingSection {
            title: qsTr("Position")
            icon: "\ueb3f"

            SettingRow {
                label: qsTr("Anchor edge")
                description: qsTr("Which screen edge the panel drops from.")
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

        SettingSection {
            title: qsTr("Pages")
            icon: "\ueb3f"

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Toggle tab pages on/off.")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.on_surface_variant
                wrapMode: Text.WordWrap
            }

            UnitList {
                manifests: pageRegistry.all ?? []
                disabled: Config.quicksettings.disabled ?? []
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
            icon: "\ueb3f"

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Toggle the cards shown below the tabs.")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.on_surface_variant
                wrapMode: Text.WordWrap
            }

            UnitList {
                manifests: cardRegistry.all ?? []
                disabled: Config.quicksettings.cardsDisabled ?? []
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
            icon: "\ueb3f"

            SettingRow {
                label: qsTr("Wi-Fi")
                StyledSwitch {
                    checked: Config.quicksettings.toggles.wifi
                    onToggled: Config.quicksettings.toggles.wifi = checked
                }
            }
            SettingRow {
                label: qsTr("Bluetooth")
                StyledSwitch {
                    checked: Config.quicksettings.toggles.bluetooth
                    onToggled: Config.quicksettings.toggles.bluetooth = checked
                }
            }
            SettingRow {
                label: qsTr("Microphone")
                StyledSwitch {
                    checked: Config.quicksettings.toggles.mic
                    onToggled: Config.quicksettings.toggles.mic = checked
                }
            }
            SettingRow {
                label: qsTr("Do not disturb")
                StyledSwitch {
                    checked: Config.quicksettings.toggles.dnd
                    onToggled: Config.quicksettings.toggles.dnd = checked
                }
            }
            SettingRow {
                label: qsTr("Settings button")
                description: qsTr("Shortcut to the pShell settings window.")
                showSeparator: false
                StyledSwitch {
                    checked: Config.quicksettings.toggles.settings
                    onToggled: Config.quicksettings.toggles.settings = checked
                }
            }
        }

        SettingSection {
            title: qsTr("News")
            icon: "\ueafd" // tabler news

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
                        icon: "\ueb41" // tabler trash
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
                    icon: "\ueb0b" // tabler plus
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
                showSeparator: false
                advanced: true
                CustomSpinBox {
                    value: Config.quicksettings.newsLimit
                    min: 5
                    max: 200
                    step: 5
                    onValueModified: v => Config.quicksettings.newsLimit = v
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }

    // Enable/disable rows for one registry's units (pages or cards).
    component UnitList: ColumnLayout {
        id: unitList

        property var manifests: []
        property var disabled: []

        signal toggled(string id, bool on)

        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: [...(unitList.manifests ?? [])].sort((a, b) => a.order - b.order || a.title.localeCompare(b.title))

            delegate: RowLayout {
                id: unitRow

                required property var modelData

                Layout.fillWidth: true
                spacing: Appearance.spacing.medium

                StyledText {
                    text: unitRow.modelData.icon ?? ""
                    font.family: Appearance.font.family.tabler
                    font.pointSize: Appearance.font.size.large
                    color: Colours.palette.on_surface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: unitRow.modelData.title
                    elide: Text.ElideRight
                }

                StyledSwitch {
                    checked: !(unitList.disabled ?? []).includes(unitRow.modelData.id)
                    onToggled: unitList.toggled(unitRow.modelData.id, checked)
                }
            }
        }
    }
}
