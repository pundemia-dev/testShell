import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

// Settings-таб System: статус демона, game mode, мониторы, профили, config.toml.
// `mod` — WallpapersModule.
StyledFlickable {
    id: systemScroll

    required property var mod

    contentWidth: width; contentHeight: systemCol.height; clip: true
    ColumnLayout {
        id: systemCol
        width: parent.width; spacing: Appearance.spacing.small

        readonly property var mod: systemScroll.mod

        SectionHeader { title: "Daemon" }
        PropertyRow { label:"Status";   value:systemCol.mod.daemonStatus }
        PropertyRow { label:"Uptime";   value:{ let s=systemCol.mod.daemonUptime; return `${Math.floor(s/3600)}h ${Math.floor((s%3600)/60)}m ${s%60}s`; } }
        PropertyRow { label:"Memory";   value:systemCol.mod.daemonMemory.toFixed(1)+" MiB" }
        PropertyRow { label:"Indexing"; value:systemCol.mod.indexingActive?`running (${systemCol.mod.indexQueueSize} queued)`:"idle" }
        PropertyRow { label:"Preview";  value:systemCol.mod.previewActive?"active":"off" }

        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            TextButton { text:"Restart Daemon"; onClicked: { systemCol.mod.sendIpc(["daemon","stop"]); systemCol.mod.daemonStatus="restarting…"; Qt.callLater(()=>{ Quickshell.execDetached([systemCol.mod.walltoolBin,"daemon","start"]); Qt.callLater(()=>systemCol.mod.fetchDaemonData(),1000); }); } }
            TextButton { text:"Refresh";        onClicked: systemCol.mod.fetchDaemonData() }
        }

        SectionHeader { title: "Game Mode" }
        SwitchRow {
            label:"Pause all (Game Mode)"; checked:systemCol.mod.gameMode
            onToggled: function() { systemCol.mod.gameMode=!systemCol.mod.gameMode; systemCol.mod.sendIpc(systemCol.mod.gameMode?["daemon","pause-all"]:["daemon","resume-all"]); }
        }

        SectionHeader { title: "Monitors" }
        Repeater {
            model: systemCol.mod.monitorsList
            delegate: PropertyRow {
                label: modelData.name||modelData
                value: modelData.width&&modelData.height?`${modelData.width}×${modelData.height} @(${modelData.x},${modelData.y}) ×${(modelData.scale||1).toFixed(1)}`:""
            }
        }
        TextButton { text:"Identify Monitors"; onClicked: systemCol.mod.sendIpc(["monitor","identify"]) }

        SectionHeader { title: "Profiles" }
        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            StyledText { text:"Profile name"; color:Colours.palette.on_surface }
            StyledTextField { Layout.preferredWidth:140; text:systemCol.mod.currentProfile; onTextChanged:systemCol.mod.currentProfile=text; placeholderText:"my-profile" }
        }
        SplitButtonRow {
            label:"Existing"
            menuItems: systemCol.mod.profilesList.map(p => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${p}"; property string val:"${p}" }`, systemCol))
            onSelected: item => systemCol.mod.currentProfile = item.val
        }
        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            TextButton { text:"Save";   enabled:systemCol.mod.currentProfile!==""; onClicked: systemCol.mod.sendIpc(["config","profile","save",systemCol.mod.currentProfile]) }
            TextButton { text:"Load";   enabled:systemCol.mod.currentProfile!==""; onClicked: systemCol.mod.sendIpc(["config","profile","load",systemCol.mod.currentProfile]) }
            TextButton { text:"Delete"; enabled:systemCol.mod.currentProfile!==""; onClicked: { systemCol.mod.sendIpc(["config","profile","rm",systemCol.mod.currentProfile]); systemCol.mod.currentProfile=""; systemCol.mod.fetchDaemonData(); } }
        }

        SectionHeader { title: "Config" }

        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            TextButton { text:"Open in Editor"; onClicked: systemCol.mod.sendIpc(["config","edit"]) }
            TextButton { text:"Reload";          onClicked: systemCol.mod.fetchDaemonData() }
        }

        // Config preview
        CollapsibleSection {
            Layout.fillWidth: true; title:"config.toml preview"; expanded:false
            Item {
                Layout.fillWidth: true
                implicitHeight: cfgText.implicitHeight + Appearance.padding.medium*2
                StyledRect {
                    anchors.fill: parent
                    color: Colours.palette.surface_variant; radius: Appearance.rounding.small
                    StyledText {
                        id: cfgText
                        anchors { left:parent.left; right:parent.right; top:parent.top; margins:Appearance.padding.medium }
                        text: systemCol.mod.configFullText || "# (click Reload to fetch config)"
                        font.family: "monospace"; font.pointSize: Appearance.font.size.smaller
                        color: Colours.palette.on_surface_variant; wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Item { Layout.preferredHeight: Appearance.padding.large }
    }
    StyledScrollBar { flickable: systemScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
}
