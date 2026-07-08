pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.config
import qs.services
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// One per-app audio stream: name above a compact horizontal volume slider.
ColumnLayout {
    id: root

    required property PwNode stream

    spacing: Appearance.spacing.small / 2

    StyledText {
        Layout.fillWidth: true
        text: Audio.getStreamName(root.stream)
        elide: Text.ElideRight
        font: Appearance.font.label.medium
        color: Colours.palette.on_surface_variant
    }

    FilledSlider {
        Layout.fillWidth: true
        implicitHeight: Appearance.padding.large + Appearance.padding.small
        orientation: Qt.Horizontal
        icon: Icons.getVolumeIcon(value, Audio.getStreamMuted(root.stream))
        from: 0
        to: Config.osd.maxVolume
        value: Audio.getStreamVolume(root.stream)
        onMoved: Audio.setStreamVolume(root.stream, value)
        onIconTapped: () => Audio.setStreamMuted(root.stream, !Audio.getStreamMuted(root.stream))
    }
}
