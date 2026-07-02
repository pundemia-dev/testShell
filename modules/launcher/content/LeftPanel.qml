pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.components.controls
import qs.components.containers
import qs.config
import qs.services

StyledRect {
    id: root

    property real rightViewWidth: 0
    property bool pathViaTop: true
    property bool pathViaLeft: true

    property alias model: innerListView.model
    property alias delegate: innerListView.delegate
    property alias listView: innerListView
    property alias implicitListHeight: innerListView.implicitHeight

    color: "transparent"

    AnimScrollBar {
        id: scrollContainer
        anchors.fill: parent
        position: root.rightViewWidth === 0 ? "right" : "left"
        flickable: innerListView
        viaTop: root.pathViaTop
        viaLeft: root.pathViaLeft
        barThickness: 6
        barSpacing: 8

        contentItem: Item {
            anchors.fill: parent

            Row {
                anchors.centerIn: parent
                visible: innerListView.count === 0
                opacity: 0.45
                spacing: Appearance.spacing.medium

                StyledRect {
                    implicitWidth: implicitHeight
                    implicitHeight: hintIcon.implicitHeight + Appearance.padding.small * 2
                    radius: Appearance.rounding.full
                    color: Colours.palette.surface_variant
                    anchors.verticalCenter: parent.verticalCenter

                    StyledIcon {
                        id: hintIcon
                        anchors.centerIn: parent
                        text: "\uee6d"
                        font.pointSize: Appearance.font.size.large
                        color: Colours.palette.on_surface_variant
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("try to type something")
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.on_surface_variant
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            StyledListView {
                id: innerListView
                anchors.fill: parent
                clip: true
                spacing: 4

                implicitHeight: (Config.launcher.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing

                onCountChanged: if (count > 0) currentIndex = 0

            add: Transition {
                Anim { properties: "opacity,scale"; from: 0; to: 1 }
            }
            remove: Transition {
                Anim { properties: "opacity,scale"; from: 1; to: 0 }
            }
            move: Transition {
                Anim { property: "y" }
                Anim { properties: "opacity,scale"; to: 1 }
            }
            addDisplaced: Transition {
                Anim { property: "y"; duration: Appearance.anim.durations.small }
                Anim { properties: "opacity,scale"; to: 1 }
            }
            displaced: Transition {
                Anim { property: "y" }
                Anim { properties: "opacity,scale"; to: 1 }
            }
            }
        }
    }
}
// pragma ComponentBehavior: Bound

// import QtQuick
// import QtQuick.Layouts
// import qs.components
// import qs.components.controls
// import qs.components.containers

// StyledRect {
//     id: root

//     // Переменная ширины правого окна (приходит извне)
//     // Если 0 - правое окно закрыто, скроллбар справа. Иначе - слева.
//     property real rightViewWidth: 0
//     property bool pathViaTop: false
//     property alias contentHeight: innerListView.contentHeight
//     onContentHeightChanged: console.log("[LeftPanel] contentHeight changed:", contentHeight)

//         // true -> перетекание сверху вниз и обратно всегда через ЛЕВО
//     property bool pathViaLeft: true
//     onRightViewWidthChanged: {
//         console.log("Right view width changed to:", rightViewWidth);
//     }


//     // Проксируем модель, чтобы задавать её снаружи
//     property alias model: innerListView.model
//     onModelChanged: {
//         console.log("[LeftPanel] model changed:", model, "count:", model?.count)
//         if (model) {
//             model.countChanged.connect(() => {
//                 console.log("[LeftPanel] model count changed:", model.count)
//             })
//         }
//     }
//     property alias delegate: innerListView.delegate// В LeftPanel.qml добавь:
//     // property alias listView: scrollContainer.contentItem // или как у тебя там называется id самого StyledListView
//     property alias listView: innerListView

//     color: "transparent" // Или цвет твоего фона левой панели

//     AnimScrollBar {
//         id: scrollContainer
//         anchors.fill: parent

//         // Автоматическое переключение стороны (триггерит ползающую анимацию)
//         // position: root.rightViewWidth === 0 ? "left" : "right"
//         position: root.rightViewWidth === 0 ? "right" : "left"
//         // position: root.rightViewWidth === 0 ? "top" : "bottom"

//         // Подключаем к Flickable (StyledListView наследуется от Flickable/ListView)
//         flickable: listView
//         viaTop: root.pathViaTop
//         viaLeft: root.pathViaLeft

//         // Внешний вид бара
//         barThickness: 6
//         barSpacing: 8

//         contentItem: StyledListView {
//             id: innerListView
//             anchors.fill: parent
//             clip: true

//             // Настройки списка
//             spacing: 4
//             onCountChanged: console.log("[ListView] count:", count, "width:", width, "height:", height)
//             onWidthChanged: console.log("[ListView] width changed:", width)
//             onHeightChanged: console.log("[ListView] height changed:", height)

//             // Дефолтная модель для проверки, если не задана
//             // model: 50
//             // delegate: StyledRect { width: listView.width; height: 40; color: "#333" }
//             add: Transition {
//                     Anim {
//                         properties: "opacity,scale"
//                         from: 0
//                         to: 1
//                     }
//                 }

//                 remove: Transition {
//                     Anim {
//                         properties: "opacity,scale"
//                         from: 1
//                         to: 0
//                     }
//                 }

//                 move: Transition {
//                     Anim { property: "y" }
//                     Anim { properties: "opacity,scale"; to: 1 }
//                 }

//                 addDisplaced: Transition {
//                     Anim {
//                         property: "y"
//                         duration: Appearance.anim.durations.small
//                     }
//                     Anim { properties: "opacity,scale"; to: 1 }
//                 }

//                 displaced: Transition {
//                     Anim { property: "y" }
//                     Anim { properties: "opacity,scale"; to: 1 }
//                 }
//         }
//     }
// }
