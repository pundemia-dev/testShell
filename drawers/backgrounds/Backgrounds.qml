pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.utils
import "components"
import QtQml.Models

Item {
    id: root
    required property int border_area
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area
    anchors.fill: parent
    
    property ListModel itemsDataModel: ListModel {
        id: itemsDataModel
        ListElement{
            aLeft: true
            aTop: false
            aRight: false
            aBottom: true
            aVerticalCenter: false
            aHorizontalCenter: false
            wrapperWidth: 100
            wrapperHeight: 100
        }
        // ,
        // {
        //     aLeft: false,
        //     aTop: true,
        //     aRight: true,
        //     aBottom: false,
        //     aVerticalCenter: false,
        //     aHorizontalCenter: false,
        //     wrapperWidth: 150,
        //     wrapperHeight: 150
        // }
    }
    
    Component.onCompleted: {
        BackgroundsApi.backgroundModel = root.itemsDataModel  // Не root.itemsData!
    }
    
    Instantiator {
        model: root.itemsDataModel
        delegate: Background {
              required property var modelData
            parent: root
            
            aLeft: modelData.aLeft
            aTop: modelData.aTop
            aRight: modelData.aRight
            aBottom: modelData.aBottom
            aVerticalCenter: modelData.aVerticalCenter
            aHorizontalCenter: modelData.aHorizontalCenter
            rounding: 20
            invertBaseRounding: true
            wrapperHeight: modelData.wrapperHeight
            wrapperWidth: modelData.wrapperWidth
            zWidth: root.width
            zHeight: root.height
            left_area: root.left_area
            top_area: root.top_area
            right_area: root.right_area
            bottom_area: root.bottom_area
            // required property bool aLeft            
            // required property bool aTop
            // required property bool aRight
            // required property bool aBottom
            // required property bool aVerticalCenter
            // required property bool aHorizontalCenter
            // required property int wrapperWidth
            // required property int wrapperHeight
            
            // parent: root
            
            // // aLeft: aLeft
            // // aTop: aTop
            // // aRight: aRight
            // // aBottom: aBottom
            // // aVerticalCenter: aVerticalCenter
            // // aHorizontalCenter: aHorizontalCenter
            // rounding: 20
            // invertBaseRounding: true
            // // wrapperHeight: wrapperHeight
            // // wrapperWidth: wrapperWidth
            // zWidth: root.width
            // zHeight: root.height
        }
    }
}