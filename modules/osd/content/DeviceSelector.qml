pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.config
import qs.services
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// A labelled output/input device picker. Wraps SplitButton (same control the
// translator uses) over a PwNode list, writing the choice back through the
// provided setter.
ColumnLayout {
    id: root

    required property string title
    required property string icon
    required property var nodes        // list<PwNode>
    required property var current      // PwNode
    required property var setNode      // function(PwNode)
    required property Item menuHost

    spacing: Appearance.spacing.small / 2

    readonly property var _model: [...nodes].map(n => ({ text: Audio.deviceName(n), value: n.id, icon: root.icon }))

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledIcon {
            text: root.icon
            color: Colours.palette.on_surface_variant
            font.pointSize: Appearance.font.icon.small.pointSize
        }
        StyledText {
            Layout.fillWidth: true
            text: root.title
            elide: Text.ElideRight
            font: Appearance.font.label.large
            color: Colours.palette.on_surface_variant
        }
    }

    SplitButton {
        id: picker
        Layout.fillWidth: true
        type: SplitButton.Tonal
        fallbackIcon: root.icon
        fallbackText: Audio.deviceName(root.current)
        menuHost: root.menuHost
        stateLayer.disabled: true

        menu.model: root._model
        menu.maxHeight: 240
        active: root._model.find(it => it.value === root.current?.id) ?? root._model[0]

        Connections {
            target: picker.menu
            function onItemSelected(item): void {
                if (!item)
                    return;
                const node = root.nodes.find(n => n.id === item.value);
                if (node)
                    root.setNode(node);
            }
        }
    }
}
