pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import Quickshell.Io
import QtQuick

// Recording top-panel content (the rails slot paints the blob background;
// panel height matches the bar). A Loader swaps the two states — the slot
// measures childrenRect, so only the ACTIVE state may contribute geometry,
// otherwise the pill never shrinks back to its content:
//   pending   — audio chooser: Без звука / Система / Микрофон / Оба + cancel;
//               recording starts only when a chip is clicked here.
//   recording — pulsing dot + bold tabular timer + red cava visualizer +
//               stop; trash / audio source / pause slide out of the stop
//               button on hover (single hover container = walkable bridge).
Item {
    id: root

    // Both axes derive from the active state's content (the rails slot is sized
    // bar-height by the wrapper and centres this content in it). Must NOT bind
    // height to parent.height: the WindowSlot Loader is size-less and adopts
    // this item's implicit size, so parent.height → 0 (circular).
    implicitWidth: view.item ? view.item.implicitWidth : 0
    implicitHeight: view.item ? view.item.implicitHeight : 0

    property int elapsed: 0
    property var levels: []

    Timer {
        interval: 1000
        running: Capture.recording && !Capture.recordPaused
        repeat: true
        triggeredOnStart: true
        onTriggered: root.elapsed = Math.max(0, Math.floor((Capture.recordPausedAccum + Date.now() - Capture.recordStartedAt) / 1000))
    }

    // ── Audio visualizer source (cava, raw ascii on stdout) ─────────
    readonly property int vizBars: 12

    // Single source of truth: the record script writes the EXACT device it is
    // capturing to "<file>.vizsource" on every (re)started segment — including
    // live audio switches (USR2) and the both-mode mix sink. The supervisor
    // below polls that file, validates the device is actually present, and
    // (re)binds cava to it; nothing is duplicated/guessed here, so the viz can
    // no longer drift from what's being recorded or cling to a stale "auto".
    function cavaCommand(file: string): var {
        const vf = file + ".vizsource";
        const script = `vf='${vf}'
cfg="$(mktemp /tmp/pshell_cava.XXXXXX)"
c=""
prev=""
trap 'kill "$c" 2>/dev/null; rm -f "$cfg"; exit 0' INT TERM
while :; do
    src="$(cat "$vf" 2>/dev/null)"
    # Only bind to a device that exists right now — otherwise wait (no auto).
    if [ -n "$src" ] && ! pactl list short sources 2>/dev/null | grep -qF -- "$src"; then
        src=""
    fi
    if [ "$src" != "$prev" ] || { [ -n "$src" ] && ! kill -0 "$c" 2>/dev/null; }; then
        kill "$c" 2>/dev/null
        c=""
        prev="$src"
        if [ -n "$src" ]; then
            printf '[general]\\nbars = ${vizBars}\\nframerate = 30\\n[input]\\nmethod = pulse\\nsource = %s\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 100\\nbar_delimiter = 59\\n' "$src" > "$cfg"
            cava -p "$cfg" &
            c=$!
        fi
    fi
    sleep 0.3
done`;

        return ["bash", "-c", script];
    }

    Process {
        id: cavaProc

        // Bound to the stable per-recording file: a live audio switch keeps the
        // same process alive (it re-reads vizsource), so there's no QML restart
        // race. Only a none↔audio toggle flips `running`.
        running: Capture.recording && Capture.recordAudio !== "none"
        command: root.cavaCommand(Capture.recordFile)

        stdout: SplitParser {
            onRead: data => {
                root.levels = data.split(";").filter(s => s !== "").map(Number);
            }
        }
    }

    // Only the active state exists in the tree (childrenRect measurement).
    Loader {
        id: view

        // Centred in the full-height root; the rails slot manages the outer
        // placement of the pill itself.
        anchors.centerIn: parent
        sourceComponent: Capture.recordPending ? pendingC : Capture.recording ? recC : null
    }

    // ── Pending: audio chooser ──────────────────────────────────────
    Component {
        id: pendingC

        Row {
            spacing: Appearance.spacing.small

            Repeater {
                model: [
                    {
                        v: "none",
                        label: "No sound"
                    },
                    {
                        v: "system",
                        label: "System"
                    },
                    {
                        v: "mic",
                        label: "Mic"
                    },
                    {
                        v: "both",
                        label: "Both"
                    }
                ]

                StyledRect {
                    id: audioChip

                    required property var modelData

                    readonly property bool preselected: Capture.resolveRecordAudio() === modelData.v

                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: chipLabel.implicitWidth + Appearance.padding.normal * 2
                    implicitHeight: chipLabel.implicitHeight + Appearance.padding.small * 2
                    radius: Appearance.rounding.full
                    color: preselected ? Colours.palette.primary : Colours.palette.surface_container_high

                    StyledText {
                        id: chipLabel

                        anchors.centerIn: parent
                        text: audioChip.modelData.label
                        color: audioChip.preselected ? Colours.palette.on_primary : Colours.palette.on_surface_variant
                    }

                    StateLayer {
                        color: audioChip.preselected ? Colours.palette.on_primary : Colours.palette.on_surface

                        function onClicked(): void {
                            Capture.startPending(audioChip.modelData.v);
                        }
                    }
                }
            }

            TablerButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "" // x
                fg: Colours.palette.on_surface_variant
                iconSize: Appearance.font.size.normal
                onClicked: Capture.cancelPending()
            }
        }
    }

    // ── Recording row ───────────────────────────────────────────────
    Component {
        id: recC

        Row {
            spacing: Appearance.spacing.smaller

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.font.size.small
                height: width
                radius: width / 2
                color: Capture.recordPaused ? Colours.palette.on_surface_variant : Colours.palette.error
                opacity: Capture.recordPaused ? 0.6 : 1

                SequentialAnimation on opacity {
                    running: Capture.recording && !Capture.recordPaused
                    loops: Animation.Infinite

                    Anim {
                        to: 0.25
                        duration: Appearance.anim.durations.large
                    }
                    Anim {
                        to: 1
                        duration: Appearance.anim.durations.large
                    }
                }
            }

            // Width pinned to the metrics of the same digit COUNT in zeros:
            // it only changes on minute-digit rollover, never per second
            // (tnum alone didn't help — the font has no tabular figures).
            StyledText {
                id: timeText

                anchors.verticalCenter: parent.verticalCenter
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.larger
                font.weight: Font.Bold
                color: Colours.palette.on_surface
                width: Math.ceil(timeMetrics.advanceWidth)
                horizontalAlignment: Text.AlignHCenter
                text: {
                    const m = Math.floor(root.elapsed / 60);
                    const s = root.elapsed % 60;
                    return `${m}:${s.toString().padStart(2, "0")}`;
                }

                TextMetrics {
                    id: timeMetrics

                    font: timeText.font
                    text: timeText.text.replace(/[0-9]/g, "0")
                }
            }

            // ── Audio visualizer (red bars fed by cava) ─────────────
            Row {
                anchors.verticalCenter: parent.verticalCenter
                // Integer geometry: fractional bar widths/spacings made the
                // Row reflow at sub-pixel boundaries on every level update.
                spacing: Math.max(1, Math.round(Appearance.spacing.small / 3))
                leftPadding: Appearance.spacing.small
                rightPadding: Appearance.spacing.small
                visible: Capture.recordAudio !== "none"
                opacity: Capture.recordPaused ? 0.35 : 1

                Repeater {
                    model: root.vizBars

                    Item {
                        required property int index

                        width: Math.round(Appearance.padding.small / 2) + 1
                        height: Appearance.font.size.large

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            radius: width / 2
                            color: Colours.palette.error
                            height: Math.max(width, Math.min(1, (root.levels[parent.index] ?? 0) / 100) * parent.height)

                            Behavior on height {
                                Anim {
                                    duration: Appearance.anim.durations.smaller
                                }
                            }
                        }
                    }
                }
            }

            // ── Controls: trash / audio / pause / stop, ALWAYS visible.
            // No hover-reveal: resizing the pill on hover fought the rails
            // size-spring (resize → re-centre → scale ring) and dropped the
            // hover → oscillation. A stable footprint keeps every button
            // reachable and the pill calm.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacing.small

                            TablerButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "" // trash
                                color: Colours.palette.surface_container_high
                                fg: Colours.palette.error
                                iconSize: Appearance.font.size.normal
                                onClicked: Capture.discardRecord()
                            }

                            TablerButton {
                                anchors.verticalCenter: parent.verticalCenter
                                color: Colours.palette.secondary_container
                                fg: Colours.palette.on_secondary_container
                                iconSize: Appearance.font.size.normal
                                icon: {
                                    switch (Capture.recordAudio) {
                                    case "system":
                                        return ""; // volume
                                    case "mic":
                                        return "";    // microphone
                                    case "both":
                                        return "";   // headset
                                    default:
                                        return "";       // volume-off
                                    }
                                }
                                onClicked: {
                                    const order = ["none", "system", "mic", "both"];
                                    const next = order[(order.indexOf(Capture.recordAudio) + 1) % order.length];
                                    Capture.setRecordAudio(next);
                                }
                            }

                            TablerButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: Capture.recordPaused ? "" : "" // play / pause
                                color: Colours.palette.secondary_container
                                fg: Colours.palette.on_secondary_container
                                iconSize: Appearance.font.size.normal
                                onClicked: Capture.togglePause()
                            }

                            TablerButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "" // player-stop-filled
                        color: Colours.palette.error_container
                        fg: Colours.palette.on_error_container
                        iconSize: Appearance.font.size.normal
                        onClicked: Capture.stopRecord()
                    }
            }
        }
    }
}
