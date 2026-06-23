import QtQuick

QtObject {
    property string text: ""
    property string icon
    property string trailingIcon
    property string trailingText
    property string activeIcon: icon
    property string activeText: text

    // Non-interactive divider row (label/icon ignored).
    property bool separator: false
    // Optional payload for model-driven menus (e.g. ValueSelector reads it back).
    property var value

    signal clicked
}
