pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import QtQuick
import QtQuick.Layouts

// Config.toasts → modules/toasts/config/ToastsConfig.qml
// Global toast behaviour + a DYNAMIC per-source mute tree built from
// ToastRegistry.sources (no hardcoded categories). Each registered ToastSource
// shows up as a section; a source nested under a module (parentId) renders as a
// child block with its own master toggle. Within a source you can mute by
// severity group (Errors / Other notifications) or per individual notification
// (advanced). Everything writes into Config.toasts.overrides via Toaster.
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // ── Position helpers (corner presets → rails anchor booleans) ───────────
    readonly property string currentPos: {
        const a = Config.toasts.anchors;
        const v = a.bottom ? "bottom" : "top";
        if (a.horizontalCenter)
            return v + "-center";
        const h = a.left ? "left" : "right";
        return v + "-" + h;
    }
    function setPos(pos: string): void {
        const a = Config.toasts.anchors;
        const parts = pos.split("-");
        const v = parts[0];
        const h = parts[1];
        a.top = v === "top";
        a.bottom = v === "bottom";
        a.left = h === "left";
        a.right = h === "right";
        a.horizontalCenter = h === "center";
        a.verticalCenter = false;
    }

    // ── Source tree (module nodes + standalone sources) ─────────────────────
    readonly property var groups: {
        const srcs = ToastRegistry.sources ?? [];
        const childrenOf = ({});
        for (const s of srcs)
            if (s.parentId)
                (childrenOf[s.parentId] = childrenOf[s.parentId] ?? []).push(s);

        const out = [];
        const seenModule = ({});
        // Module nodes (anything referenced as a parentId), synthesised if the
        // module itself never registered a source.
        for (const s of srcs) {
            if (s.parentId && !seenModule[s.parentId]) {
                seenModule[s.parentId] = true;
                const node = srcs.find(x => x.sourceId === s.parentId);
                out.push({
                    id: s.parentId,
                    label: node?.label ?? s.parentId,
                    icon: node?.icon ?? "",
                    isModule: true,
                    self: null,
                    children: childrenOf[s.parentId] ?? []
                });
            }
        }
        // Standalone sources (no parent, and not themselves a module node).
        for (const s of srcs)
            if (!s.parentId && !seenModule[s.sourceId])
                out.push({
                    id: s.sourceId,
                    label: s.label,
                    icon: s.icon || "",
                    isModule: false,
                    self: s,
                    children: []
                });

        out.sort((a, b) => String(a.label).localeCompare(String(b.label)));
        return out;
    }

    // Position preset pills (reused from the OsdPage pattern).
    component PillRow: Flow {
        id: pillRow
        property var model: []
        property string current: ""
        signal picked(string key)

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Repeater {
            model: pillRow.model
            delegate: StyledRect {
                id: pill
                required property var modelData
                readonly property bool active: pillRow.current === modelData.key

                implicitWidth: pillLabel.implicitWidth + Appearance.padding.medium * 2
                implicitHeight: pillLabel.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.small
                color: active ? Colours.palette.secondary_container : Colours.palette.surface_container_high

                StyledText {
                    id: pillLabel
                    anchors.centerIn: parent
                    text: pill.modelData.label
                    font.pointSize: Appearance.font.size.small
                    color: pill.active ? Colours.palette.on_secondary_container : Colours.palette.on_surface_variant
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pillRow.picked(pill.modelData.key)
                }
            }
        }
    }

    // Leaf controls for one source: master + severity groups + per-notification.
    component SourceBlock: ColumnLayout {
        id: sb
        required property var src
        property bool parentEnabled: true

        readonly property string sid: sb.src.sourceId
        readonly property bool selfEnabled: Toaster.flag(sb.sid, "enabled")
        readonly property var notifs: sb.src.notifications ?? []
        readonly property bool hasErr: sb.notifs.some(n => n.severity === "error")
        readonly property bool hasOther: sb.notifs.some(n => n.severity !== "error")

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        SwitchRow {
            label: qsTr("Enabled")
            checked: sb.selfEnabled
            enabled: sb.parentEnabled
            onToggled: c => Toaster.setOverride(sb.sid, "enabled", c)
        }
        SwitchRow {
            visible: sb.hasErr
            label: qsTr("Errors")
            checked: Toaster.flag(sb.sid, "errors")
            enabled: sb.parentEnabled && sb.selfEnabled
            onToggled: c => Toaster.setOverride(sb.sid, "errors", c)
        }
        SwitchRow {
            visible: sb.hasOther
            label: qsTr("Other notifications")
            checked: Toaster.flag(sb.sid, "others")
            enabled: sb.parentEnabled && sb.selfEnabled
            onToggled: c => Toaster.setOverride(sb.sid, "others", c)
        }
        Repeater {
            model: sb.notifs
            delegate: SwitchRow {
                required property var modelData
                visible: Config.general.advanced
                label: modelData.label ?? modelData.id
                checked: Toaster.notifFlag(sb.sid, modelData.id)
                enabled: sb.parentEnabled && sb.selfEnabled
                onToggled: c => Toaster.setNotifOverride(sb.sid, modelData.id, c)
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Appearance.spacing.medium

        StyledText {
            text: qsTr("Toasts")
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.DemiBold
            color: Colours.palette.on_surface
            Layout.fillWidth: true
        }

        // ── General ───────────────────────────────────────────────────────
        SettingSection {
            title: qsTr("General")
            icon: "\uea35" // tabler bell

            SwitchRow {
                label: qsTr("Enabled")
                checked: Config.toasts.enabled
                onToggled: c => Config.toasts.enabled = c
            }

            SettingRow {
                label: qsTr("Position")
                showSeparator: false

                PillRow {
                    model: [
                        { key: "top-left", label: qsTr("Top left") },
                        { key: "top-center", label: qsTr("Top center") },
                        { key: "top-right", label: qsTr("Top right") },
                        { key: "bottom-left", label: qsTr("Bottom left") },
                        { key: "bottom-center", label: qsTr("Bottom center") },
                        { key: "bottom-right", label: qsTr("Bottom right") }
                    ]
                    current: root.currentPos
                    onPicked: key => root.setPos(key)
                }
            }

            SpinBoxRow {
                label: qsTr("Default timeout (ms)")
                value: Config.toasts.defaultTimeout
                min: 1000
                max: 20000
                step: 500
                onValueModified: v => Config.toasts.defaultTimeout = v
            }

            SpinBoxRow {
                label: qsTr("Max visible")
                value: Config.toasts.maxVisible
                min: 1
                max: 10
                step: 1
                onValueModified: v => Config.toasts.maxVisible = v
            }

            SpinBoxRow {
                label: qsTr("Width")
                value: Config.toasts.toastWidth
                min: 240
                max: 560
                step: 10
                visible: Config.general.advanced
                onValueModified: v => Config.toasts.toastWidth = v
            }
        }

        // ── Sources (dynamic) ───────────────────────────────────────────────
        StyledText {
            visible: root.groups.length === 0
            Layout.fillWidth: true
            text: qsTr("No toast sources yet — they appear here automatically as modules and plugins emit toasts.")
            wrapMode: Text.WordWrap
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.on_surface_variant
        }

        Repeater {
            model: root.groups
            delegate: SettingSection {
                id: grp
                required property var modelData
                title: grp.modelData.label
                icon: grp.modelData.icon

                // Standalone source → its leaf controls directly.
                Repeater {
                    model: grp.modelData.isModule ? [] : [grp.modelData.self]
                    delegate: SourceBlock {
                        required property var modelData
                        Layout.fillWidth: true
                        src: modelData
                        parentEnabled: true
                    }
                }

                // Module node → master toggle + a block per child plugin.
                Repeater {
                    model: grp.modelData.isModule ? [grp.modelData] : []
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        SwitchRow {
                            label: qsTr("Enabled")
                            checked: Toaster.flag(grp.modelData.id, "enabled")
                            onToggled: c => Toaster.setOverride(grp.modelData.id, "enabled", c)
                        }

                        Repeater {
                            model: grp.modelData.children
                            delegate: ColumnLayout {
                                id: childCol
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.topMargin: Appearance.spacing.small
                                spacing: Appearance.spacing.small

                                StyledText {
                                    text: childCol.modelData.label
                                    font: Appearance.font.title.small
                                    color: Colours.palette.on_surface_variant
                                    Layout.fillWidth: true
                                }
                                SourceBlock {
                                    Layout.fillWidth: true
                                    src: childCol.modelData
                                    parentEnabled: Toaster.flag(grp.modelData.id, "enabled")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
