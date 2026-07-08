pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.modules.quicksettings.content
import Caelestia
import Quickshell
import QtQuick
import QtQuick.Layouts

// Screen-recorder card — port of caelestia's Record card onto the Capture
// service: SplitButton mode menu (fullscreen/region), a recordings list that
// animates into REC controls while recording, and an inline delete confirm.
// Starting fullscreen opens Capture's pending audio chooser (top rails panel).
QsCard {
    id: root

    // Injected by the card host so the SplitButton dropdown stays pickable
    // inside the layershell panel (see QuicksettingsContent).
    property Item menuHost: null

    property string confirmDeletePath: ""

    readonly property string recsDir: Capture.resolvePath(Config.capture.recordDir) || `${Capture.home}/Videos`

    readonly property string elapsedStr: {
        const ms = Capture.recordPausedAccum + (Capture.recordPaused ? 0 : Time.date.getTime() - Capture.recordStartedAt);
        const s = Math.max(0, Math.floor(ms / 1000));
        const hours = Math.floor(s / 3600);
        const mins = Math.floor((s % 3600) / 60);
        const secs = (s % 60).toString().padStart(2, "0");
        return hours > 0 ? `${hours}:${mins.toString().padStart(2, "0")}:${secs}` : `${mins}:${secs}`;
    }

    function startFullscreen(): void {
        const name = Niri.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "");
        Capture.requestRecordOutput(name);
    }

    // Region selection lives in the capture editor; hand off through IPC so
    // the modules stay decoupled, and close the panel out of the way.
    function startRegion(): void {
        IpcManager.show("quicksettings", false);
        Quickshell.execDetached(["qs", "-c", "pShell", "ipc", "call", "capture", "region"]);
    }

    implicitHeight: layout.implicitHeight + Appearance.padding.large * 2

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.medium

        RowLayout {
            spacing: Appearance.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: {
                    const h = icon.implicitHeight + Appearance.padding.small * 2;
                    return h - (h % 2);
                }

                radius: Appearance.rounding.full
                color: Capture.recording ? Colours.palette.secondary : Colours.palette.secondary_container

                StyledIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: "\ued22" // tabler video
                    color: Capture.recording ? Colours.palette.on_secondary : Colours.palette.on_secondary_container
                    font.pointSize: Appearance.font.size.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Screen Recorder")
                    font: Appearance.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    animate: true
                    text: {
                        if (Capture.recordPending)
                            return qsTr("Choose an audio source…");
                        if (Capture.recording)
                            return Capture.recordPaused ? qsTr("Paused") : qsTr("Running...");
                        return qsTr("Ready");
                    }
                    color: Colours.palette.on_surface_variant
                    font: Appearance.font.body.small
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: Capture.recordPending
                isRound: true
                icon: "\ueb55" // tabler x
                type: IconButton.Tonal
                onClicked: Capture.cancelPending()
            }

            SplitButton {
                disabled: Capture.recording || Capture.recordPending
                menuHost: root.menuHost

                active: menuItems.find(m => m.value === Config.quicksettings.recordMode) ?? menuItems[0]
                menu.onItemSelected: item => Config.quicksettings.recordMode = item.value

                menuItems: [
                    MenuItem {
                        value: "fullscreen"
                        icon: "\ueaea" // tabler maximize
                        text: qsTr("Record fullscreen")
                        activeText: qsTr("Fullscreen")
                        onClicked: root.startFullscreen()
                    },
                    MenuItem {
                        value: "region"
                        icon: "\uea85" // tabler crop
                        text: qsTr("Record region")
                        activeText: qsTr("Region")
                        onClicked: root.startRegion()
                    }
                ]
            }
        }

        Loader {
            id: listOrControls

            // 0 = recordings list, 1 = REC controls, 2 = delete confirm.
            property int viewMode: Capture.recording ? 1 : root.confirmDeletePath ? 2 : 0

            asynchronous: true
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            sourceComponent: viewMode === 1 ? recordingControls : viewMode === 2 ? deleteConfirm : recordingList
            clip: Layout.preferredHeight < implicitHeight

            Behavior on Layout.preferredHeight {
                id: locHeightAnim

                enabled: false

                Anim {}
            }

            Behavior on viewMode {
                SequentialAnimation {
                    Anim {
                        target: listOrControls
                        property: "opacity"
                        to: 0
                        type: Anim.DefaultEffects
                    }
                    PropertyAction {
                        target: locHeightAnim
                        property: "enabled"
                        value: true
                    }
                    PropertyAction {}
                    ParallelAnimation {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: 100
                            }
                            PropertyAction {
                                target: locHeightAnim
                                property: "enabled"
                                value: false
                            }
                        }
                        Anim {
                            target: listOrControls
                            property: "opacity"
                            to: 1
                            type: Anim.SlowEffects
                        }
                    }
                }
            }
        }
    }

    Component {
        id: recordingList

        QsRecordingList {
            recsDir: root.recsDir
            onRequestDelete: path => root.confirmDeletePath = path
        }
    }

    Component {
        id: recordingControls

        RowLayout {
            spacing: Appearance.spacing.medium

            StyledRect {
                radius: Appearance.rounding.full
                color: Capture.recordPaused ? Colours.palette.tertiary : Colours.palette.error

                implicitWidth: recText.implicitWidth + Appearance.padding.medium * 2
                implicitHeight: recText.implicitHeight + Appearance.padding.large

                StyledText {
                    id: recText

                    anchors.centerIn: parent
                    animate: true
                    text: Capture.recordPaused ? "PAUSED" : "REC"
                    color: Capture.recordPaused ? Colours.palette.on_tertiary : Colours.palette.on_error
                    font: Appearance.font.mono.small
                }

                Behavior on implicitWidth {
                    Anim {}
                }

                SequentialAnimation on opacity {
                    running: !Capture.recordPaused
                    alwaysRunToEnd: true
                    loops: Animation.Infinite

                    Anim {
                        from: 1
                        to: 0
                        duration: Appearance.anim.durations.large
                        easing.bezierCurve: Appearance.anim.curves.emphasizedAccel
                    }
                    Anim {
                        from: 0
                        to: 1
                        duration: Appearance.anim.durations.extraLarge
                        easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Recording for %1").arg(root.elapsedStr)
                font: Appearance.font.body.medium
                elide: Text.ElideMiddle
            }

            RowLayout {
                spacing: Appearance.spacing.extraSmall

                IconButton {
                    isRound: true
                    label.animate: true
                    icon: Capture.recordPaused ? "\ued46" : "\ued45" // tabler player-play / player-pause
                    toggle: true
                    checked: Capture.recordPaused
                    type: IconButton.Tonal
                    onClicked: {
                        Capture.togglePause();
                        internalChecked = Capture.recordPaused;
                    }
                }

                IconButton {
                    isRound: true
                    icon: "\ued4a" // tabler player-stop
                    inactiveColour: Colours.palette.error
                    inactiveOnColour: Colours.palette.on_error
                    onClicked: Capture.stopRecord()
                }
            }
        }
    }

    Component {
        id: deleteConfirm

        ColumnLayout {
            spacing: Appearance.spacing.small

            StyledText {
                text: qsTr("Delete recording?")
                font: Appearance.font.body.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("'%1' will be permanently deleted.").arg(root.confirmDeletePath.split("/").pop())
                color: Colours.palette.on_surface_variant
                font: Appearance.font.body.small
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Appearance.spacing.medium

                TextButton {
                    text: qsTr("Cancel")
                    type: TextButton.Text
                    onClicked: root.confirmDeletePath = ""
                }

                TextButton {
                    text: qsTr("Delete")
                    type: TextButton.Text
                    label.color: Colours.palette.error
                    stateLayer.color: Colours.palette.error
                    onClicked: {
                        CUtils.deleteFile(`file://${root.confirmDeletePath}`);
                        root.confirmDeletePath = "";
                    }
                }
            }
        }
    }
}
