pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.utils
import qs.components
import qs.components.controls
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts

// Full-config theme manager. Each card is a presets/full/<name>.json snapshot:
// click to apply, pencil to rename, trash to delete; the top field saves the
// current config as a new theme. Backed by PresetsManager (scope "full").
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function _save(): void {
        const n = nameField.text.trim();
        if (!n)
            return;
        PresetsManager.savePreset("full", n);
        nameField.text = "";
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.normal

        StyledText {
            text: qsTr("Themes")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        StyledText {
            text: qsTr("Whole-config snapshots. Applying one swaps your entire shell.json.")
            font.pointSize: Appearance.font.size.normal
            color: Colours.palette.on_surface_variant
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.bottomMargin: Appearance.spacing.small
        }

        SettingSection {
            title: qsTr("Save current")
            icon: "\ueb62" // tabler device-floppy

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledTextField {
                    id: nameField
                    Layout.fillWidth: true
                    placeholderText: qsTr("New theme name…")
                    onAccepted: root._save()
                    padding: Appearance.padding.small
                    leftPadding: Appearance.padding.normal
                    rightPadding: Appearance.padding.normal
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

        SettingSection {
            title: qsTr("Saved themes")
            icon: "\ueb01" // tabler palette

            StyledText {
                visible: themeList.count === 0
                Layout.fillWidth: true
                text: qsTr("No themes saved yet.")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.outline
            }

            Repeater {
                id: themeList

                model: FolderListModel {
                    folder: `file://${Paths.config}/presets/full`
                    nameFilters: ["*.json"]
                    showDirs: false
                    sortField: FolderListModel.Name
                }

                delegate: StyledRect {
                    id: card

                    required property string fileBaseName
                    property bool editing: false
                    property bool confirmingDelete: false

                    function commit(): void {
                        const n = nameEdit.text.trim();
                        if (n && n !== card.fileBaseName)
                            PresetsManager.renamePreset("full", card.fileBaseName, n);
                        card.editing = false;
                    }

                    Layout.fillWidth: true
                    implicitHeight: cardRow.implicitHeight + Appearance.padding.normal * 2
                    radius: Appearance.rounding.normal
                    color: card.confirmingDelete ? Qt.alpha(Colours.palette.error, 0.18) : Colours.layer(Colours.palette.surface_container, 2)

                    Timer {
                        id: delTimer
                        interval: 3000
                        onTriggered: card.confirmingDelete = false
                    }

                    StateLayer {
                        function onClicked(): void {
                            if (card.confirmingDelete)
                                card.confirmingDelete = false;
                            else if (!card.editing)
                                PresetsManager.applyPreset("full", card.fileBaseName);
                        }
                    }

                    RowLayout {
                        id: cardRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.rightMargin: Appearance.padding.small
                        spacing: Appearance.spacing.small

                        StyledText {
                            visible: !card.editing
                            Layout.fillWidth: true
                            text: card.fileBaseName
                            elide: Text.ElideRight
                            color: Colours.palette.on_surface
                        }

                        StyledTextField {
                            id: nameEdit
                            visible: card.editing
                            Layout.fillWidth: true
                            text: card.fileBaseName
                            onAccepted: card.commit()
                            padding: Appearance.padding.small
                            leftPadding: Appearance.padding.normal
                            rightPadding: Appearance.padding.normal
                            background: StyledRect {
                                radius: Appearance.rounding.small
                                color: Colours.palette.surface_container_high
                            }
                        }

                        IconButton {
                            type: IconButton.Text
                            icon: card.editing ? "\uea5e" : "\ueb04" // tabler check : pencil
                            onClicked: {
                                if (card.editing) {
                                    card.commit();
                                } else {
                                    card.confirmingDelete = false;
                                    nameEdit.text = card.fileBaseName;
                                    card.editing = true;
                                    nameEdit.forceActiveFocus();
                                }
                            }
                        }

                        IconButton {
                            type: IconButton.Text
                            icon: card.confirmingDelete ? "\uea5e" : "\ueb41" // tabler check : trash
                            onClicked: {
                                if (card.confirmingDelete) {
                                    PresetsManager.deletePreset("full", card.fileBaseName);
                                } else {
                                    card.confirmingDelete = true;
                                    delTimer.restart();
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.spacing.large
        }
    }
}
