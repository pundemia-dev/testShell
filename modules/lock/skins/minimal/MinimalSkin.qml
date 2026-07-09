pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.components
import qs.components.images
import qs.services
import qs.config

// Minimal lock skin: blurred screencopy, a big clock and a password pill.
// Mostly here to prove the skin contract — all visuals swap per skin while the
// lock/PAM logic stays in the module.
Item {
    id: root

    required property var lock
    required property var pam
    required property var screen

    readonly property bool unlocking: unlockAnim.running

    focus: true
    Keys.onPressed: event => {
        if (unlocking)
            return;
        root.pam.handleKey(event);
    }

    Connections {
        function onUnlock(): void {
            unlockAnim.start();
        }

        target: root.lock
    }

    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
            Anim {
                target: column
                property: "scale"
                to: 0.9
            }
        }
        ScriptAction {
            script: root.lock.finishUnlock()
        }
    }

    // Blurred wallpaper background (niri refuses screencopy while locked, so
    // no ScreencopyView here — see CaelestiaSkin).
    Item {
        id: background

        anchors.fill: parent
        opacity: 0

        StyledRect {
            anchors.fill: parent
            color: Colours.palette.surface
        }

        CachingImage {
            anchors.fill: parent
            path: Colours.wallpaperPath
            visible: Colours.wallpaperPath !== ""
            fillMode: Image.PreserveAspectCrop

            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
                blurMultiplier: 1
            }
        }

        Anim on opacity {
            running: true
            to: 1
            type: Anim.StandardLarge
        }

        StyledRect {
            anchors.fill: parent
            color: Colours.palette.surface
            opacity: 0.35
        }
    }

    Column {
        id: column

        anchors.centerIn: parent
        spacing: Appearance.spacing.largeIncreased

        Anim on scale {
            running: true
            from: 0.9
            to: 1
            type: Anim.FastSpatial
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.timeStr
            color: Colours.palette.primary
            font.family: Appearance.font.family.sans
            font.pointSize: Appearance.font.headline.large.pointSize * 3
            font.weight: Font.Medium
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.format("dddd • d MMM").toUpperCase()
            color: Colours.palette.on_surface
            font.family: Appearance.font.family.sans
            font.pointSize: Appearance.font.title.medium.pointSize
            font.weight: Font.DemiBold
        }

        StyledRect {
            anchors.horizontalCenter: parent.horizontalCenter

            implicitWidth: 320
            implicitHeight: pill.implicitHeight + Appearance.padding.medium * 2

            color: Colours.tPalette.surface_container
            radius: Appearance.rounding.full

            Row {
                id: pill

                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                StyledIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.pam.passwd.active ? "" : "" // tabler refresh / lock
                    color: root.pam.state === "fail" || root.pam.state === "error" ? Colours.palette.error : Colours.palette.on_surface_variant
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.pam.buffer)
                            return "●".repeat(Math.min(root.pam.buffer.length, 24));
                        if (root.pam.passwd.active)
                            return qsTr("Checking...");
                        if (root.pam.state === "max")
                            return qsTr("Max tries reached");
                        return qsTr("Enter password");
                    }
                    color: root.pam.buffer ? Colours.palette.on_surface : Colours.palette.outline
                    font: Appearance.font.body.medium
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 360

            text: {
                if (root.pam.fprintState === "error")
                    return qsTr("FP ERROR: %1").arg(root.pam.fprint.message);
                if (root.pam.state === "error")
                    return qsTr("PW ERROR: %1").arg(root.pam.passwd.message);
                if (root.pam.lockMessage)
                    return root.pam.lockMessage;
                if (root.pam.state === "fail")
                    return qsTr("Incorrect password. Please try again.");
                if (root.pam.state === "max")
                    return qsTr("Maximum password attempts reached.");
                return "";
            }
            visible: text !== ""
            color: Colours.palette.error
            font: Appearance.font.body.small
            horizontalAlignment: Qt.AlignHCenter
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }
    }
}
