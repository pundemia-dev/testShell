import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

// Settings-таб Theme: режим dark/light, авто-расписание, палитра matugen и
// fine-tune ползунки. `mod` — WallpapersModule.
StyledFlickable {
    id: themeScroll

    required property var mod

    contentWidth: width; contentHeight: themeCol.height; clip: true
    ColumnLayout {
        id: themeCol
        width: parent.width; spacing: Appearance.spacing.small

        readonly property var mod: themeScroll.mod

        SectionHeader { title: "Mode" }

        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.large
            ToggleButton {
                label: "Dark"; toggled: themeCol.mod.themeMode === "dark"
                onClicked: { themeCol.mod.themeMode="dark"; themeCol.mod.setThemeParam("mode","dark"); }
            }
            ToggleButton {
                label: "Light"; toggled: themeCol.mod.themeMode === "light"
                onClicked: { themeCol.mod.themeMode="light"; themeCol.mod.setThemeParam("mode","light"); }
            }
        }

        SectionHeader { title: "Auto Mode Schedule" }

        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            StyledText { text:"Sunrise"; color:Colours.palette.on_surface }
            Item { Layout.fillWidth: true }
            StyledTextField {
                Layout.preferredWidth:80; text:themeCol.mod.themeAutoSunrise
                placeholderText:"07:00"
                onEditingFinished: {
                    themeCol.mod.themeAutoSunrise = text;
                    themeCol.mod.sendIpc(["config","set-theme-auto","sunrise",text]);
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            StyledText { text:"Sunset"; color:Colours.palette.on_surface }
            Item { Layout.fillWidth: true }
            StyledTextField {
                Layout.preferredWidth:80; text:themeCol.mod.themeAutoSunset
                placeholderText:"19:00"
                onEditingFinished: {
                    themeCol.mod.themeAutoSunset = text;
                    themeCol.mod.sendIpc(["config","set-theme-auto","sunset",text]);
                }
            }
        }
        TextButton {
            text: "Enable Auto Mode"
            onClicked: themeCol.mod.sendIpc(["theme","mode","auto"])
        }

        SectionHeader { title: "Palette" }

        SplitButtonRow {
            id: schemeSplitBtn; label: "Scheme"
            menuItems: themeCol.mod.themeVariants.map(v => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${v.replace('scheme-','')}"; property string val:"${v}" }`, themeCol))
            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++)
                    if (menuItems[i].val === themeCol.mod.themeSchemeType) { active = menuItems[i]; break; }
            }
            onSelected: item => {
                themeCol.mod.themeSchemeType = item.val;
                themeCol.mod.sendIpc(["theme","palette","set",item.val]);
                themeCol.mod.saveMatugenDefault("scheme_type", item.val);
            }
        }

        // Fine-tune
        CollapsibleSection {
            Layout.fillWidth: true; title: "Fine-tune"; expanded: true

            RowLayout {
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                StyledText { text:"Contrast"; color:Colours.palette.on_surface }
                StyledSlider { id:contrastSl; Layout.fillWidth:true; from:-1.0; to:1.0; stepSize:0.05
                    value: themeCol.mod.themeContrast
                    onInteraction: v => { themeCol.mod.themeContrast=v; themeCol.mod.setThemeParam("contrast",v.toFixed(2)); themeCol.mod.restartThemeDebounce(); }
                }
                StyledText { text:contrastSl.value.toFixed(2); color:Colours.palette.on_surface_variant; Layout.preferredWidth:38 }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                StyledText { text:"Dark brightness"; color:Colours.palette.on_surface }
                StyledSlider { id:darkSl; Layout.fillWidth:true; from:-1.0; to:1.0; stepSize:0.05
                    value: themeCol.mod.themeLightnessDark
                    onInteraction: v => { themeCol.mod.themeLightnessDark=v; themeCol.mod.setThemeParam("lightness-dark",v.toFixed(2)); themeCol.mod.restartThemeDebounce(); }
                }
                StyledText { text:darkSl.value.toFixed(2); color:Colours.palette.on_surface_variant; Layout.preferredWidth:38 }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                StyledText { text:"Light brightness"; color:Colours.palette.on_surface }
                StyledSlider { id:lightSl; Layout.fillWidth:true; from:-1.0; to:1.0; stepSize:0.05
                    value: themeCol.mod.themeLightnessLight
                    onInteraction: v => { themeCol.mod.themeLightnessLight=v; themeCol.mod.setThemeParam("lightness-light",v.toFixed(2)); themeCol.mod.restartThemeDebounce(); }
                }
                StyledText { text:lightSl.value.toFixed(2); color:Colours.palette.on_surface_variant; Layout.preferredWidth:38 }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                StyledText { text:"Opacity"; color:Colours.palette.on_surface }
                StyledSlider { id:opacSl; Layout.fillWidth:true; from:0.0; to:1.0; stepSize:0.05
                    value: themeCol.mod.themeOpacity
                    onInteraction: v => { themeCol.mod.themeOpacity=v; themeCol.mod.setThemeParam("opacity",v.toFixed(2)); themeCol.mod.restartThemeDebounce(); }
                }
                StyledText { text:opacSl.value.toFixed(2); color:Colours.palette.on_surface_variant; Layout.preferredWidth:38 }
            }

            SpinBoxRow {
                label:"Color index (0–4)"; value:themeCol.mod.themeColorIndex; min:0; max:4; step:1
                onValueModified: v => { themeCol.mod.themeColorIndex=v; themeCol.mod.setThemeParam("source-color-index",v); themeCol.mod.restartThemeDebounce(); }
            }

            SplitButtonRow {
                id: preferBtn; label:"Prefer"
                menuItems: themeCol.mod.colorPrefs.map(p => Qt.createQmlObject(`import qs.components.controls; MenuItem { text:"${p}"; property string val:"${p}" }`, themeCol))
                Component.onCompleted: {
                    for (let i = 0; i < menuItems.length; i++)
                        if (menuItems[i].val === themeCol.mod.themePrefer) { active = menuItems[i]; break; }
                }
                onSelected: item => {
                    themeCol.mod.themePrefer = item.val;
                    themeCol.mod.setThemeParam("prefer", item.val);
                    themeCol.mod.restartThemeDebounce();
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: Appearance.spacing.medium
                StyledText { text:"Fallback color"; color:Colours.palette.on_surface }
                Item { Layout.fillWidth: true }
                Rectangle { width:24;height:24;radius:4; color:"#"+(themeCol.mod.themeFallbackColor?themeCol.mod.themeFallbackColor.substring(0,6):"4285f4"); border.width:1;border.color:Colours.palette.outline }
                StyledTextField {
                    Layout.preferredWidth:110; text:themeCol.mod.themeFallbackColor; placeholderText:"rrggbb"
                    onEditingFinished: {
                        let c = text.replace(/[^0-9a-fA-F]/g,"");
                        if (c.length >= 6) { themeCol.mod.themeFallbackColor=c.substring(0,6); themeCol.mod.setThemeParam("fallback-color",c.substring(0,6)); themeCol.mod.restartThemeDebounce(); }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: Appearance.spacing.medium
            TextButton { text:"Regenerate Theme"; onClicked: { if (themeCol.mod.originalWallpaper) themeCol.mod.sendIpc(["theme","generate",themeCol.mod.originalWallpaper]); } }
            TextButton { text:"Reset to Defaults"; onClicked: themeCol.mod.sendIpc(["theme","set","contrast","0"]) }
        }

        Item { Layout.preferredHeight: Appearance.padding.large }
    }
    StyledScrollBar { flickable: themeScroll; anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom }
}
