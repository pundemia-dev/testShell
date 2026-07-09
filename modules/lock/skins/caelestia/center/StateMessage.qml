pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services
import qs.config

Item {
    id: root

    required property var pam

    readonly property string msg: {
        if (pam.fprintState === "error")
            return qsTr("FP ERROR: %1").arg(pam.fprint.message);
        if (pam.state === "error")
            return qsTr("PW ERROR: %1").arg(pam.passwd.message);

        if (pam.lockMessage)
            return pam.lockMessage;

        if (pam.state === "max" && pam.fprintState === "max")
            return qsTr("Maximum password and fingerprint attempts reached.");
        if (pam.state === "max") {
            if (pam.fprint.available)
                return qsTr("Maximum password attempts reached. Please use fingerprint.");
            return qsTr("Maximum password attempts reached.");
        }
        if (pam.fprintState === "max")
            return qsTr("Maximum fingerprint attempts reached. Please use password.");

        if (pam.state === "fail") {
            if (pam.fprint.available)
                return qsTr("Incorrect password. Please try again or use fingerprint.");
            return qsTr("Incorrect password. Please try again.");
        }
        if (pam.fprintState === "fail")
            return qsTr("Fingerprint not recognized (%1/%2). Please try again or use password.").arg(pam.fprint.tries).arg(Config.lock.maxFprintTries);

        return "";
    }

    // niri doesn't expose capsLock/numLock (stubs in the Niri service); the
    // layout part still works via KeyboardLayoutsChanged events.
    readonly property string stateMsg: {
        if (Niri.keyboardLayoutIndex !== 0) {
            if (Niri.capsLock && Niri.numLock)
                return qsTr("Caps lock and Num lock are ON.\nKeyboard layout: %1").arg(Niri.kbLayoutFull);
            if (Niri.capsLock)
                return qsTr("Caps lock is ON. Kb layout: %1").arg(Niri.kbLayoutFull);
            if (Niri.numLock)
                return qsTr("Num lock is ON. Kb layout: %1").arg(Niri.kbLayoutFull);
            return qsTr("Keyboard layout: %1").arg(Niri.kbLayoutFull);
        }

        if (Niri.capsLock && Niri.numLock)
            return qsTr("Caps lock and Num lock are ON.");
        if (Niri.capsLock)
            return qsTr("Caps lock is ON.");
        if (Niri.numLock)
            return qsTr("Num lock is ON.");

        return "";
    }

    property bool stateMsgShouldBeVisible

    onMsgChanged: {
        if (msg) {
            if (message.opacity > 0) {
                message.animate = true;
                message.text = msg;
                message.animate = false;

                exitAnim.stop();
                if (message.scale < 1)
                    appearAnim.restart();
                else
                    flashAnim.restart();
            } else {
                message.text = msg;
                exitAnim.stop();
                appearAnim.restart();
            }
        } else {
            appearAnim.stop();
            flashAnim.stop();
            exitAnim.start();
        }
    }

    onStateMsgChanged: {
        if (stateMsg) {
            if (stateMessage.opacity > 0) {
                stateMessage.animate = true;
                stateMessage.text = stateMsg;
                stateMessage.animate = false;
            } else {
                stateMessage.text = stateMsg;
            }
            stateMsgShouldBeVisible = true;
        } else {
            stateMsgShouldBeVisible = false;
        }
    }

    implicitHeight: Math.max(message.implicitHeight, stateMessage.implicitHeight)

    Behavior on implicitHeight {
        Anim {}
    }

    StyledText {
        id: stateMessage

        anchors.left: parent.left
        anchors.right: parent.right

        scale: root.stateMsgShouldBeVisible && !root.msg ? 1 : 0.7
        opacity: root.stateMsgShouldBeVisible && !root.msg ? 1 : 0
        color: Colours.palette.on_surface_variant

        font: Appearance.font.body.small
        horizontalAlignment: Qt.AlignHCenter
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        lineHeight: 1.2

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    StyledText {
        id: message

        anchors.left: parent.left
        anchors.right: parent.right

        scale: 0.7
        opacity: 0
        color: Colours.palette.error

        font: Appearance.font.body.small
        horizontalAlignment: Qt.AlignHCenter
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere

        Connections {
            function onFlashMsg(): void {
                exitAnim.stop();
                if (message.scale < 1)
                    appearAnim.restart();
                else
                    flashAnim.restart();
            }

            target: root.pam
        }

        Anim {
            id: appearAnim

            type: Anim.DefaultEffects
            target: message
            properties: "scale,opacity"
            to: 1
            onFinished: flashAnim.restart()
        }

        SequentialAnimation {
            id: flashAnim

            loops: 2

            FlashAnim {
                to: 0.3
            }
            FlashAnim {
                to: 1
            }
        }

        ParallelAnimation {
            id: exitAnim

            Anim {
                target: message
                property: "scale"
                to: 0.7
                type: Anim.StandardLarge
            }
            Anim {
                target: message
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
        }
    }

    component FlashAnim: NumberAnimation {
        target: message
        property: "opacity"
        duration: Appearance.anim.durations.small
        easing.type: Easing.Linear
    }
}
