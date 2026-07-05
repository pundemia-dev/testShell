import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Правая панель Wallpaper Engine: бейдж модификаторов, empty state, карусель,
// подсказка и оверлей настроек. `mod` — инстанс WallpapersModule.
Item {
    id: panelContainer
    anchors.fill: parent

    required property var mod

    // Wrapper снимает clip с правой панели, читая это с корня панели
    // (rightLoader.item) — прокидываем флаг модуля.
    readonly property bool needsOverflow: mod.needsOverflow

    // ── Modifier badge ──
    StyledRect {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Appearance.padding.small
        z: 10
        color: Colours.alpha(Colours.palette.surface_container_highest, 0.9)
        border.width: 1; border.color: Colours.alpha(Colours.palette.outline_variant, 0.5)
        radius: Appearance.rounding.full
        implicitWidth: _badgeRow.implicitWidth + Appearance.padding.large * 2
        implicitHeight: _badgeRow.implicitHeight + Appearance.padding.small * 2
        property bool shouldShow: (!panelContainer.mod.isCtrlPressed && (panelContainer.mod.isAltPressed || panelContainer.mod.isShiftPressed)) || panelContainer.mod.visMode > 0
        opacity: shouldShow ? 1.0 : 0.0; scale: shouldShow ? 1.0 : 0.85; visible: opacity > 0
        Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.small } }
        Behavior on scale   { ScaleAnimator   { duration: Appearance.anim.durations.small } }
        RowLayout {
            id: _badgeRow; anchors.centerIn: parent; spacing: Appearance.spacing.large
            StyledIcon { visible: panelContainer.mod.isAltPressed && !panelContainer.mod.isCtrlPressed;  text: ""; color: Colours.palette.primary;     font.pointSize: Appearance.font.size.large }
            StyledIcon { visible: panelContainer.mod.isShiftPressed && !panelContainer.mod.isCtrlPressed; text: ""; color: Colours.palette.tertiary;    font.pointSize: Appearance.font.size.large }
            StyledIcon { visible: panelContainer.mod.visMode > 0; text: panelContainer.mod.visMode === 2 ? "" : ""; color: Colours.palette.on_surface; opacity: panelContainer.mod.visMode===1?0.4:1.0; font.pointSize: Appearance.font.size.large }
        }
    }

    // ── Empty state ──
    ColumnLayout {
        anchors.centerIn: parent; spacing: Appearance.spacing.medium; z: 5
        property bool shouldShow: panelContainer.mod.galleryModel.count === 0
        opacity: shouldShow ? 1.0 : 0.0; scale: shouldShow ? 1.0 : 0.92; visible: opacity > 0
        Behavior on opacity {
            OpacityAnimator {}
        }
        Behavior on scale { ScaleAnimator {} }
        StyledIcon {
            Layout.alignment: Qt.AlignHCenter
            text: panelContainer.mod.isShiftPressed?"":panelContainer.mod.isAltPressed?"":panelContainer.mod.visMode===2?"":""
            font.pointSize: Appearance.font.size.extraLarge*2
            color: Colours.alpha(Colours.palette.on_surface_variant,0.3)
        }
        StyledText  {
            Layout.alignment: Qt.AlignHCenter
            text: panelContainer.mod.isShiftPressed?"No favorites yet":panelContainer.mod.isAltPressed?"History is empty":panelContainer.mod.visMode===2?"No hidden wallpapers":"No wallpapers found"
            font.pointSize: Appearance.font.size.large
            color: Colours.palette.on_surface_variant
        }
        StyledText  {
            Layout.alignment: Qt.AlignHCenter
            text: panelContainer.mod.isShiftPressed?"Add with Ctrl+Shift+A":panelContainer.mod.isAltPressed?"Set a wallpaper first":panelContainer.mod.visMode===2?"Hide with Ctrl+Shift+H":"Try changing filters or query"
            font.pointSize: Appearance.font.size.small
            color: Colours.alpha(Colours.palette.on_surface_variant,0.6)
        }
    }

    // ── Carousel ──
    WallCarousel {
        anchors.fill: parent
        anchors.topMargin: Appearance.padding.medium
        anchors.bottomMargin: Appearance.padding.medium
        mod: panelContainer.mod
    }

    // Hint
    StyledText {
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 4
        text: "Hold[Alt]: History  •  Hold[Shift]: Favorites  •  [Ctrl+H]: Dot-files  •  [←→]: Navigate"
        font.pointSize: Appearance.font.size.smaller; color: Colours.alpha(Colours.palette.on_surface_variant, 0.5); z: 5
    }

    // ── Settings overlay ──
    WallSettingsView {
        anchors.fill: parent
        z: 20
        mod: panelContainer.mod
    }
}
