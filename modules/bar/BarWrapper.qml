pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import QtQuick
import qs.utils 

Item {
    id: root
    required property int screenHeight
    required property int screenWidth

    Binding on implicitWidth {
        when: Config.bar.orientation
        value: Config.bar.thickness
    }
    
    Binding on implicitHeight {
        when: !Config.bar.orientation
        value: Config.bar.thickness
    }
    // implicitWidth: Config.bar.orientation ? Config.bar.thickness : undefined
    // implicitHeight: Config.bar.orientation ? undefined : Config.bar.thickness
    
    // Объявляем position как property
    property QtObject position: QtObject {
        // Content size
        property int wrapperWidth: Config.bar.orientation ? screenWidth - Config.bar.shortSideMargin * 2 : Config.bar.thickness
        property int wrapperHeight: Config.bar.orientation ? Config.bar.thickness : screenHeight - Config.bar.shortSideMargin * 2
        // Anchors
        property bool aLeft: (!Config.bar.orientation && !Config.bar.position)
        property bool aRight: (!Config.bar.orientation && Config.bar.position)
        property bool aTop: (Config.bar.orientation && !Config.bar.position)
        property bool aBottom: (Config.bar.orientation && Config.bar.position)
        property bool aHorizontalCenter: Config.bar.orientation
        property bool aVerticalCenter: !Config.bar.orientation
        // // Margins & offsets
        property int vCenterOffset: 0
        property int hCenterOffset: 0
        // Base settings
        property int rounding: Config.bar.rounding.all
        property bool invertBaseRounding: Config.bar.invertBaseRounding.all
        // Bar exclusion
        property bool excludeBarArea: false
        // Reusability
        property bool reusable: Config.bar.reusability.all
    }
    property QtObject begin: QtObject {
        // Content size
        property int wrapperWidth: Config.bar.orientation ? 300 : Config.bar.thickness
        property int wrapperHeight: Config.bar.orientation ? Config.bar.thickness : 300
        // Anchors
        property bool aLeft: !(!Config.bar.orientation && Config.bar.position)
        property bool aRight: !Config.bar.orientation && Config.bar.position
        property bool aTop: !(Config.bar.orientation && Config.bar.position)
        property bool aBottom: Config.bar.orientation && Config.bar.position
        property bool aHorizontalCenter: false
        property bool aVerticalCenter: false
        // Margins & offsets
        property int mLeft: !(!Config.bar.orientation && Config.bar.position) ? (Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin) : 0
        property int mRight: !Config.bar.orientation && Config.bar.position ? (Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin) : 0
        property int mTop: !(Config.bar.orientation && Config.bar.position) ? (Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin) : 0
        property int mBottom: Config.bar.orientation && Config.bar.position ? (Config.bar.longSideMargin ? Config.bar.longSideMargin : Config.bar.shortSideMargin) : 0
        // Base settings
        property int rounding: Config.bar.rounding.begin ?? Config.bar.rounding.all ?? undefined
        property bool invertBaseRounding: Config.bar.invertBaseRounding.begin ?? (Config.bar.invertBaseRounding.all ?? undefined)
        // Bar exclusion
        property bool excludeBarArea: false
        // Reusability
        property bool reusable: Config.bar.reusability.begin ?? Config.bar.reusability.all// ?? undefined
    }
    property QtObject center: QtObject {
        // Content size
        property int wrapperWidth: Config.bar.orientation ? 250 : Config.bar.thickness
        property int wrapperHeight: Config.bar.orientation ? Config.bar.thickness : 300
        // Anchors
        property bool aLeft: !Config.bar.orientation && !Config.bar.position
        property bool aRight: !Config.bar.orientation && Config.bar.position
        property bool aTop: Config.bar.orientation && !Config.bar.position
        property bool aBottom: Config.bar.orientation && Config.bar.position 
        property bool aHorizontalCenter: Config.bar.orientation
        property bool aVerticalCenter: !Config.bar.orientation
        // Margins & offsets
        property int mLeft: !Config.bar.orientation && !Config.bar.position ? (Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin) : 0
        property int mRight: !Config.bar.orientation && Config.bar.position ? (Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin) : 0
        property int mTop: Config.bar.orientation && !Config.bar.position ? (Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin) : 0
        property int mBottom: Config.bar.orientation && Config.bar.position ? (Config.bar.longSideMargin ? Config.bar.longSideMargin : Config.bar.shortSideMargin) : 0
        // Base settings
        property int rounding: Config.bar.rounding.center ?? Config.bar.rounding.all ?? undefined
        property bool invertBaseRounding: Config.bar.invertBaseRounding.center ?? Config.bar.invertBaseRounding.all ?? undefined
        // Bar exclusion
        property bool excludeBarArea: false
        // Reusability
        property bool reusable: Config.bar.reusability.center ?? Config.bar.reusability.all ?? undefined
    }
    property QtObject end: QtObject {
        // Content size
        property int wrapperWidth: Config.bar.orientation ? 300 : Config.bar.thickness
        property int wrapperHeight: Config.bar.orientation ? Config.bar.thickness : 300
        // Anchors
        property bool aLeft: !Config.bar.orientation && !Config.bar.position
        property bool aRight: !(!Config.bar.orientation && !Config.bar.position)
        property bool aTop: Config.bar.orientation && !Config.bar.position
        property bool aBottom: !(Config.bar.orientation && !Config.bar.position)
        property bool aHorizontalCenter: false
        property bool aVerticalCenter: false
        // Margins & offsets
        property int mLeft: !Config.bar.orientation && !Config.bar.position ? (Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin) : 0
        property int mRight: !(!Config.bar.orientation && !Config.bar.position) ? (Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin) : 0
        property int mTop: Config.bar.orientation && !Config.bar.position ? (Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin) : 0
        property int mBottom: !(Config.bar.orientation && !Config.bar.position) ? (Config.bar.longSideMargin ? Config.bar.longSideMargin : Config.bar.shortSideMargin) : 0
        // Base settings
        property int rounding: Config.bar.rounding.end ?? Config.bar.rounding.all ?? undefined
        property bool invertBaseRounding: Config.bar.invertBaseRounding.end ?? Config.bar.invertBaseRounding.all ?? undefined
        // Bar exclusion
        property bool excludeBarArea: false
        // Reusability
        property bool reusable: Config.bar.reusability.end ?? Config.bar.reusability.all ?? undefined
    }

    anchors.leftMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
    anchors.topMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin
    anchors.rightMargin: Config.bar.orientation ? Config.bar.shortSideMargin : Config.bar.longSideMargin
    anchors.bottomMargin: Config.bar.orientation ? Config.bar.longSideMargin : Config.bar.shortSideMargin

    Loader {
        id: content
        anchors.fill: parent
        sourceComponent : Bar {
            anchors.fill: parent
        }
        
        onLoaded: {
            console.log("BarWrapper: Loader loaded, calling requestBackground");
            console.log("BarWrapper: position object:", root.position);
            console.log("BarWrapper: position.wrapperWidth:", root.position.wrapperWidth);
            if (Config.bar.separated) {
                BackgroundsApi.requestBackground(root.begin, true)
                BackgroundsApi.requestBackground(root.center, true)
                BackgroundsApi.requestBackground(root.end, true)
                //console.warn("no background")
            }else
                BackgroundsApi.requestBackground(root.position, true);
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
