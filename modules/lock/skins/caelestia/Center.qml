import "center"
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.config

ColumnLayout {
    id: root

    required property var lock
    readonly property real centerScale: Math.min(1, (lock.screen?.height ?? 1440) / 1440)
    readonly property int centerWidth: Config.lock.sizes.centerWidth * centerScale

    Layout.preferredWidth: centerWidth
    Layout.fillWidth: false
    Layout.fillHeight: true

    spacing: Appearance.spacing.largeIncreased

    Clock {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Appearance.padding.large
        centerScale: root.centerScale
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter

        text: Time.format("dddd • d MMM").toUpperCase()
        color: Colours.palette.on_surface
        font.family: Appearance.font.family.sans
        font.pointSize: Appearance.font.title.medium.pointSize
        font.weight: Font.DemiBold
    }

    ProfilePic {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Appearance.spacing.extraExtraLarge * root.centerScale
        Layout.bottomMargin: Appearance.spacing.extraLarge * root.centerScale
        centerWidth: root.centerWidth
    }

    PasswordInput {
        Layout.alignment: Qt.AlignHCenter
        centerScale: Math.max(0.8, root.centerScale)
        centerWidth: root.centerWidth
        lock: root.lock
    }

    StateMessage {
        Layout.fillWidth: true
        pam: root.lock.pam
    }
}
