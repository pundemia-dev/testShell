pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Collapsible <think>…</think> block. Collapses once the assistant is done.
Item {
    id: root

    // Not `required`: instantiated via Loader + Binding push (MessageItem).
    property string segmentContent: ""
    required property bool done
    required property bool thinking
    // true once the closing </think> tag was found (segment is complete)
    property bool completed: false

    property bool collapsed: completed

    Layout.fillWidth: true
    implicitHeight: collapsed ? header.implicitHeight
                              : col.implicitHeight

    clip: true

    Behavior on implicitHeight {
        enabled: root.completed
        NumberAnimation {
            duration:    Appearance.anim.durations.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 0

        // ── Header ────────────────────────────────────────────────────
        StyledRect {
            id: header
            Layout.fillWidth: true
            radius: Appearance.rounding.small
            bottomLeftRadius:  root.collapsed ? Appearance.rounding.small
                                              : Appearance.rounding.extraSmall / 2
            bottomRightRadius: root.collapsed ? Appearance.rounding.small
                                              : Appearance.rounding.extraSmall / 2
            color: Colours.tPalette.surface_variant
            implicitHeight: headerRow.implicitHeight + Appearance.padding.small * 2

            Behavior on bottomLeftRadius  { Anim {} }
            Behavior on bottomRightRadius { Anim {} }

            StateLayer {
                color:    Colours.palette.on_surface
                disabled: !root.completed
                function onClicked(): void {
                    if (root.completed) root.collapsed = !root.collapsed
                }
            }

            RowLayout {
                id: headerRow
                anchors {
                    fill: parent
                    leftMargin:  Appearance.padding.medium
                    rightMargin: Appearance.padding.small
                    topMargin:   Appearance.padding.small
                    bottomMargin: Appearance.padding.small
                }
                spacing: Appearance.spacing.small

                // Animated dots while thinking
                LoadingIndicator {
                    visible:  !root.completed
                    implicitSize: Appearance.font.icon.small.pointSize
                    color:    Colours.palette.on_surface_variant
                }

                StyledText {
                    Layout.fillWidth: true
                    text:  root.completed ? "Thought" : "Thinking"
                    font:  Appearance.font.label.small
                    color: Colours.palette.on_surface_variant
                }

                StyledIcon {
                    visible: root.completed
                    text:    ""   // chevron-down
                    color:   Colours.palette.on_surface_variant
                    rotation: root.collapsed ? 0 : 180
                    Behavior on rotation { Anim {} }
                }
            }
        }

        // ── Body ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: root.collapsed ? 0 : bodyRect.implicitHeight + 2
            clip: true

            Behavior on implicitHeight {
                enabled: root.completed
                NumberAnimation {
                    duration:    Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            StyledRect {
                id: bodyRect
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                radius: Appearance.rounding.extraSmall / 2
                bottomLeftRadius:  Appearance.rounding.small
                bottomRightRadius: Appearance.rounding.small
                color: Colours.tPalette.surface_variant
                implicitHeight: bodyText.implicitHeight

                TextBlock {
                    id: bodyText
                    anchors { left: parent.left; right: parent.right }
                    segmentContent: root.segmentContent
                    done:     root.done
                    thinking: true      // always muted colour
                }
            }
        }
    }
}
