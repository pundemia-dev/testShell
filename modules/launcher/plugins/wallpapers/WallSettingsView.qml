import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Оверлей настроек Wallpaper Engine: navigation rail + шесть табов
// (Display/Theme/Gallery/Slideshow/System/Keys). `mod` — WallpapersModule.
StyledRect {
    id: settingsOverlay

    required property var mod

    color: Colours.palette.surface_container; radius: Appearance.rounding.large
    opacity: mod.isSettingsOpen ? 1.0 : 0.0; visible: opacity > 0
    Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.normal } }

    MouseArea { anchors.fill: parent; enabled: settingsOverlay.mod.isSettingsOpen; hoverEnabled: true; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = true }

    RowLayout {
        anchors.fill: parent; spacing: 0

        // ── Navigation Rail ──
        StyledRect {
            Layout.fillHeight: true; Layout.preferredWidth: 72
            color: Colours.palette.surface_container_low; radius: Appearance.rounding.large

            ColumnLayout {
                anchors.fill: parent; anchors.topMargin: Appearance.padding.medium; anchors.bottomMargin: Appearance.padding.medium; spacing: Appearance.spacing.small

                Repeater {
                    model: [
                        { icon: "\ue30d", label: "Display",   index: 0 },
                        { icon: "\ue40a", label: "Theme",     index: 1 },
                        { icon: "\ue3b6", label: "Gallery",   index: 2 },
                        { icon: "\ue41b", label: "Slideshow", index: 3 },
                        { icon: "\ue8b8", label: "System",    index: 4 },
                        { icon: "\ue312", label: "Keys",      index: 5 }
                    ]
                    delegate: Item {
                        Layout.fillWidth: true; Layout.preferredHeight: 56
                        property bool isActive: settingsOverlay.mod.settingsTabIndex === modelData.index
                        StyledRect {
                            anchors.centerIn: parent; width: 56; height: 48; radius: Appearance.rounding.full
                            color: parent.isActive ? Colours.palette.secondary_container : _navHov.hovered ? Colours.alpha(Colours.palette.on_surface,0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: Appearance.anim.durations.smaller } }
                            ColumnLayout { anchors.centerIn: parent; spacing: 2
                                StyledIcon { Layout.alignment: Qt.AlignHCenter; text: modelData.icon; font.pointSize: Appearance.font.size.large; color: parent.parent.parent.parent.isActive?Colours.palette.on_secondary_container:Colours.palette.on_surface_variant }
                                StyledText  { Layout.alignment: Qt.AlignHCenter; text: modelData.label; font.pointSize: Appearance.font.size.smaller; font.weight: parent.parent.parent.parent.isActive?Font.DemiBold:Font.Normal; color: parent.parent.parent.parent.isActive?Colours.palette.on_secondary_container:Colours.palette.on_surface_variant }
                            }
                            HoverHandler { id: _navHov }
                            TapHandler { onTapped: settingsOverlay.mod.settingsTabIndex = modelData.index }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // ── Content ──
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true

            StackLayout {
                anchors.fill: parent; anchors.margins: Appearance.padding.medium
                currentIndex: settingsOverlay.mod.settingsTabIndex

                WallDisplayTab   { mod: settingsOverlay.mod }
                WallThemeTab     { mod: settingsOverlay.mod }
                WallGalleryTab   { mod: settingsOverlay.mod }
                WallSlideshowTab { mod: settingsOverlay.mod }
                WallSystemTab    { mod: settingsOverlay.mod }
                WallKeysTab      {}
            }
        }
    }
}
