pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.utils
import qs.components
import qs.components.controls
import qs.components.effects
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// FAB-style preset switcher for the settings sidebar (à la end-4's "Config
// file" button, repurposed). Primary fill / on_primary content, icon in the
// shared leading slot so it lines up with the rail icons. Click opens a popup
// listing presets for the current page's `scope` (apply / delete) plus a
// "save current" field. Backed by PresetsManager. See docs/development/settings.md.
StyledRect {
    id: root

    property bool expanded: true
    property string scope: "full"
    property int padH: Appearance.padding.large
    property int iconBox: 26
    property int iconSize: Appearance.font.size.large
    property int buttonHeight: iconBox + Appearance.padding.medium * 2

    implicitWidth: root.expanded ? (padH + iconBox + Appearance.spacing.small + labelText.implicitWidth + padH) : (padH * 2 + iconBox)
    implicitHeight: buttonHeight
    radius: Appearance.rounding.small
    color: Colours.palette.primary

    Behavior on implicitWidth {
        Anim {}
    }

    StateLayer {
        color: Colours.palette.on_primary
        function onClicked(): void {
            if (menu.visible)
                menu.close();
            else
                menu.open();
        }
    }

    // Icon in the shared leading slot — same x as every rail icon.
    StyledText {
        id: iconLabel
        anchors.left: parent.left
        anchors.leftMargin: root.padH
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconBox
        horizontalAlignment: Text.AlignHCenter
        text: "\ueb01" // tabler palette
        font.family: Appearance.font.family.tabler
        font.pointSize: root.iconSize
        color: Colours.palette.on_primary
    }

    StyledText {
        id: labelText
        anchors.left: iconLabel.right
        anchors.leftMargin: Appearance.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        text: qsTr("Presets")
        font.weight: Font.Medium
        color: Colours.palette.on_primary
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Anim {}
        }
    }

    Popup {
        id: menu

        y: root.height + Appearance.spacing.small
        width: 260
        padding: 0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Item {}

        enter: Transition {
            Anim {
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.anim.durations.small
            }
        }
        exit: Transition {
            Anim {
                property: "opacity"
                from: 1
                to: 0
                duration: Appearance.anim.durations.small
            }
        }

        contentItem: Elevation {
            level: 2
            radius: Appearance.rounding.small
            implicitHeight: menuColumn.implicitHeight

            StyledClippingRect {
                anchors.fill: parent
                radius: parent.radius
                color: Colours.tPalette.surface_container

                ColumnLayout {
                    id: menuColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.medium
                        Layout.bottomMargin: Appearance.padding.small
                        text: qsTr("Apply %1 preset").arg(root.scope)
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.on_surface_variant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.medium
                        visible: presetList.count === 0
                        text: qsTr("No saved presets yet.")
                        font.pointSize: Appearance.font.size.small
                        color: Colours.palette.outline
                    }

                    ListView {
                        id: presetList

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(contentHeight, 220)
                        visible: count > 0
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        model: FolderListModel {
                            folder: `file://${Paths.config}/presets/${root.scope}`
                            nameFilters: ["*.json"]
                            showDirs: false
                            sortField: FolderListModel.Name
                        }

                        delegate: StyledRect {
                            id: presetRow

                            required property string fileBaseName
                            property bool confirmingDelete: false

                            width: ListView.view.width
                            implicitHeight: rowText.implicitHeight + Appearance.padding.medium * 2
                            color: presetRow.confirmingDelete ? Qt.alpha(Colours.palette.error, 0.18) : "transparent"

                            Timer {
                                id: delTimer
                                interval: 3000
                                onTriggered: presetRow.confirmingDelete = false
                            }

                            StateLayer {
                                radius: 0
                                function onClicked(): void {
                                    if (presetRow.confirmingDelete) {
                                        presetRow.confirmingDelete = false;
                                        return;
                                    }
                                    PresetsManager.applyPreset(root.scope, presetRow.fileBaseName);
                                    menu.close();
                                }
                            }

                            StyledText {
                                id: rowText
                                anchors.left: parent.left
                                anchors.right: delButton.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Appearance.padding.medium
                                text: presetRow.fileBaseName
                                elide: Text.ElideRight
                            }

                            IconButton {
                                id: delButton
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: Appearance.padding.small
                                type: IconButton.Text
                                icon: presetRow.confirmingDelete ? "\uea5e" : "\ueb41" // tabler check : trash
                                onClicked: {
                                    if (presetRow.confirmingDelete)
                                        PresetsManager.deletePreset(root.scope, presetRow.fileBaseName);
                                    else {
                                        presetRow.confirmingDelete = true;
                                        delTimer.restart();
                                    }
                                }
                            }
                        }
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Colours.palette.outline_variant
                        opacity: 0.4
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.small
                        spacing: Appearance.spacing.small

                        StyledTextField {
                            id: nameField
                            Layout.fillWidth: true
                            placeholderText: qsTr("Save current as…")
                            padding: Appearance.padding.small
                            leftPadding: Appearance.padding.medium
                            rightPadding: Appearance.padding.medium
                            onAccepted: root._save()
                            background: StyledRect {
                                radius: Appearance.rounding.small
                                color: Colours.palette.surface_container_high
                            }
                        }

                        IconButton {
                            type: IconButton.Text
                            icon: "\ueb62" // tabler device-floppy
                            onClicked: root._save()
                        }
                    }
                }
            }
        }
    }

    function _save(): void {
        const n = nameField.text.trim();
        if (!n)
            return;
        PresetsManager.savePreset(root.scope, n);
        nameField.text = "";
    }
}
