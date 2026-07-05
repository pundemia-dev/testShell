import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

// Settings-таб Gallery: индексация, watch-директории, история, избранное,
// сортировка. `mod` — WallpapersModule.
StyledFlickable {
    id: galleryScroll

    required property var mod

    contentWidth: width; contentHeight: galleryCol.height; clip: true
    ColumnLayout {
        id: galleryCol
        width: parent.width; spacing: Appearance.spacing.small

        readonly property var mod: galleryScroll.mod

        SectionHeader { title: "Index" }

        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            StyledText { text:"Directory"; color:Colours.palette.on_surface }
            StyledTextField { Layout.fillWidth:true; text:galleryCol.mod.indexDir; onTextChanged:galleryCol.mod.indexDir=text }
        }
        SwitchRow { label:"Force re-index"; checked:galleryCol.mod.indexForce; onToggled: function(){galleryCol.mod.indexForce=!galleryCol.mod.indexForce} }
        TextButton { text:"Index Now"; onClicked: { let a=["wallpaper","index",galleryCol.mod.indexDir]; if(galleryCol.mod.indexForce) a.push("--force"); galleryCol.mod.sendIpc(a); } }

        SectionHeader { title: "Watch Directories (auto-index)" }

        SwitchRow {
            label: "AI Tagging (requires Moondream)"
            checked: galleryCol.mod.aiTagging
            onToggled: function() {
                galleryCol.mod.aiTagging = !galleryCol.mod.aiTagging;
                galleryCol.mod.sendIpc(["config","set-indexer","ai_tagging",String(galleryCol.mod.aiTagging)]);
            }
        }

        Repeater {
            model: galleryCol.mod.watchDirs
            delegate: RowLayout {
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                StyledIcon { text:"\ue2c7"; color:Colours.palette.on_surface_variant }
                StyledText { Layout.fillWidth:true; text:modelData; elide:Text.ElideLeft; color:Colours.palette.on_surface }
                IconButton {
                    icon:"\ue872"; type:IconButton.Tonal
                    onClicked: {
                        galleryCol.mod.sendIpc(["config","set-indexer","rm_watch_dir",modelData]);
                        let updated = galleryCol.mod.watchDirs.filter(d=>d!==modelData);
                        galleryCol.mod.watchDirs = updated;
                    }
                    Tooltip { target:parent; text:"Remove watch dir" }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            StyledTextField {
                id: watchDirField; Layout.fillWidth:true
                placeholderText: "Path to watch…"
                text: galleryCol.mod.newWatchDir
                onTextChanged: galleryCol.mod.newWatchDir = text
            }
            TextButton {
                text:"Add"
                enabled: galleryCol.mod.newWatchDir.length > 0
                onClicked: {
                    galleryCol.mod.sendIpc(["config","set-indexer","add_watch_dir",galleryCol.mod.newWatchDir]);
                    galleryCol.mod.watchDirs = galleryCol.mod.watchDirs.concat([galleryCol.mod.newWatchDir]);
                    galleryCol.mod.newWatchDir = "";
                    watchDirField.text = "";
                }
            }
        }

        SectionHeader { title: "History" }
        PropertyRow { label:"Entries"; value:String(galleryCol.mod.historyCount) }
        TextButton { text:"Clear History"; onClicked: { galleryCol.mod.sendIpc(["wallpaper","history","clear"]); galleryCol.mod.historyCount=0; } }

        SectionHeader { title: "Favorites" }
        PropertyRow { label:"Entries"; value:String(galleryCol.mod.favoritesCount) }
        TextButton {
            text:"Clear All Favorites"
            onClicked: galleryCol.mod.sendIpcWithResponse(["wallpaper","fav","list","--limit","1000"], resp => {
                if (resp?.status==="Ok"&&resp.data) {
                    let e = resp.data.value||[];
                    for (let x of e) if (x.path) galleryCol.mod.sendIpc(["wallpaper","fav","rm",x.path]);
                    galleryCol.mod.favoritesCount=0;
                }
            })
        }

        SectionHeader { title: "Random & Sort" }
        SplitButtonRow {
            label:"Sort by"
            menuItems: galleryCol.mod.sortFields.map(f => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${f[0].toUpperCase()+f.slice(1)}"; property string val:"${f}" }`, galleryCol))
            Component.onCompleted: {
                for (let i=0;i<menuItems.length;i++) if(menuItems[i].val===galleryCol.mod.sortBy){active=menuItems[i];break;}
            }
            onSelected: item => galleryCol.mod.sortBy = item.val
        }
        SwitchRow { label:"Reverse order"; checked:galleryCol.mod.sortReverse; onToggled:function(){galleryCol.mod.sortReverse=!galleryCol.mod.sortReverse} }

        Item { Layout.preferredHeight: Appearance.padding.large }
    }
    StyledScrollBar { flickable: galleryScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
}
