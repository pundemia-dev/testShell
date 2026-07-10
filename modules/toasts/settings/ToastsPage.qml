pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import qs.components.containers
import qs.modules.settings.components
import QtQuick
import QtQuick.Layouts

// Config.toasts → modules/toasts/config/ToastsConfig.qml
// Three tiers of muting, most-global first:
//   1. Severity — global Info / Warning / Error switches (Config.toasts.severity).
//   2. Per source — a master Enabled that kills everything from that source
//      (or module node), plus a collapsible list of its individual
//      notifications, ranked Error → Warning → Info and split by a divider.
//   3. Each notification's own toggle (Config.toasts.overrides[src].ids[id]).
// The source tree is built dynamically from ToastRegistry.sources — no
// hardcoded categories.
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // ── Source tree (module nodes + standalone sources) ─────────────────────
    readonly property var groups: {
        const srcs = ToastRegistry.sources ?? [];
        const childrenOf = ({});
        for (const s of srcs)
            if (s.parentId)
                (childrenOf[s.parentId] = childrenOf[s.parentId] ?? []).push(s);

        const out = [];
        const seenModule = ({});
        for (const s of srcs) {
            if (s.parentId && !seenModule[s.parentId]) {
                seenModule[s.parentId] = true;
                const node = srcs.find(x => x.sourceId === s.parentId);
                out.push({
                    id: s.parentId,
                    label: node?.label ?? s.parentId,
                    icon: node?.icon ?? "",
                    isModule: true,
                    self: null,
                    children: childrenOf[s.parentId] ?? []
                });
            }
        }
        for (const s of srcs)
            if (!s.parentId && !seenModule[s.sourceId])
                out.push({
                    id: s.sourceId,
                    label: s.label,
                    icon: s.icon || "",
                    isModule: false,
                    self: s,
                    children: []
                });

        out.sort((a, b) => String(a.label).localeCompare(String(b.label)));
        return out;
    }

    // Leaf controls for one source: master Enabled + a collapsible list of its
    // individual notifications, grouped Error → Warning → Info with dividers.
    component SourceBlock: ColumnLayout {
        id: sb
        required property var src
        property bool parentEnabled: true

        readonly property string sid: sb.src.sourceId
        readonly property bool selfEnabled: Toaster.flag(sb.sid, "enabled")
        readonly property var notifs: sb.src.notifications ?? []

        // Non-empty severity groups, ranked, each { key, label, items }.
        readonly property var noteGroups: {
            const buckets = ({
                    error: [],
                    warning: [],
                    info: []
                });
            for (const n of sb.notifs) {
                const s = n.severity === "error" ? "error" : n.severity === "warning" ? "warning" : "info";
                buckets[s].push(n);
            }
            const labels = ({
                    error: qsTr("Errors"),
                    warning: qsTr("Warnings"),
                    info: qsTr("Info")
                });
            const out = [];
            for (const key of ["error", "warning", "info"])
                if (buckets[key].length > 0)
                    out.push({
                        key: key,
                        label: labels[key],
                        items: buckets[key]
                    });
            return out;
        }

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        SwitchRow {
            label: qsTr("Enabled")
            checked: sb.selfEnabled
            enabled: sb.parentEnabled
            onToggled: c => Toaster.setOverride(sb.sid, "enabled", c)
        }

        CollapsibleSection {
            Layout.fillWidth: true
            visible: sb.notifs.length > 0
            title: qsTr("Notifications")

            Repeater {
                model: sb.noteGroups
                delegate: ColumnLayout {
                    id: grpCol
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    // Divider above every group except the first.
                    StyledRect {
                        visible: grpCol.index > 0
                        Layout.fillWidth: true
                        Layout.topMargin: Appearance.spacing.small
                        implicitHeight: 1
                        color: Colours.palette.outline_variant
                    }

                    StyledText {
                        text: grpCol.modelData.label
                        font: Appearance.font.label.small
                        color: Colours.palette.on_surface_variant
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: grpCol.modelData.items
                        delegate: SwitchRow {
                            required property var modelData
                            Layout.fillWidth: true
                            label: modelData.label ?? modelData.id
                            checked: Toaster.notifFlag(sb.sid, modelData.id)
                            enabled: sb.parentEnabled && sb.selfEnabled
                            onToggled: c => Toaster.setNotifOverride(sb.sid, modelData.id, c)
                        }
                    }
                }
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

        // ── Severity (global) ───────────────────────────────────────────────
        SettingSection {
            title: qsTr("Severity")
            icon: "\uea03" // tabler adjustments
            description: qsTr("Globally mute every toast of a severity, regardless of source.")

            SwitchRow {
                label: qsTr("Info")
                checked: Config.toasts.severity.info
                onToggled: c => Config.toasts.severity.info = c
            }
            SwitchRow {
                label: qsTr("Warning")
                checked: Config.toasts.severity.warning
                onToggled: c => Config.toasts.severity.warning = c
            }
            SwitchRow {
                label: qsTr("Error")
                checked: Config.toasts.severity.error
                onToggled: c => Config.toasts.severity.error = c
            }
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

        BackgroundCard {
            cfg: Config.toasts
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
