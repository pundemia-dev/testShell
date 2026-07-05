import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services

// PathView-карусель обоев с кнопками навигации; регистрирует себя в модуле
// через mod.carousel. `mod` — инстанс WallpapersModule.
Item {
    id: carouselContainer
    clip: true

    required property var mod

    readonly property real baseItemWidth:  mod._baseCardW
    readonly property real baseItemHeight: mod._baseCardH
    readonly property bool showNavButtons: mod.galleryModel.count > 1 && !mod.isSettingsOpen

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            let primary   = carouselContainer.mod.isVertical ? event.angleDelta.y : event.angleDelta.x;
            let secondary = carouselContainer.mod.isVertical ? event.angleDelta.x : event.angleDelta.y;
            if (Math.abs(primary) > Math.abs(secondary)) {
                if (primary < 0) carouselContainer.mod.navigateDown(); else carouselContainer.mod.navigateUp();
            } else {
                if (secondary < 0) carouselContainer.mod.navigateDown(); else carouselContainer.mod.navigateUp();
            }
            event.accepted = true;
        }
    }

    // prev button
    Item {
        id: navPrevBtn; z: 10; visible: carouselContainer.showNavButtons
        anchors.left: carouselContainer.mod.isVertical?undefined:parent.left; anchors.top: carouselContainer.mod.isVertical?parent.top:undefined
        anchors.verticalCenter: carouselContainer.mod.isVertical?undefined:parent.verticalCenter
        anchors.horizontalCenter: carouselContainer.mod.isVertical?parent.horizontalCenter:undefined
        anchors.leftMargin: carouselContainer.mod.isVertical?0:Appearance.padding.small
        anchors.topMargin:  carouselContainer.mod.isVertical?Appearance.padding.small:0
        width: _prevBtn.width; height: _prevBtn.height
        property bool hovered: _prevHov.hovered
        IconButton {
            id: _prevBtn; anchors.centerIn: parent
            icon: carouselContainer.mod.isVertical?"\ue5c7":"\ue5c4"
            type: IconButton.Tonal
            opacity: navPrevBtn.hovered?1.0:0.4
            Behavior on opacity {
                OpacityAnimator {
                    duration: Appearance.anim.durations.smaller
                }
            }
            onClicked: carouselContainer.mod.navigateUp()
        }
        HoverHandler { id: _prevHov }
        Tooltip {
            target: navPrevBtn
            text: carouselContainer.mod.isVertical?"Previous (↑)":"Previous (←)"
        }
    }

    // next button
    Item {
        id: navNextBtn; z: 10; visible: carouselContainer.showNavButtons
        anchors.right: carouselContainer.mod.isVertical?undefined:parent.right; anchors.bottom: carouselContainer.mod.isVertical?parent.bottom:undefined
        anchors.verticalCenter: carouselContainer.mod.isVertical?undefined:parent.verticalCenter
        anchors.horizontalCenter: carouselContainer.mod.isVertical?parent.horizontalCenter:undefined
        anchors.rightMargin:  carouselContainer.mod.isVertical?0:Appearance.padding.small
        anchors.bottomMargin: carouselContainer.mod.isVertical?Appearance.padding.small:0
        width: _nextBtn.width; height: _nextBtn.height
        property bool hovered: _nextHov.hovered
        IconButton {
            id: _nextBtn; anchors.centerIn: parent
            icon: carouselContainer.mod.isVertical?"\ue5c5":"\ue5c8"
            type: IconButton.Tonal; opacity: navNextBtn.hovered?1.0:0.4
            Behavior on opacity {
                OpacityAnimator {
                    duration: Appearance.anim.durations.smaller
                }
            }
            onClicked: carouselContainer.mod.navigateDown()
        }
        HoverHandler { id: _nextHov }
        Tooltip {
            target: navNextBtn
            text: carouselContainer.mod.isVertical?"Next (↓)":"Next (→)"
        }
    }

    PathView {
        id: grid
        Component.onCompleted:  carouselContainer.mod.carousel = grid
        Component.onDestruction: carouselContainer.mod.carousel = null
        anchors.fill: parent
        model: carouselContainer.mod.galleryModel
        pathItemCount: carouselContainer.mod.visibleItems
        cacheItemCount: 15
        snapMode: PathView.SnapToItem
        preferredHighlightBegin: 0.5; preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        flickDeceleration: 2000; maximumFlickVelocity: 2500
        interactive: true; dragMargin: carouselContainer.baseItemWidth * 0.4
        highlightMoveDuration: carouselContainer.mod._isRapid ? 0 : carouselContainer.mod._isActive ? 150 : 350

        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex < count) {
                let item = carouselContainer.mod.galleryModel.get(currentIndex);
                if (item && !carouselContainer.mod._isRapid) carouselContainer.mod.livePreview(item.path);
            }
        }

        delegate: Item {
            id: cardDelegate
            required property int    index
            required property string name
            required property string path
            required property string mediaType
            required property string tags
            required property bool   isFav
            required property bool   removing

            z: PathView.z ?? 0
            implicitWidth:  carouselContainer.baseItemWidth
            implicitHeight: carouselContainer.baseItemHeight + Appearance.padding.small

            readonly property real targetScale:   PathView.itemScale  ?? 0.5
            readonly property real targetOpacity: PathView.itemOpacity ?? 0.6
            readonly property bool isCenterCard:  Math.abs(targetScale - 1.0) < 0.05

            scale: targetScale; opacity: PathView.onPath ? targetOpacity : 0; visible: opacity > 0

            Item {
                id: transformContainer; anchors.fill: parent; transformOrigin: Item.Center
                scale: 0.0; opacity: 0.0
                Component.onCompleted: {
                    if (carouselContainer.mod._isRapid) { scale = 1.0; opacity = 1.0; }
                    else if (!cardDelegate.removing) { enterScaleAnim.restart(); enterOpacityAnim.restart(); }
                }
                NumberAnimation { id: enterScaleAnim;   target: transformContainer; property: "scale";   to: 1.0; duration: Appearance.anim.durations.expressiveDefaultSpatial; easing.type: Easing.OutBack }
                NumberAnimation { id: enterOpacityAnim; target: transformContainer; property: "opacity"; to: 1.0; duration: carouselContainer.mod._isIdle?Appearance.anim.durations.normal:Appearance.anim.durations.smaller; easing.type: Easing.OutSine }
                NumberAnimation { id: exitScaleAnim;    target: transformContainer; property: "scale";   to: 0.0; duration: Appearance.anim.durations.expressiveDefaultSpatial }
                NumberAnimation { id: exitOpacityAnim;  target: transformContainer; property: "opacity"; to: 0.0; duration: Appearance.anim.durations.expressiveDefaultSpatial }

                StyledClippingRect {
                    anchors.fill: parent; anchors.margins: Appearance.padding.small
                    radius: Appearance.rounding.large; color: Colours.palette.surface_variant

                    CachingImage { anchors.fill: parent; path: cardDelegate.path; asynchronous: true }

                    Rectangle {
                        anchors.bottom: parent.bottom; width: parent.width; height: parent.height/2
                        opacity: cardDelegate.isCenterCard?1.0:0.4
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.7) }
                        }
                    }

                    // Fav button
                    Item {
                        id: favArea; anchors.top: parent.top; anchors.right: parent.right; width: 40; height: 40
                        HoverHandler { id: favHov }
                        StyledRect {
                            anchors.centerIn: parent; width: 28; height: 28; radius: Appearance.rounding.full
                            color: cardDelegate.isFav ? Colours.alpha(Colours.palette.tertiary_container,0.9) : Colours.alpha(Colours.palette.surface,0.7)
                            opacity: cardDelegate.isFav || favHov.hovered ? 1.0 : 0.0; visible: opacity>0
                            scale: cardDelegate.isFav || favHov.hovered ? 1.0 : 0.7
                            Behavior on opacity { OpacityAnimator { duration: Appearance.anim.durations.smaller } }
                            Behavior on scale   { ScaleAnimator   { duration: Appearance.anim.durations.smaller; easing.type: Easing.OutBack } }
                            StyledIcon { anchors.centerIn: parent; text: cardDelegate.isFav?"\ue866":"\ue867"; font.pointSize: Appearance.font.size.normal; color: cardDelegate.isFav?Colours.palette.tertiary:Colours.palette.on_surface }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: carouselContainer.mod.toggleFavForIndex(cardDelegate.index) }
                        }
                    }

                    // Media type badge
                    Loader {
                        anchors.top: parent.top; anchors.right: favArea.left; anchors.topMargin: Appearance.padding.small; anchors.rightMargin: 2
                        active: cardDelegate.mediaType !== "image"
                        sourceComponent: StyledRect {
                            color: Colours.alpha(Colours.palette.tertiary_container,0.9); radius: Appearance.rounding.small
                            implicitWidth: _badgeTxt.implicitWidth + Appearance.padding.small*2; implicitHeight: _badgeTxt.implicitHeight + 2
                            StyledText { id: _badgeTxt; anchors.centerIn: parent; text: cardDelegate.mediaType==="video"?"MP4":cardDelegate.mediaType==="gif"?"GIF":cardDelegate.mediaType.toUpperCase(); font.pointSize: Appearance.font.size.smaller; font.weight: Font.DemiBold; color: Colours.palette.on_tertiary_container }
                        }
                    }

                    // Title
                    ColumnLayout {
                        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: Appearance.padding.medium; spacing: 2
                        opacity: cardDelegate.isCenterCard?1.0:0.0; visible: opacity>0
                        StyledText { Layout.fillWidth: true; text: cardDelegate.name; color: "white"; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        StyledText { Layout.fillWidth: true; text: cardDelegate.tags||cardDelegate.path; color: "lightgray"; font.pointSize: Appearance.font.size.smaller; elide: Text.ElideRight }
                    }

                    StateLayer { anchors.fill: parent; radius: Appearance.rounding.large; function onClicked() { carouselContainer.mod.execute("",false); } }
                }
            }

            onRemovingChanged: { if (removing) { exitScaleAnim.restart(); exitOpacityAnim.restart(); } }
        }

        path: carouselContainer.mod.isVertical ? _vertPath : _horizPath

        Path {
            id: _horizPath; startX: 0; startY: grid.height/2
            PathAttribute{name:"itemScale";value:0.45} PathAttribute{name:"itemOpacity";value:0.4} PathAttribute{name:"z";value:0}
            PathLine{x:grid.width*0.15;relativeY:0}
            PathAttribute{name:"itemScale";value:0.68} PathAttribute{name:"itemOpacity";value:0.6} PathAttribute{name:"z";value:1}
            PathLine{x:grid.width*0.32;relativeY:0}
            PathAttribute{name:"itemScale";value:0.84} PathAttribute{name:"itemOpacity";value:0.8} PathAttribute{name:"z";value:2}
            PathLine{x:grid.width*0.5;relativeY:0}
            PathAttribute{name:"itemScale";value:1.0}  PathAttribute{name:"itemOpacity";value:1.0} PathAttribute{name:"z";value:3}
            PathLine{x:grid.width*0.68;relativeY:0}
            PathAttribute{name:"itemScale";value:0.84} PathAttribute{name:"itemOpacity";value:0.8} PathAttribute{name:"z";value:2}
            PathLine{x:grid.width*0.85;relativeY:0}
            PathAttribute{name:"itemScale";value:0.68} PathAttribute{name:"itemOpacity";value:0.6} PathAttribute{name:"z";value:1}
            PathLine{x:grid.width;relativeY:0}
            PathAttribute{name:"itemScale";value:0.45} PathAttribute{name:"itemOpacity";value:0.4} PathAttribute{name:"z";value:0}
        }

        Path {
            id: _vertPath; startX: grid.width/2; startY: 0
            PathAttribute{name:"itemScale";value:0.45} PathAttribute{name:"itemOpacity";value:0.4} PathAttribute{name:"z";value:0}
            PathLine{relativeX:0;y:grid.height*0.15}
            PathAttribute{name:"itemScale";value:0.68} PathAttribute{name:"itemOpacity";value:0.6} PathAttribute{name:"z";value:1}
            PathLine{relativeX:0;y:grid.height*0.32}
            PathAttribute{name:"itemScale";value:0.84} PathAttribute{name:"itemOpacity";value:0.8} PathAttribute{name:"z";value:2}
            PathLine{relativeX:0;y:grid.height*0.5}
            PathAttribute{name:"itemScale";value:1.0}  PathAttribute{name:"itemOpacity";value:1.0} PathAttribute{name:"z";value:3}
            PathLine{relativeX:0;y:grid.height*0.68}
            PathAttribute{name:"itemScale";value:0.84} PathAttribute{name:"itemOpacity";value:0.8} PathAttribute{name:"z";value:2}
            PathLine{relativeX:0;y:grid.height*0.85}
            PathAttribute{name:"itemScale";value:0.68} PathAttribute{name:"itemOpacity";value:0.6} PathAttribute{name:"z";value:1}
            PathLine{relativeX:0;y:grid.height}
            PathAttribute{name:"itemScale";value:0.45} PathAttribute{name:"itemOpacity";value:0.4} PathAttribute{name:"z";value:0}
        }
    }
}
