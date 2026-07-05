import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

// Settings-таб Display: монитор, namespace, resize, transition,
// per-monitor / per-wallpaper overrides. `mod` — WallpapersModule.
StyledFlickable {
    id: displayScroll

    required property var mod

    contentWidth: width; contentHeight: displayCol.height; clip: true
    ColumnLayout {
        id: displayCol
        width: parent.width; spacing: Appearance.spacing.small

        readonly property var mod: displayScroll.mod

        SectionHeader { title: "Target" }

        SplitButtonRow {
            label: "Monitor"
            menuItems: {
                let items = [Qt.createQmlObject('import qs.components.controls; MenuItem { text:"All"; icon:"desktop_windows"; property string val:"All" }', displayCol)];
                for (let m of displayCol.mod.monitorsList) {
                    let n = m.name || m;
                    items.push(Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${n}"; icon:"monitor"; property string val:"${n}" }`, displayCol));
                }
                return items;
            }
            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++)
                    if (menuItems[i].val === displayCol.mod.targetMonitor) { active = menuItems[i]; break; }
            }
            onSelected: item => displayCol.mod.targetMonitor = item.val
        }

        SwitchRow {
            label: "Skip theme generation"
            checked: displayCol.mod.skipThemeGen
            onToggled: function() { displayCol.mod.skipThemeGen = !displayCol.mod.skipThemeGen; }
        }

        SectionHeader { title: "awww Namespace" }

        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            StyledText { text: "Namespace"; color: Colours.palette.on_surface }
            Item { Layout.fillWidth: true }
            StyledTextField {
                Layout.preferredWidth: 200
                text: displayCol.mod.awwwNamespace
                placeholderText: "(default)"
                onEditingFinished: {
                    displayCol.mod.awwwNamespace = text;
                    displayCol.mod.sendIpc(["config", "set-namespace", text || "null"]);
                }
            }
        }

        SectionHeader { title: "Resize" }

        SplitButtonRow {
            label: "Mode"
            menuItems: displayCol.mod.resizeModes.map(m => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${m[0].toUpperCase()+m.slice(1)}"; property string val:"${m}" }`, displayCol))
            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++)
                    if (menuItems[i].val === displayCol.mod.resizeMode) { active = menuItems[i]; break; }
            }
            onSelected: item => { displayCol.mod.resizeMode = item.val; displayCol.mod.saveAwwwDefault("resize", item.val); }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            StyledText { text: "Fill Color"; color: Colours.palette.on_surface }
            Item { Layout.fillWidth: true }
            Rectangle { width:24; height:24; radius:4; color:"#"+displayCol.mod.fillColor.substring(0,6); border.width:1; border.color:Colours.palette.outline }
            StyledTextField {
                Layout.preferredWidth: 110; text: displayCol.mod.fillColor
                onEditingFinished: {
                    let c = text.replace(/[^0-9a-fA-F]/g,"");
                    if (c.length >= 6) { let n = c.substring(0,8).padEnd(8,"f"); displayCol.mod.fillColor = n; displayCol.mod.saveAwwwDefault("fill_color", n); }
                }
            }
        }

        SplitButtonRow {
            label: "Filter"
            menuItems: displayCol.mod.imageFilters.map(f => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${f}"; property string val:"${f}" }`, displayCol))
            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++)
                    if (menuItems[i].val === displayCol.mod.imageFilter) { active = menuItems[i]; break; }
            }
            onSelected: item => { displayCol.mod.imageFilter = item.val; displayCol.mod.saveAwwwDefault("filter", item.val); }
        }

        // Transition
        CollapsibleSection {
            Layout.fillWidth: true; title: "Transition"; expanded: false

            SplitButtonRow {
                label: "Type"
                menuItems: displayCol.mod.transitionTypes.map(t => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${t}"; property string val:"${t}" }`, displayCol))
                Component.onCompleted: {
                    for (let i = 0; i < menuItems.length; i++)
                        if (menuItems[i].val === displayCol.mod.transitionType) { active = menuItems[i]; break; }
                }
                onSelected: item => { displayCol.mod.transitionType = item.val; displayCol.mod.saveAwwwDefault("transition_type", item.val); }
            }

            SpinBoxRow { label:"Duration (s)"; value: displayCol.mod.transitionDuration; min:0.1; max:10; step:0.1; onValueModified: v => { displayCol.mod.transitionDuration=v; displayCol.mod.saveAwwwDefault("transition_duration",v); } }
            SpinBoxRow { label:"FPS";           value: displayCol.mod.transitionFps;      min:10;  max:144; step:5;  onValueModified: v => { displayCol.mod.transitionFps=v;      displayCol.mod.saveAwwwDefault("transition_fps",v); } }
            SpinBoxRow { visible: displayCol.mod.transitionType==="simple"; label:"Step (1-255)"; value:displayCol.mod.transitionStep; min:1; max:255; step:1; onValueModified: v => { displayCol.mod.transitionStep=v; displayCol.mod.saveAwwwDefault("transition_step",v); } }
            SpinBoxRow { visible: displayCol.mod.transitionType==="wipe"||displayCol.mod.transitionType==="wave"; label:"Angle (°)"; value:displayCol.mod.transitionAngle; min:0; max:360; step:15; onValueModified: v => { displayCol.mod.transitionAngle=v; displayCol.mod.saveAwwwDefault("transition_angle",v); } }

            RowLayout {
                visible: displayCol.mod.transitionType==="grow"||displayCol.mod.transitionType==="outer"||displayCol.mod.transitionType==="any"
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                StyledText { text:"Position"; color:Colours.palette.on_surface }
                Item { Layout.fillWidth: true }
                StyledTextField { Layout.preferredWidth:120; text:displayCol.mod.transitionPos; onEditingFinished: { displayCol.mod.transitionPos=text; displayCol.mod.saveAwwwDefault("transition_pos",text); } }
            }
            RowLayout {
                visible: displayCol.mod.transitionType==="fade"
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                StyledText { text:"Bezier"; color:Colours.palette.on_surface }
                Item { Layout.fillWidth: true }
                StyledTextField { Layout.preferredWidth:150; text:displayCol.mod.transitionBezier; onEditingFinished: { displayCol.mod.transitionBezier=text; displayCol.mod.saveAwwwDefault("transition_bezier",text); } }
            }
            RowLayout {
                visible: displayCol.mod.transitionType==="wave"
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                StyledText { text:"Wave (W,H)"; color:Colours.palette.on_surface }
                Item { Layout.fillWidth: true }
                StyledTextField { Layout.preferredWidth:80; text:displayCol.mod.transitionWave; onEditingFinished: { displayCol.mod.transitionWave=text; displayCol.mod.saveAwwwDefault("transition_wave",text); } }
            }
            SwitchRow {
                visible: displayCol.mod.transitionType==="grow"||displayCol.mod.transitionType==="outer"||displayCol.mod.transitionType==="any"
                label:"Invert Y"; checked:displayCol.mod.transitionInvertY
                onToggled: function() { displayCol.mod.transitionInvertY=!displayCol.mod.transitionInvertY; displayCol.mod.saveAwwwDefault("invert_y",displayCol.mod.transitionInvertY); }
            }
        }

        // Per-monitor overrides
        CollapsibleSection {
            Layout.fillWidth: true; title: "Per-monitor Overrides"; expanded: false

            Repeater {
                model: displayCol.mod.monitorConfigs
                delegate: RowLayout {
                    Layout.fillWidth: true; spacing: Appearance.spacing.medium
                    StyledText { text: modelData.monitor; font.weight: Font.DemiBold; color: Colours.palette.primary }
                    StyledText {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        color: Colours.palette.on_surface_variant
                        text: {
                            let o = modelData.options || {};
                            let parts = [];
                            if (o.resize)          parts.push("resize:"+o.resize);
                            if (o.transition_type) parts.push("tr:"+o.transition_type);
                            if (o.filter)          parts.push("filter:"+o.filter);
                            return parts.join("  ") || "(no overrides)";
                        }
                    }
                    IconButton {
                        icon: "\ue872"; type: IconButton.Tonal
                        onClicked: {
                            let mon = modelData.monitor;
                            displayCol.mod.sendIpc(["config","rm-monitor",mon]);
                            displayCol.mod.sendIpcWithResponse(["config","list-monitors"], resp => {
                                if (resp?.status==="Ok" && resp.data) displayCol.mod.monitorConfigs = resp.data.value || [];
                            });
                        }
                        Tooltip { target: parent; text: "Remove "+modelData.monitor+" overrides" }
                    }
                }
            }

            // Add override for current monitor
            RowLayout {
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                StyledText { text: "Set override for:"; color: Colours.palette.on_surface }
                SplitButtonRow {
                    label: ""
                    menuItems: displayCol.mod.monitorsList.map(m => {
                        let n = m.name||m;
                        return Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${n}"; property string val:"${n}" }`, displayCol);
                    })
                    onSelected: item => {
                        // Apply current global settings as monitor override
                        displayCol.mod.sendIpc(["config","set-monitor",item.val,"resize",displayCol.mod.resizeMode]);
                        displayCol.mod.sendIpc(["config","set-monitor",item.val,"transition_type",displayCol.mod.transitionType]);
                        displayCol.mod.sendIpc(["config","set-monitor",item.val,"filter",displayCol.mod.imageFilter]);
                        displayCol.mod.sendIpcWithResponse(["config","list-monitors"], resp => {
                            if (resp?.status==="Ok"&&resp.data) displayCol.mod.monitorConfigs = resp.data.value||[];
                        });
                    }
                }
            }
        }

        // Per-wallpaper options
        CollapsibleSection {
            Layout.fillWidth: true; title: "Per-wallpaper Options"; expanded: false
            PropertyRow { label:"Current"; value: displayCol.mod.originalWallpaper?displayCol.mod._fileNameFromPath(displayCol.mod.originalWallpaper):"None" }
            RowLayout {
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                TextButton { text:"Save Current Options"; onClicked: { let args=["wallpaper","options","set","--resize",displayCol.mod.resizeMode,"--filter",displayCol.mod.imageFilter,"--transition-type",displayCol.mod.transitionType]; displayCol.mod.sendIpc(args); } }
                TextButton { text:"Clear Options";         onClicked: displayCol.mod.sendIpc(["wallpaper","options","clear"]) }
            }
            TextButton {
                text: "View Saved Options"
                onClicked: displayCol.mod.sendIpcWithResponse(["wallpaper","options","get"], resp => {
                    if (resp?.status==="Ok"&&resp.data) console.log("[WP] options:", JSON.stringify(resp.data));
                })
            }
        }

        Item { Layout.preferredHeight: Appearance.padding.large }
    }
    StyledScrollBar { flickable: displayScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
}
