pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.containers
import qs.components.controls
import Quickshell
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts

// Past recordings under the Capture record dir (port of caelestia's
// RecordingList on FolderListModel instead of the C++ FileSystemModel).
ColumnLayout {
    id: root

    required property string recsDir
    property bool expanded: false

    signal requestDelete(string path)

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.medium

        StyledIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "\ueb6b" // tabler list
            font.pointSize: Appearance.font.size.large
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            text: qsTr("Recordings")
            font: Appearance.font.body.medium
        }

        IconButton {
            icon: root.expanded ? "\uea62" : "\uea5f" // tabler chevron-up / chevron-down
            type: IconButton.Text
            label.animate: true
            onClicked: root.expanded = !root.expanded
        }
    }

    StyledListView {
        id: list

        model: FolderListModel {
            folder: `file://${root.recsDir}`
            nameFilters: ["recording_*.mp4"]
            showDirs: false
            sortField: FolderListModel.Name
            sortReversed: true
        }

        Layout.fillWidth: true
        implicitHeight: (Appearance.font.body.large.pointSize + Appearance.padding.small) * (root.expanded ? 10 : 3)
        clip: true

        delegate: RowLayout {
            id: recording

            required property string fileName
            required property string filePath

            width: list.width
            spacing: Appearance.spacing.extraSmall

            StyledText {
                Layout.fillWidth: true
                Layout.rightMargin: Appearance.spacing.extraSmall
                text: {
                    const matches = recording.fileName.match(/^recording_(\d{4})-(\d{2})-(\d{2})_(\d{2})\.(\d{2})\.(\d{2})/);
                    if (!matches)
                        return recording.fileName;
                    const [, y, mo, d, h, mi, s] = matches;
                    const date = new Date(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(s));
                    return qsTr("Recording at %1").arg(Qt.formatDateTime(date, "d MMM hh:mm"));
                }
                color: Colours.palette.on_surface_variant
                elide: Text.ElideRight
            }

            IconButton {
                icon: "\ued46" // tabler player-play
                type: IconButton.Text
                onClicked: {
                    IpcManager.show("quicksettings", false);
                    Quickshell.execDetached(["xdg-open", recording.filePath]);
                }
            }

            IconButton {
                icon: "\ueaad" // tabler folder
                type: IconButton.Text
                onClicked: {
                    IpcManager.show("quicksettings", false);
                    Quickshell.execDetached(["xdg-open", root.recsDir]);
                }
            }

            IconButton {
                icon: "\ueb41" // tabler trash
                type: IconButton.Text
                label.color: Colours.palette.error
                stateLayer.color: Colours.palette.error
                onClicked: root.requestDelete(recording.filePath)
            }
        }

        add: Transition {
            Anim {
                type: Anim.DefaultEffects
                property: "opacity"
                from: 0
                to: 1
            }
        }

        remove: Transition {
            Anim {
                type: Anim.DefaultEffects
                property: "opacity"
                to: 0
            }
        }

        displaced: Transition {
            Anim {
                type: Anim.DefaultEffects
                property: "opacity"
                to: 1
            }
            Anim {
                property: "y"
            }
        }

        Loader {
            asynchronous: true
            anchors.centerIn: parent

            opacity: list.count === 0 ? 1 : 0
            active: opacity > 0

            sourceComponent: RowLayout {
                spacing: Appearance.spacing.medium

                StyledIcon {
                    text: "\ued22" // tabler video
                    color: Colours.palette.outline
                }

                StyledText {
                    text: qsTr("No recordings found")
                    color: Colours.palette.outline
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Behavior on implicitHeight {
            Anim {}
        }
    }
}
