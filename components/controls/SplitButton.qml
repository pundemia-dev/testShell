import ".."
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Row {
    id: root

    enum Type {
        Filled,
        Tonal
    }

    property real horizontalPadding: Appearance.padding.medium
    property real verticalPadding: Appearance.padding.small
    property int type: SplitButton.Filled
    property bool disabled
    property bool menuOnTop
    property string fallbackIcon
    property string fallbackText

    // Optional overlay item the dropdown is reparented into. Pointer events
    // never reach items placed outside their ancestors' bounds inside the
    // layershell panels (the menu renders but is unpickable), so a host that
    // CONTAINS the dropdown area (e.g. the page root) must be provided there.
    // Null keeps the legacy in-tree anchoring (regular windows are fine).
    property Item menuHost: null

    property alias menuItems: menu.items
    property alias active: menu.active
    property alias expanded: menu.expanded
    property alias menu: menu
    property alias iconLabel: iconLabel
    property alias label: label
    property alias stateLayer: stateLayer

    property color colour: type == SplitButton.Filled ? Colours.palette.primary : Colours.palette.secondary_container
    property color textColour: type == SplitButton.Filled ? Colours.palette.on_primary : Colours.palette.on_secondary_container
    property color disabledColour: Qt.alpha(Colours.palette.on_surface, 0.1)
    property color disabledTextColour: Qt.alpha(Colours.palette.on_surface, 0.38)

    spacing: Math.floor(Appearance.spacing.small / 2)

    StyledRect {
        radius: implicitHeight / 2// * Math.min(1, Appearance.rounding.scale)
        topRightRadius: Appearance.rounding.small / 2
        bottomRightRadius: Appearance.rounding.small / 2
        color: root.disabled ? root.disabledColour : root.colour

        implicitWidth: textRow.implicitWidth + root.horizontalPadding * 2
        implicitHeight: expandBtn.implicitHeight

        StateLayer {
            id: stateLayer

            rect.topRightRadius: parent.topRightRadius
            rect.bottomRightRadius: parent.bottomRightRadius
            color: root.textColour
            disabled: root.disabled

            function onClicked(): void {
                root.active?.clicked();
            }
        }

        RowLayout {
            id: textRow

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: Math.floor(root.verticalPadding / 4)
            spacing: Appearance.spacing.small

            StyledIcon {
                id: iconLabel

                Layout.alignment: Qt.AlignVCenter
                animate: true
                text: root.active?.activeIcon ?? root.fallbackIcon
                color: root.disabled ? root.disabledTextColour : root.textColour
                fill: 1
            }

            StyledText {
                id: label

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: implicitWidth
                animate: true
                text: root.active?.activeText ?? root.fallbackText
                color: root.disabled ? root.disabledTextColour : root.textColour
                clip: true

                Behavior on Layout.preferredWidth {
                    Anim {
                        easing.bezierCurve: Appearance.anim.curves.emphasized
                    }
                }
            }
        }
    }

    StyledRect {
        id: expandBtn

        // property real rad: root.expanded ? implicitHeight / 2 * Math.min(1, Appearance.rounding.scale) : Appearance.rounding.small / 2
        property real rad: root.expanded ? implicitHeight / 2 : Appearance.rounding.small / 2 //Appearance.rounding.scale) : Appearance.rounding.small / 2

        radius: implicitHeight / 2// * Math.min(1, Appearance.rounding.scale)
        topLeftRadius: rad
        bottomLeftRadius: rad
        color: root.disabled ? root.disabledColour : root.colour

        implicitWidth: implicitHeight
        implicitHeight: expandIcon.implicitHeight + root.verticalPadding * 2

        StateLayer {
            id: expandStateLayer

            rect.topLeftRadius: parent.topLeftRadius
            rect.bottomLeftRadius: parent.bottomLeftRadius
            color: root.textColour
            disabled: root.disabled

            function onClicked(): void {
                root.expanded = !root.expanded;
            }
        }

        StyledIcon {
            id: expandIcon

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.expanded ? 0 : -Math.floor(root.verticalPadding / 4)

            text: "\uea5f" //"expand_more"
            color: root.disabled ? root.disabledTextColour : root.textColour
            rotation: root.expanded ? 180 : 0

            Behavior on anchors.horizontalCenterOffset {
                Anim {}
            }

            Behavior on rotation {
                Anim {}
            }
        }

        Behavior on rad {
            Anim {}
        }

        Menu {
            id: menu

            parent: root.menuHost ?? expandBtn

            // In-tree (legacy) anchoring, disabled when hosted.
            anchors.top: root.menuHost ? undefined
                : (root.menuOnTop ? undefined : expandBtn.bottom)
            anchors.bottom: root.menuHost ? undefined
                : (root.menuOnTop ? expandBtn.top : undefined)
            anchors.right: root.menuHost ? undefined : expandBtn.right
            anchors.topMargin: Appearance.spacing.small
            anchors.bottomMargin: Appearance.spacing.small

            // Hosted positioning: computed in host coordinates and clamped to
            // the host's bounds so the whole dropdown stays pickable.
            readonly property point _btnOrigin: {
                if (!root.menuHost)
                    return Qt.point(0, 0);
                void root.menuHost.width;
                void root.menuHost.height;
                void expandBtn.x;
                void expandBtn.y;
                return expandBtn.mapToItem(root.menuHost, 0, 0);
            }
            x: root.menuHost
                ? Math.max(0, Math.min(_btnOrigin.x + expandBtn.width - width,
                                       root.menuHost.width - width))
                : 0
            y: {
                if (!root.menuHost)
                    return 0;
                const gap = Appearance.spacing.small;
                const target = root.menuOnTop
                    ? _btnOrigin.y - height - gap
                    : _btnOrigin.y + expandBtn.height + gap;
                return Math.max(0, Math.min(target, root.menuHost.height - height));
            }
        }
    }
}
