pragma ComponentBehavior: Bound

import qs.config
import qs.services
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
        // True when no per-segment thickness override is set. Uses == null so it
        // catches BOTH undefined (fresh) and null (how an unset field comes back
        // from shell.json after a reload) — otherwise the "total" mode would
        // silently drop on the first reload. Fields only ever hold a number,
        // null, or undefined, so == null is exactly "unset".
        return (Config.bar.thickness.begin == null && Config.bar.thickness.center == null && Config.bar.thickness.end == null);
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
        property Component content: End {
            screen: root.screen
        }
    }

    anchors.leftMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
    anchors.topMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin
    anchors.rightMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
    anchors.bottomMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin

    // Slots currently registered with the rails manager. Reconciled against
    // the desired set on every input change (separated mode, a segment's
    // layout emptying/filling, edit mode, loader lifecycle) — a segment with
    // no widgets keeps no background unless the layout editor needs it as a
    // drop target.
    property var _activeSlots: []

    function _desiredSlots(): var {
        const editing = BarEditManager.editing;
        if (Config.bar.separated) {
            const out = [];
            if (editing || (Config.bar.beginLayout || []).length > 0)
                out.push(root.begin);
            if (editing || (Config.bar.centerLayout || []).length > 0)
                out.push(root.center);
            if (editing || (Config.bar.endLayout || []).length > 0)
                out.push(root.end);
            return out;
        }
        const any = (Config.bar.beginLayout || []).length > 0 || (Config.bar.centerLayout || []).length > 0 || (Config.bar.endLayout || []).length > 0;
        return editing || any ? [root.position] : [];
    }

    function _syncBgs(): void {
        if (!barLoader.active)
            return; // teardown runs via _clearBgs from the loader item's destruction
        const desired = root._desiredSlots();
        for (const s of root._activeSlots)
            if (desired.indexOf(s) < 0)
                root.manager.removeBackground(s);
        for (const s of desired)
            if (root._activeSlots.indexOf(s) < 0)
                root.manager.requestBackground(s);
        root._activeSlots = desired;
    }

    function _clearBgs(): void {
        for (const s of root._activeSlots)
            root.manager.removeBackground(s);
        root._activeSlots = [];
    }

    // Edge flip (orientation/position): the slot set is unchanged, only the
    // rail each one belongs to. Relocate in place — no teardown, no dying ghost.
    function _relocateBgs(): void {
        for (const s of root._activeSlots)
            root.manager.relocateBackground(s);
    }

    // `separated` and the layouts arrive late from the async JSON config and
    // may change at runtime — reconcile instead of latching once in onCompleted.
    //
    // `orientation`/`position` choose the rail, and a slot's rail is fixed at
    // requestBackground time — it doesn't move when the bare bool flips, so the
    // bar stays on its old edge until something re-registers it. (Editing
    // shell.json masked this: FileView.reload() re-runs the adapter and
    // incidentally fires onSeparatedChanged → _syncBgs.) Relocate the slots in
    // place instead — atomic, no dying ghost. Route through Qt.callLater so the
    // two writes setEdge makes (orientation then position) collapse into ONE
    // relocate on the next tick, with both bools already final.
    Connections {
        target: Config.bar
        function onSeparatedChanged(): void {
            root._syncBgs();
        }
        function onBeginLayoutChanged(): void {
            root._syncBgs();
        }
        function onCenterLayoutChanged(): void {
            root._syncBgs();
        }
        function onEndLayoutChanged(): void {
            root._syncBgs();
        }
        function onOrientationChanged(): void {
            Qt.callLater(root._relocateBgs);
        }
        function onPositionChanged(): void {
            Qt.callLater(root._relocateBgs);
        }
    }

    // Edit mode needs every slot present as a drop target, even empty ones.
    Connections {
        target: BarEditManager
        function onEditingChanged(): void {
            root._syncBgs();
        }
    }

    Loader {
        id: barLoader
        active: root.barVisible
        anchors.fill: parent

        sourceComponent: Item {
            anchors.fill: parent

            Component.onCompleted: root._syncBgs()
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
