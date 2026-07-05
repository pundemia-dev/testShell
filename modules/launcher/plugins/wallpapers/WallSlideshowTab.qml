import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

// Settings-таб Slideshow: запуск/интервал/директория и фильтры.
// `mod` — WallpapersModule.
StyledFlickable {
    id: slideshowScroll

    required property var mod

    contentWidth: width; contentHeight: slideshowCol.height; clip: true
    ColumnLayout {
        id: slideshowCol
        width: parent.width; spacing: Appearance.spacing.small

        readonly property var mod: slideshowScroll.mod

        SectionHeader { title: "Slideshow" }

        SwitchRow {
            label:"Active"; checked:slideshowCol.mod.slideshowActive
            onToggled: function() {
                slideshowCol.mod.slideshowActive = !slideshowCol.mod.slideshowActive;
                if (slideshowCol.mod.slideshowActive) {
                    let a = ["daemon","slideshow","start",slideshowCol.mod.slideshowDir,"-i",String(Math.round(slideshowCol.mod.slideshowInterval))];
                    if (slideshowCol.mod.slideshowTextFilter)  a.push("--query",slideshowCol.mod.slideshowTextFilter);
                    if (slideshowCol.mod.slideshowIncludeHidden) a.push("--include-dot");
                    if (slideshowCol.mod.slideshowOnlyHidden)    a.push("--only-dot");
                    if (slideshowCol.mod.slideshowOnlyFavorites) a.push("--favorites");
                    slideshowCol.mod.sendIpc(a);
                } else {
                    slideshowCol.mod.sendIpc(["daemon","slideshow","stop"]);
                }
            }
        }

        SpinBoxRow {
            label:"Interval (sec)"; value:slideshowCol.mod.slideshowInterval; min:10; max:86400; step:60
            onValueModified: v => { slideshowCol.mod.slideshowInterval=v; slideshowCol.mod.saveSlideshowConfig("interval",v); }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            StyledText { text:"Directory"; color:Colours.palette.on_surface }
            StyledTextField { Layout.fillWidth:true; text:slideshowCol.mod.slideshowDir; onEditingFinished: { slideshowCol.mod.slideshowDir=text; slideshowCol.mod.saveSlideshowConfig("dir",text); } }
        }

        CollapsibleSection {
            Layout.fillWidth: true; title:"Filters"; expanded:false

            SwitchRow {
                label:"Include hidden files"; checked:slideshowCol.mod.slideshowIncludeHidden
                onToggled: function() {
                    slideshowCol.mod.slideshowIncludeHidden=!slideshowCol.mod.slideshowIncludeHidden;
                    if (slideshowCol.mod.slideshowIncludeHidden) slideshowCol.mod.slideshowOnlyHidden=false;
                    slideshowCol.mod.saveSlideshowConfig("include_hidden",slideshowCol.mod.slideshowIncludeHidden);
                    if (slideshowCol.mod.slideshowIncludeHidden) slideshowCol.mod.saveSlideshowConfig("only_hidden",false);
                }
            }
            SwitchRow {
                label:"Only hidden files"; checked:slideshowCol.mod.slideshowOnlyHidden
                onToggled: function() {
                    slideshowCol.mod.slideshowOnlyHidden=!slideshowCol.mod.slideshowOnlyHidden;
                    if (slideshowCol.mod.slideshowOnlyHidden) slideshowCol.mod.slideshowIncludeHidden=false;
                    slideshowCol.mod.saveSlideshowConfig("only_hidden",slideshowCol.mod.slideshowOnlyHidden);
                    if (slideshowCol.mod.slideshowOnlyHidden) slideshowCol.mod.saveSlideshowConfig("include_hidden",false);
                }
            }
            SwitchRow {
                label:"Only favorites"; checked:slideshowCol.mod.slideshowOnlyFavorites
                onToggled: function() { slideshowCol.mod.slideshowOnlyFavorites=!slideshowCol.mod.slideshowOnlyFavorites; slideshowCol.mod.saveSlideshowConfig("only_favorites",slideshowCol.mod.slideshowOnlyFavorites); }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                StyledText { text:"Text filter"; color:Colours.palette.on_surface }
                StyledTextField { Layout.fillWidth:true; placeholderText:"name, tags, or color…"; text:slideshowCol.mod.slideshowTextFilter; onEditingFinished: { slideshowCol.mod.slideshowTextFilter=text; slideshowCol.mod.saveSlideshowConfig("text_filter",text||""); } }
            }
        }

        Item { Layout.preferredHeight: Appearance.padding.large }
    }
    StyledScrollBar { flickable: slideshowScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
}
