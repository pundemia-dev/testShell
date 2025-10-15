pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import QtQuick
import qs.utils 

Item {
    id: root

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
        property bool aLeft: false
        property bool aRight: false
        property bool aTop: false
        property bool aBottom: true
        property bool aHorizontalCenter: true
        property bool aVerticalCenter: false
        property int wrapperWidth: 600
        property int wrapperHeight: 600
        property bool reusable: true
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
            BackgroundsApi.requestBackground(root.position, false);
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
