import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.components.controls
import qs.components.images
import qs.components.containers
import qs.services
import Quickshell

// Правая панель модуля Applications: иконка + описание выбранного приложения
// и переключатели pin/hide. `mod` — инстанс AppsModule.
Item {
    id: panelRoot
    anchors.fill: parent

    required property var mod

    property var displayedApp: mod.selectedApp

    Connections {
        target: panelRoot.mod
        function onSelectedAppChanged() { fadeOut.start() }
    }

    SequentialAnimation {
        id: fadeOut
        ParallelAnimation {
            Anim { target: content; property: "opacity"; to: 0; duration: Appearance.anim.durations.small }
            Anim { target: content; property: "scale";   to: 0.97; duration: Appearance.anim.durations.small }
        }
        ScriptAction {
            script: { panelRoot.displayedApp = panelRoot.mod.selectedApp; fadeIn.start() }
        }
    }

    ParallelAnimation {
        id: fadeIn
        Anim { target: content; property: "opacity"; to: 1; duration: Appearance.anim.durations.small }
        Anim { target: content; property: "scale";   to: 1; duration: Appearance.anim.durations.small }
    }

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        width: parent.width - Appearance.padding.large * 2
        spacing: 12
        transformOrigin: Item.Center

        // ── Иконка + заголовок ────────────────────────────────────────
        CachingIconImage {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 128
            Layout.preferredHeight: 128
            source: panelRoot.displayedApp
                ? Quickshell.iconPath(panelRoot.displayedApp.icon, "application-x-executable")
                : ""
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: panelRoot.displayedApp?.name ?? ""
            font.pointSize: Appearance.font.size.large
            font.weight: Font.DemiBold
            color: Colours.palette.primary
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: panelRoot.displayedApp?.comment || panelRoot.displayedApp?.genericName || ""
            font.pointSize: Appearance.font.size.small
            color: Colours.alpha(Colours.palette.on_surface, 0.5)
            visible: text !== ""
        }

        // ── Настройки ─────────────────────────────────────────────────
        SectionContainer {
            Layout.fillWidth: true

            SwitchRow {
                label: "Pin app"
                checked: panelRoot.mod.isPinned
                onToggled: function() { panelRoot.mod.togglePin() }
                tooltip: "Ctrl+P"
                icon: panelRoot.mod.isPinned ? "" : ""
                color: "transparent"
                paddings: 0
            }

            SwitchRow {
                label: "Hide app"
                checked: panelRoot.mod.isHidden
                onToggled: function() { panelRoot.mod.toggleHide() }
                tooltip: "Ctrl+H"
                icon: panelRoot.mod.isHidden ? "" : ""
                color: "transparent"
                paddings: 0
            }
        }
    }
}
