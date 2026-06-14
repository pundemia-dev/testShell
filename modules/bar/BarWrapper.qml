pragma ComponentBehavior: Bound

import qs.config
import qs.utils
import Quickshell
import QtQuick
import qs.components
import "content"

Item {
    id: root
    required property int screenHeight
    required property int screenWidth
    required property var manager
    required property ShellScreen screen

    // Visibility state
    property bool barVisible: Config.bar.enabled


    // Регистрация visibility через менеджер (с поддержкой pendingRequests)
    Component.onCompleted: {
        VisibilitiesManager.addVisibility(root.screen, "bar", "bar", false, Config.bar.enabled, "Toggle Bar");
    }

    // Слушаем изменения visibility от глобального менеджера
    Connections {
        target: VisibilitiesManager
        function onVisibilityChanged(screen: ShellScreen, name: string, state: bool) {
            if (screen === root.screen && name === "bar") {
                root.barVisible = state;
            }
        }
    }

    // Синхронизация Config.bar.enabled с visibility state
    Connections {
        target: Config.bar
        function onEnabledChanged() {
            VisibilitiesManager.setVisibility(root.screen, "bar", Config.bar.enabled);
        }
    }

    Binding on implicitWidth {
        when: Config.bar.orientation
        value: Config.bar.thickness.all
    }

    Binding on implicitHeight {
        when: !Config.bar.orientation
        value: Config.bar.thickness.all
    }
    // implicitWidth: Config.bar.orientation ? Config.bar.thickness : undefined
    // implicitHeight: Config.bar.orientation ? undefined : Config.bar.thickness
    function isTotalThickness() {
        // Возвращаем true, если все три свойства undefined, иначе false
        return (Config.bar.thickness.begin === undefined && Config.bar.thickness.center === undefined && Config.bar.thickness.end === undefined);
    }

    // Объявляем position как property
    property QtObject position: QtObject {
        // Content size
        property int wrapperWidth: Config.bar.orientation ? screenWidth - Config.bar.shortSideMargin.all * 2 : Config.bar.thickness.all
        property int wrapperHeight: Config.bar.orientation ? Config.bar.thickness.all : screenHeight - Config.bar.shortSideMargin.all * 2
        // Anchors
        property bool aLeft: (!Config.bar.orientation && !Config.bar.position)
        property bool aRight: (!Config.bar.orientation && Config.bar.position)
        property bool aTop: (Config.bar.orientation && !Config.bar.position)
        property bool aBottom: (Config.bar.orientation && Config.bar.position)
        property bool aHorizontalCenter: Config.bar.orientation
        property bool aVerticalCenter: !Config.bar.orientation
        // // Margins & offsets
        property int mLeft: !Config.bar.orientation && !Config.bar.position ? (Config.bar.orientation ? (Config.bar.shortSideMargin.all ?? 0) : (Config.bar.longSideMargin.all ?? 0)) : 0
        property int mRight: !Config.bar.orientation && Config.bar.position ? (Config.bar.orientation ? (Config.bar.shortSideMargin.all ?? 0) : (Config.bar.longSideMargin.all ?? 0)) : 0
        property int mTop: Config.bar.orientation && !Config.bar.position ? (Config.bar.orientation ? (Config.bar.longSideMargin.all ?? 0) : (Config.bar.shortSideMargin.all ?? 0)) : 0
        property int mBottom: Config.bar.orientation && Config.bar.position ? (Config.bar.longSideMargin ? (Config.bar.longSideMargin.all ?? 0) : (Config.bar.shortSideMargin ?? 0)) : 0
        property int vCenterOffset: 0
        property int hCenterOffset: 0
        // Rails contract
        property string mode: "push"
        property bool pinned: true
        property bool reservesSpace: true
        readonly property int layer: 0
        property int windowRounding: Config.bar.rounding.all
        property int invertedJoinRounding: (Config.bar.invertBaseRounding.all ?? false) ? Config.bar.rounding.all : 0
        property Component content: Combined {
            screen: root.screen
        }
    }
    property QtObject begin: QtObject {
        // Content size
        property int wrapperWidth: Config.bar.orientation ? 0 : (isTotalThickness() ? (Config.bar.thickness.all + Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0)) : (Config.bar.thickness.begin ?? Config.bar.thickness.all ?? 0))
        property int wrapperHeight: Config.bar.orientation ? (isTotalThickness() ? (Config.bar.thickness.all + Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0)) : (Config.bar.thickness.begin ?? Config.bar.thickness.all ?? 0)) : 0
        // Anchors
        property bool aLeft: !(!Config.bar.orientation && Config.bar.position)
        property bool aRight: !Config.bar.orientation && Config.bar.position
        property bool aTop: !(Config.bar.orientation && Config.bar.position)
        property bool aBottom: Config.bar.orientation && Config.bar.position
        property bool aHorizontalCenter: false
        property bool aVerticalCenter: false
        // Margins & offsets
        property int mLeft: !(!Config.bar.orientation && Config.bar.position) ? (Config.bar.orientation ? (Config.bar.shortSideMargin.begin ?? Config.bar.shortSideMargin.all ?? 0) : (Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0)) : 0
        property int mRight: !Config.bar.orientation && Config.bar.position ? (Config.bar.orientation ? (Config.bar.shortSideMargin.begin ?? Config.bar.shortSideMargin.all ?? 0) : (Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0)) : 0
        property int mTop: !(Config.bar.orientation && Config.bar.position) ? (Config.bar.orientation ? (Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.shortSideMargin.begin ?? Config.bar.shortSideMargin.all ?? 0)) : 0
        property int mBottom: Config.bar.orientation && Config.bar.position ? (Config.bar.longSideMargin ? (Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.shortSideMargin ?? Config.bar.shortSideMargin ?? 0)) : 0
        // Paddings
        property int pLeft: !Config.bar.orientation && !Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.orientation ? (Config.bar.paddings.begin ?? Config.bar.paddings.all ?? 0) : 0)
        property int pRight: !Config.bar.orientation && Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.orientation ? (Config.bar.paddings.begin ?? Config.bar.paddings.all ?? 0) : 0)
        property int pTop: Config.bar.orientation && !Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0) : (!Config.bar.orientation ? (Config.bar.paddings.begin ?? Config.bar.paddings.all ?? 0) : 0)
        property int pBottom: Config.bar.orientation && Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0) : (!Config.bar.orientation ? (Config.bar.paddings.begin ?? Config.bar.paddings.all ?? 0) : 0)
        // Rails contract
        property string mode: "push"
        property bool pinned: true
        property bool reservesSpace: true
        readonly property int layer: 0
        property int windowRounding: Config.bar.rounding.begin ?? Config.bar.rounding.all ?? 0
        property int invertedJoinRounding: (Config.bar.invertBaseRounding.begin ?? Config.bar.invertBaseRounding.all ?? false) ? (Config.bar.rounding.begin ?? Config.bar.rounding.all ?? 0) : 0

        property Component content: Begin {
            screen: root.screen
        }
    }
    property QtObject center: QtObject {
        // Content size
        property int wrapperWidth: Config.bar.orientation ? 0 : (isTotalThickness() ? (Config.bar.thickness.all + Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0)) : (Config.bar.thickness.center ?? Config.bar.thickness.all ?? 0))
        property int wrapperHeight: Config.bar.orientation ? (isTotalThickness() ? (Config.bar.thickness.all + Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0)) : (Config.bar.thickness.center ?? Config.bar.thickness.all ?? 0)) : 0
        // Anchors
        property bool aLeft: !Config.bar.orientation && !Config.bar.position
        property bool aRight: !Config.bar.orientation && Config.bar.position
        property bool aTop: Config.bar.orientation && !Config.bar.position
        property bool aBottom: Config.bar.orientation && Config.bar.position
        property bool aHorizontalCenter: Config.bar.orientation
        property bool aVerticalCenter: !Config.bar.orientation
        // Margins & offsets
        property int mLeft: !Config.bar.orientation && !Config.bar.position ? (Config.bar.orientation ? (Config.bar.shortSideMargin.center ?? Config.bar.shortSideMargin.all ?? 0) : (Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0)) : 0
        property int mRight: !Config.bar.orientation && Config.bar.position ? (Config.bar.orientation ? (Config.bar.shortSideMargin.center ?? Config.bar.shortSideMargin.all ?? 0) : (Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0)) : 0
        property int mTop: Config.bar.orientation && !Config.bar.position ? (Config.bar.orientation ? (Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.shortSideMargin.center ?? Config.bar.shortSideMargin.all ?? 0)) : 0
        property int mBottom: Config.bar.orientation && Config.bar.position ? (Config.bar.longSideMargin ? (Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.shortSideMargin.center ?? Config.bar.shortSideMargin ?? 0)) : 0
        // Paddings
        property int pLeft: !Config.bar.orientation && !Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.orientation ? (Config.bar.paddings.center ?? Config.bar.paddings.all ?? 0) : 0)
        property int pRight: !Config.bar.orientation && Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.orientation ? (Config.bar.paddings.center ?? Config.bar.paddings.all ?? 0) : 0)
        property int pTop: Config.bar.orientation && !Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0) : (!Config.bar.orientation ? (Config.bar.paddings.center ?? Config.bar.paddings.all ?? 0) : 0)
        property int pBottom: Config.bar.orientation && Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0) : (!Config.bar.orientation ? (Config.bar.paddings.center ?? Config.bar.paddings.all ?? 0) : 0)
        // Rails contract
        property string mode: "push"
        property bool pinned: true
        property bool reservesSpace: true
        readonly property int layer: 0
        property int windowRounding: Config.bar.rounding.center ?? Config.bar.rounding.all ?? 0
        property int invertedJoinRounding: (Config.bar.invertBaseRounding.center ?? Config.bar.invertBaseRounding.all ?? false) ? (Config.bar.rounding.center ?? Config.bar.rounding.all ?? 0) : 0
        property Component content: Center {
            screen: root.screen
        }
    }
    property QtObject end: QtObject {
        // Content size
        property int wrapperWidth: Config.bar.orientation ? 0 : (isTotalThickness() ? (Config.bar.thickness.all + Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0)) : (Config.bar.thickness.end ?? Config.bar.thickness.all ?? 0))
        property int wrapperHeight: Config.bar.orientation ? (isTotalThickness() ? (Config.bar.thickness.all + Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0)) : (Config.bar.thickness.end ?? Config.bar.thickness.all ?? 0)) : 0
        // Anchors
        property bool aLeft: !Config.bar.orientation && !Config.bar.position
        property bool aRight: !(!Config.bar.orientation && !Config.bar.position)
        property bool aTop: Config.bar.orientation && !Config.bar.position
        property bool aBottom: !(Config.bar.orientation && !Config.bar.position)
        property bool aHorizontalCenter: false
        property bool aVerticalCenter: false
        // Margins & offsets
        property int mLeft: !Config.bar.orientation && !Config.bar.position ? (Config.bar.orientation ? (Config.bar.shortSideMargin.end ?? Config.bar.shortSideMargin.all ?? 0) : (Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0)) : 0
        property int mRight: !(!Config.bar.orientation && !Config.bar.position) ? (Config.bar.orientation ? (Config.bar.shortSideMargin.end ?? Config.bar.shortSideMargin.all ?? 0) : (Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0)) : 0
        property int mTop: Config.bar.orientation && !Config.bar.position ? (Config.bar.orientation ? (Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.shortSideMargin.end ?? Config.bar.shortSideMargin.all ?? 0)) : 0
        property int mBottom: !(Config.bar.orientation && !Config.bar.position) ? (Config.bar.longSideMargin ? (Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.shortSideMargin.end ?? Config.bar.shortSideMargin.all ?? 0)) : 0
        // Paddings
        property int pLeft: !Config.bar.orientation && !Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.orientation ? (Config.bar.paddings.end ?? Config.bar.paddings.all ?? 0) : 0)
        property int pRight: !Config.bar.orientation && Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) : (Config.bar.orientation ? (Config.bar.paddings.end ?? Config.bar.paddings.all ?? 0) : 0)
        property int pTop: Config.bar.orientation && !Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) : (!Config.bar.orientation ? (Config.bar.paddings.end ?? Config.bar.paddings.all ?? 0) : 0)
        property int pBottom: Config.bar.orientation && Config.bar.position && isTotalThickness() ? Math.max(Config.bar.longSideMargin.begin ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.center ?? Config.bar.longSideMargin.all ?? 0, Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) - (Config.bar.longSideMargin.end ?? Config.bar.longSideMargin.all ?? 0) : (!Config.bar.orientation ? (Config.bar.paddings.end ?? Config.bar.paddings.all ?? 0) : 0)
        // Rails contract
        property string mode: "push"
        property bool pinned: true
        property bool reservesSpace: true
        readonly property int layer: 0
        property int windowRounding: Config.bar.rounding.end ?? Config.bar.rounding.all ?? 0
        property int invertedJoinRounding: (Config.bar.invertBaseRounding.end ?? Config.bar.invertBaseRounding.all ?? false) ? (Config.bar.rounding.end ?? Config.bar.rounding.all ?? 0) : 0
        property Component content: End {
            screen: root.screen
        }
    }

    anchors.leftMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
    anchors.topMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin
    anchors.rightMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
    anchors.bottomMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin

    // Whether backgrounds are currently registered, and under which mode they
    // were registered. Tracked so a later `separated` change (e.g. once the
    // async JSON config finishes loading) can tear down the old set with the
    // mode it was actually created in before requesting the new one.
    property bool _bgsActive: false
    property bool _bgsSeparated: false

    function _requestBgs(): void {
        if (Config.bar.separated) {
            root.manager.requestBackground(root.begin);
            root.manager.requestBackground(root.center);
            root.manager.requestBackground(root.end);
        } else {
            root.manager.requestBackground(root.position);
        }
    }

    function _removeBgs(separated: bool): void {
        if (separated) {
            root.manager.removeBackground(root.begin);
            root.manager.removeBackground(root.center);
            root.manager.removeBackground(root.end);
        } else {
            root.manager.removeBackground(root.position);
        }
    }

    // (Re)register backgrounds for the current `separated` mode, tearing down
    // any previously-registered set first. Safe to call on initial load and on
    // every later `separated` flip.
    function _applyBgs(): void {
        if (!barLoader.active)
            return;
        if (root._bgsActive)
            root._removeBgs(root._bgsSeparated);
        root._requestBgs();
        root._bgsActive = true;
        root._bgsSeparated = Config.bar.separated;
    }

    function _clearBgs(): void {
        if (!root._bgsActive)
            return;
        root._removeBgs(root._bgsSeparated);
        root._bgsActive = false;
    }

    // `separated` arrives late from the async JSON config and may be toggled at
    // runtime — re-apply instead of latching the value once in onCompleted.
    Connections {
        target: Config.bar
        function onSeparatedChanged(): void {
            root._applyBgs();
        }
    }

    Loader {
        id: barLoader
        active: root.barVisible
        anchors.fill: parent

        sourceComponent: Item {
            anchors.fill: parent

            Component.onCompleted: root._applyBgs()
            Component.onDestruction: root._clearBgs()
        }
    }
}
// pragma ComponentBehavior: Bound

// import qs.config
// import Quickshell
// import QtQuick
// import qs.utils

// Item {
//     id: root

//     implicitWidth: Config.bar.orientation ? Config.bar.thickness : undefined
//     implicitHeight: Config.bar.orientation ? undefined : Config.bar.thickness

//     QtObject {
//         id: position
//         property bool aLeft: false
//         property bool aRight: false
//         property bool aTop: false
//         property bool aBottom: true
//         property bool aHorizontalCenter: true
//         property bool aVerticalCenter: false
//         property int wrapperWidth: 600
//         property int wrapperHeight: 600
//         property bool reusable: true
//     }

//     anchors.leftMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
//     anchors.topMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin
//     anchors.rightMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
//     anchors.bottomMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin

//     Loader {
//         id: content
//         anchors.fill: parent

//         // anchors.left: !Config.bar.orientation && !Config.bar.position ? parent.left : undefined;
//         // anchors.top: Config.bar.orientation && !Config.bar.position ? parent.top : undefined;
//         // anchors.right: !Config.bar.orientation && Config.bar.position ? parent.right : undefined;
//         // anchors.bottom: Config.bar.orientation && Config.bar.position ? parent.bottom : undefined;

//         // anchors.leftMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
//         // anchors.topMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin
//         // anchors.rightMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
//         // anchors.bottomMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin

//         sourceComponent : Bar {
//             anchors.fill: parent
//             // anchors.left: !Config.bar.orientation && !Config.bar.position ? parent.left : undefined;
//             // anchors.top: Config.bar.orientation && !Config.bar.position ? parent.top : undefined;
//             // anchors.right: !Config.bar.orientation && Config.bar.position ? parent.right : undefined;
//             // anchors.bottom: Config.bar.orientation && Config.bar.position ? parent.bottom : undefined;

//             // anchors.leftMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
//             // anchors.topMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin
//             // anchors.rightMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
//             // anchors.bottomMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin
//         }

//         onLoaded: BackgroundsApi.requestBackground(root.position)
//     }
// }
