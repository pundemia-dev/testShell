pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// Ported from caelestia sidebar/Notif: one notification row inside an app
// group. Collapsed shows "summary  body-preview" on a single line; expanded
// grows into a card with time, markdown body and the action pill strip.
StyledRect {
    id: root

    required property var modelData
    required property bool expanded

    readonly property StyledText body: (expandedContent.item as ExpandedBody)?.body ?? null
    readonly property real nonAnimHeight: expanded ? summary.implicitHeight + expandedContent.implicitHeight + expandedContent.anchors.topMargin + Appearance.padding.medium * 2 : summaryHeightMetrics.height

    implicitHeight: nonAnimHeight

    radius: Appearance.rounding.medium
    color: {
        const c = root.modelData?.urgency === NotificationUrgency.Critical ? Colours.palette.secondary_container : Colours.layer(Colours.palette.surface_container_high, 2);
        return expanded ? c : Qt.alpha(c, 0);
    }

    state: expanded ? "expanded" : ""

    states: State {
        name: "expanded"

        PropertyChanges {
            summary.anchors.margins: Appearance.padding.medium
            dummySummary.anchors.margins: Appearance.padding.medium
            compactBody.anchors.margins: Appearance.padding.medium
            timeStr.anchors.margins: Appearance.padding.medium
            expandedContent.anchors.margins: Appearance.padding.medium
            summary.width: root.width - Appearance.padding.medium * 2 - timeStr.implicitWidth - Appearance.spacing.small
            summary.maximumLineCount: Number.MAX_SAFE_INTEGER
        }
    }

    transitions: Transition {
        Anim {
            properties: "margins,width,maximumLineCount"
        }
    }

    TextMetrics {
        id: summaryHeightMetrics

        font: summary.font
        text: " " // Use this height to prevent weird characters from changing the line height
    }

    StyledText {
        id: summary

        anchors.top: parent.top
        anchors.left: parent.left

        width: parent.width
        text: root.modelData?.summary ?? ""
        color: root.modelData?.urgency === NotificationUrgency.Critical ? Colours.palette.on_secondary_container : Colours.palette.on_surface
        elide: Text.ElideRight
        wrapMode: Text.WordWrap
        maximumLineCount: 1
    }

    StyledText {
        id: dummySummary

        anchors.top: parent.top
        anchors.left: parent.left

        visible: false
        text: root.modelData?.summary ?? ""
    }

    WrappedLoader {
        id: compactBody

        shouldBeActive: !root.expanded
        anchors.top: parent.top
        anchors.left: dummySummary.right
        anchors.right: parent.right
        anchors.leftMargin: Appearance.spacing.small

        sourceComponent: StyledText {
            text: String(root.modelData?.body ?? "").replace(/\n/g, " ")
            color: root.modelData?.urgency === NotificationUrgency.Critical ? Colours.palette.secondary : Colours.palette.outline
            elide: Text.ElideRight
        }
    }

    WrappedLoader {
        id: timeStr

        shouldBeActive: root.expanded
        anchors.top: parent.top
        anchors.right: parent.right

        sourceComponent: StyledText {
            animate: true
            text: root.modelData?.timeStr ?? ""
            color: Colours.palette.outline
            font: Appearance.font.body.small
        }
    }

    WrappedLoader {
        id: expandedContent

        shouldBeActive: root.expanded
        anchors.top: summary.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Appearance.spacing.extraSmall

        sourceComponent: ExpandedBody {}
    }

    Behavior on implicitHeight {
        Anim {}
    }

    component ExpandedBody: ColumnLayout {
        readonly property alias body: bodyText

        spacing: Appearance.spacing.medium

        StyledText {
            id: bodyText

            Layout.fillWidth: true
            textFormat: Text.MarkdownText
            text: String(root.modelData?.body ?? "").replace(/(.)\n(?!\n)/g, "$1\n\n") || qsTr("No body here! :/")
            color: root.modelData?.urgency === NotificationUrgency.Critical ? Colours.palette.secondary : Colours.palette.outline
            wrapMode: Text.WordWrap

            onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
        }

        NotifActionList {
            notif: root.modelData
        }
    }

    component WrappedLoader: Loader {
        id: comp

        required property bool shouldBeActive

        active: false
        opacity: 0

        // Makes the loader load on the same frame shouldBeActive becomes true, which ensures size is set
        states: State {
            name: "active"
            when: comp.shouldBeActive

            PropertyChanges {
                comp.opacity: 1
                comp.active: true
            }
        }

        transitions: [
            Transition {
                from: ""
                to: "active"

                SequentialAnimation {
                    PropertyAction {
                        property: "active"
                    }
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                    }
                }
            },
            Transition {
                from: "active"
                to: ""

                SequentialAnimation {
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                    }
                    PropertyAction {
                        property: "active"
                    }
                }
            }
        ]
    }
}
