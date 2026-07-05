import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.components.controls
import qs.components.containers

// Settings-таб Keys: статичная шпаргалка по шорткатам модуля.
StyledFlickable {
    id: keysScroll

    contentWidth: width; contentHeight: keysCol.height; clip: true
    ColumnLayout {
        id: keysCol
        width: parent.width; spacing: Appearance.spacing.small

        SectionHeader { title: "Navigation" }
        PropertyRow { label:"← / → (↑ / ↓)";    value:"Navigate carousel" }
        PropertyRow { label:"Enter";               value:"Apply wallpaper" }
        PropertyRow { label:"Esc";                 value:"Cancel and close" }
        PropertyRow { label:"Alt+Enter";           value:"Apply in Stretch mode" }

        SectionHeader { title: "Settings & Modes" }
        PropertyRow { label:"Ctrl+I";  value:"Open / close settings" }
        PropertyRow { label:"Ctrl+M";  value:"Toggle dark / light" }
        PropertyRow { label:"Ctrl+T";  value:"Next palette scheme" }
        PropertyRow { label:"Ctrl+H";  value:"Cycle dot-file modes: normal → include → only" }
        PropertyRow { label:"Ctrl+R";  value:"Set random wallpaper" }
        PropertyRow { label:"Ctrl+G";  value:"Toggle Game Mode" }

        SectionHeader { title: "Favorites & Hidden" }
        PropertyRow { label:"Ctrl+Shift+A"; value:"Add to favorites" }
        PropertyRow { label:"Ctrl+Shift+D"; value:"Remove from favorites" }
        PropertyRow { label:"Ctrl+Shift+H"; value:"Toggle hidden status (.filename)" }

        SectionHeader { title: "History" }
        PropertyRow { label:"Ctrl+["; value:"Previous wallpaper in history" }
        PropertyRow { label:"Ctrl+]"; value:"Next wallpaper in history" }

        SectionHeader { title: "View Modes (Hold)" }
        PropertyRow { label:"Alt (hold)";   value:"Show history" }
        PropertyRow { label:"Shift (hold)"; value:"Show favorites" }

        SectionHeader { title: "In Favorites mode" }
        PropertyRow { label:"Shift+Ctrl+D (hold Shift)"; value:"Remove and hide item immediately" }

        Item { Layout.preferredHeight: Appearance.padding.large }
    }
    StyledScrollBar { flickable: keysScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
}
