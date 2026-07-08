pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.config
import qs.services
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// OSD panel UI. Two core sliders (volume + brightness) that rotate + reflow with
// the panel's anchor orientation (like the translator): stacked vertical bars on
// a side edge, side-by-side horizontal bars on a top/bottom edge. Two hover
// buttons (audio / display) unfold an extra section that grows the background.
Item {
    id: root

    required property var monitor

    // Reported up to the wrapper for keep-alive.
    property bool panelHovered: false
    property string expandedSection: ""
    readonly property bool expanded: expandedSection.length > 0

    // Same anchor contract the translator uses.
    readonly property bool isHorizontal: Config.osd.anchors.horizontalCenter ?? false
    readonly property int barLen: Config.osd.sliderLength
    readonly property int barThick: Config.osd.sliderThickness
    readonly property bool hasBrightness: Config.osd.enableBrightness && !!monitor

    implicitWidth: outer.implicitWidth
    implicitHeight: outer.implicitHeight

    function setSection(s: string): void {
        expandedSection = s;
        collapseTimer.stop();
    }
    function requestCollapse(): void {
        collapseTimer.restart();
    }
    Timer {
        id: collapseTimer
        interval: 150
        onTriggered: root.expandedSection = ""
    }

    HoverHandler {
        onHoveredChanged: root.panelHovered = hovered
    }

    // ── Layout ─────────────────────────────────────────────────────────────
    // Outer places [core | expansion] along the CROSS axis: side panels grow
    // wider (expansion to the right), top/bottom panels grow taller (below).
    GridLayout {
        id: outer
        anchors.fill: parent
        columns: root.isHorizontal ? 1 : 2
        rowSpacing: Appearance.spacing.medium
        columnSpacing: Appearance.spacing.medium

        // ── Core strip ──────────────────────────────────────────────────
        // Order along the strip: audio trigger · volume · brightness · display
        // trigger — so each section button sits at the far edge next to its own
        // slider (audio above/left of volume, display below/right of brightness).
        GridLayout {
            id: core
            Layout.row: 0
            Layout.column: 0
            columns: root.isHorizontal ? 4 : 1
            rowSpacing: Appearance.spacing.small
            columnSpacing: Appearance.spacing.small

            SectionButton {
                Layout.alignment: Qt.AlignCenter
                icon: "\ueb51" // volume
                section: "audio"
            }

            Bar {
                Layout.alignment: Qt.AlignCenter
                icon: Icons.getVolumeIcon(value, Audio.muted)
                to: Config.osd.maxVolume
                value: Audio.volume
                onMovedFn: v => Audio.setVolume(v)
                onTapFn: () => Audio.toggleMute()
                onScrollUp: () => Audio.incrementVolume(0)
                onScrollDown: () => Audio.decrementVolume(0)
            }

            Bar {
                Layout.alignment: Qt.AlignCenter
                visible: root.hasBrightness
                icon: Icons.getBrightnessIcon(value)
                to: 1
                value: root.monitor?.brightness ?? 0
                onMovedFn: v => root.monitor?.setBrightness(v)
                onScrollUp: () => root.monitor?.setBrightness((root.monitor?.brightness ?? 0) + Config.osd.brightnessStep)
                onScrollDown: () => root.monitor?.setBrightness((root.monitor?.brightness ?? 0) - Config.osd.brightnessStep)
            }

            SectionButton {
                Layout.alignment: Qt.AlignCenter
                icon: "\ueb30" // sun
                section: "display"
                visible: root.hasBrightness
            }
        }

        // ── Expansion drawer ────────────────────────────────────────────
        Item {
            id: expansion
            Layout.row: root.isHorizontal ? 1 : 0
            Layout.column: root.isHorizontal ? 0 : 1
            Layout.fillWidth: root.isHorizontal
            Layout.fillHeight: !root.isHorizontal
            clip: true

            readonly property int target: Config.osd.expansionSize

            Layout.preferredWidth: root.isHorizontal ? -1 : (root.expanded ? target : 0)
            Layout.preferredHeight: root.isHorizontal ? (root.expanded ? target : 0) : -1
            opacity: root.expanded ? 1 : 0
            visible: (root.isHorizontal ? Layout.preferredHeight : Layout.preferredWidth) > 0

            Behavior on Layout.preferredWidth {
                Anim { type: Anim.Emphasized }
            }
            Behavior on Layout.preferredHeight {
                Anim { type: Anim.Emphasized }
            }
            Behavior on opacity {
                Anim {}
            }

            HoverHandler {
                onHoveredChanged: hovered ? root.setSection(root.expandedSection) : root.requestCollapse()
            }

            VerticalFadeFlickable {
                anchors.fill: parent
                contentHeight: sectionCol.implicitHeight

                ColumnLayout {
                    id: sectionCol
                    width: expansion.width
                    spacing: Appearance.spacing.medium

                    // ── Audio ──────────────────────────────────────────
                    FilledSlider {
                        Layout.fillWidth: true
                        implicitHeight: root.barThick
                        visible: root.expandedSection === "audio" && Config.osd.enableMicrophone
                        orientation: Qt.Horizontal
                        icon: Icons.getMicVolumeIcon(value, Audio.sourceMuted)
                        to: Config.osd.maxVolume
                        value: Audio.sourceVolume
                        onMoved: Audio.setSourceVolume(value)
                        onIconTapped: () => Audio.toggleSourceMute()
                    }

                    DeviceSelector {
                        Layout.fillWidth: true
                        visible: root.expandedSection === "audio"
                        title: qsTr("Output")
                        icon: "\uea8b" // speaker
                        nodes: Audio.sinks
                        current: Audio.sink
                        setNode: n => Audio.setAudioSink(n)
                        menuHost: dropdownHost
                    }

                    DeviceSelector {
                        Layout.fillWidth: true
                        visible: root.expandedSection === "audio"
                        title: qsTr("Input")
                        icon: "\ueaf0" // microphone
                        nodes: Audio.sources
                        current: Audio.source
                        setNode: n => Audio.setAudioSource(n)
                        menuHost: dropdownHost
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.expandedSection === "audio" && Config.osd.showPerAppStreams && Audio.streams.length > 0
                        text: qsTr("Applications")
                        font: Appearance.font.label.large
                        color: Colours.palette.on_surface_variant
                    }
                    Repeater {
                        model: root.expandedSection === "audio" && Config.osd.showPerAppStreams ? Audio.streams : []
                        StreamRow {
                            required property var modelData
                            Layout.fillWidth: true
                            stream: modelData
                        }
                    }

                    // ── Display ─────────────────────────────────────────
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.expandedSection === "display"
                        text: qsTr("Brightness")
                        font: Appearance.font.label.large
                        color: Colours.palette.on_surface_variant
                    }
                    Repeater {
                        model: root.expandedSection === "display" ? Brightness.monitors : []
                        ColumnLayout {
                            id: monRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small / 2

                            StyledText {
                                Layout.fillWidth: true
                                text: monRow.modelData.modelData.name
                                elide: Text.ElideRight
                                font: Appearance.font.label.medium
                                color: Colours.palette.on_surface_variant
                            }
                            FilledSlider {
                                Layout.fillWidth: true
                                implicitHeight: root.barThick
                                orientation: Qt.Horizontal
                                icon: Icons.getBrightnessIcon(value)
                                to: 1
                                value: monRow.modelData.brightness
                                onMoved: monRow.modelData.setBrightness(value)
                            }
                        }
                    }
                }
            }
        }
    }

    // Dropdown host for the DeviceSelector menus (pointer events only reach
    // items within their ancestors' bounds in layershell panels).
    Item {
        id: dropdownHost
        anchors.fill: parent
        z: 100
    }

    // ── Local components ─────────────────────────────────────────────────────
    // A wheel-scrollable core slider that rotates with the panel.
    component Bar: CustomMouseArea {
        id: bar

        property string icon
        property real value
        property real to: 1
        property var onMovedFn
        property var onTapFn: null
        property var onScrollUp
        property var onScrollDown

        acceptedButtons: Qt.NoButton
        implicitWidth: root.isHorizontal ? root.barLen : root.barThick
        implicitHeight: root.isHorizontal ? root.barThick : root.barLen

        function onWheel(event: WheelEvent): void {
            if (event.angleDelta.y > 0)
                bar.onScrollUp();
            else if (event.angleDelta.y < 0)
                bar.onScrollDown();
        }

        FilledSlider {
            anchors.fill: parent
            orientation: root.isHorizontal ? Qt.Horizontal : Qt.Vertical
            icon: bar.icon
            from: 0
            to: bar.to
            value: bar.value
            onMoved: bar.onMovedFn(value)
            onIconTapped: bar.onTapFn
        }
    }

    // A hover trigger that unfolds its section.
    component SectionButton: StyledRect {
        id: sbtn

        property string icon
        property string section

        implicitWidth: root.barThick
        implicitHeight: root.barThick
        radius: Appearance.rounding.full
        color: active ? Colours.palette.secondary_container : Colours.palette.surface_container_high

        readonly property bool active: root.expandedSection === section

        StyledIcon {
            anchors.centerIn: parent
            text: sbtn.icon
            color: sbtn.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant
            font.pointSize: Appearance.font.icon.small.pointSize
        }

        HoverHandler {
            onHoveredChanged: hovered ? root.setSection(sbtn.section) : root.requestCollapse()
        }
    }
}
