pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Layouts

// Lyrics panel: header + the time-synced LyricList (which is purely a view over
// the Lyrics service's runtime-fetched output).
ColumnLayout {
    id: root
    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledText {
            text: "\ueafc" // tabler music
            font.family: Appearance.font.family.tabler
            font.pointSize: Appearance.font.size.large
            color: Colours.palette.primary
        }
        StyledText {
            Layout.fillWidth: true
            text: qsTr("Lyrics")
            font.pointSize: Appearance.font.size.large
            font.weight: Font.DemiBold
        }
    }

    LyricList {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
}
