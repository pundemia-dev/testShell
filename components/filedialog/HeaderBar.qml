pragma ComponentBehavior: Bound

import ".."
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property var dialog

    implicitWidth: inner.implicitWidth + Appearance.padding.normal * 2
    implicitHeight: inner.implicitHeight + Appearance.padding.normal * 2

    color: Colours.palette.surface_container

    RowLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        spacing: Appearance.spacing.small

        Item {
            implicitWidth: implicitHeight
            implicitHeight: upIcon.implicitHeight + Appearance.padding.small * 2

            StateLayer {
                radius: Appearance.rounding.small
                disabled: root.dialog.cwd.length === 1

                function onClicked(): void {
                    root.dialog.cwd.pop();
                }
            }

            MaterialIcon {
                id: upIcon

                anchors.centerIn: parent
                text: "drive_folder_upload"
                color: root.dialog.cwd.length === 1 ? Colours.palette.outline : Colours.palette.on_surface
                grade: 200
            }
        }

        StyledRect {
            Layout.fillWidth: true

            radius: Appearance.rounding.small
            color: Colours.palette.surface_container_high

            implicitHeight: pathComponents.implicitHeight + pathComponents.anchors.margins * 2

            RowLayout {
                id: pathComponents

                anchors.fill: parent
                anchors.margins: Appearance.padding.small / 2
                anchors.leftMargin: 0

                spacing: Appearance.spacing.small

                Repeater {
                    model: root.dialog.cwd

                    RowLayout {
                        id: folder

                        required property string modelData
                        required property int index

                        spacing: 0

                        Loader {
                            Layout.rightMargin: Appearance.spacing.small
                            active: folder.index > 0
                            sourceComponent: StyledText {
                                text: "/"
                                color: Colours.palette.on_surface_variant
                                font.bold: true
                            }
                        }

                        Item {
                            implicitWidth: homeIcon.implicitWidth + (homeIcon.active ? Appearance.padding.small : 0) + folderName.implicitWidth + Appearance.padding.normal * 2
                            implicitHeight: folderName.implicitHeight + Appearance.padding.small * 2

                            Loader {
                                anchors.fill: parent
                                active: folder.index < root.dialog.cwd.length - 1
                                sourceComponent: StateLayer {
                                    radius: Appearance.rounding.small

                                    function onClicked(): void {
                                        root.dialog.cwd = root.dialog.cwd.slice(0, folder.index + 1);
                                    }
                                }
                            }

                            Loader {
                                id: homeIcon

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Appearance.padding.normal

                                active: folder.index === 0 && folder.modelData === "Home"
                                sourceComponent: MaterialIcon {
                                    text: "home"
                                    color: root.dialog.cwd.length === 1 ? Colours.palette.on_surface : Colours.palette.on_surface_variant
                                    fill: 1
                                }
                            }

                            StyledText {
                                id: folderName

                                anchors.left: homeIcon.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: homeIcon.active ? Appearance.padding.small : 0

                                text: folder.modelData
                                color: folder.index < root.dialog.cwd.length - 1 ? Colours.palette.on_surface_variant : Colours.palette.on_surface
                                font.bold: true
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }
}
