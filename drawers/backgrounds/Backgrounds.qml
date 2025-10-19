pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.utils
import qs.config
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
        // ListElement{
        //     aLeft: true
        //     aTop: false
        //     aRight: false
        //     aBottom: true
        //     aVerticalCenter: false
        //     aHorizontalCenter: false
        //     wrapperWidth: 100
        //     wrapperHeight: 100
        // }
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
        BackgroundsApi.backgroundModel = root.itemsDataModel  
    }
    
    Instantiator {
        model: root.itemsDataModel
        delegate: Background {
            required property var modelData
            parent: root
            
            // Content size
            wrapperHeight: modelData.wrapperHeight
            wrapperWidth: modelData.wrapperWidth

            // Anchors
            aLeft: modelData.aLeft
            aTop: modelData.aTop
            aRight: modelData.aRight
            aBottom: modelData.aBottom
            aVerticalCenter: modelData.aVerticalCenter
            aHorizontalCenter: modelData.aHorizontalCenter

            // Margins & offsets
            mLeft: modelData.mLeft || Config.backgrounds.margins.left || 0
            mRight: modelData.mRight || Config.backgrounds.margins.right || 0
            mTop: modelData.mTop || Config.backgrounds.margins.top || 0
            mBottom: modelData.mBottom || Config.backgrounds.margins.bottom || 0
            vCenterOffset: modelData.vCenterOffset || Config.backgrounds.offsets.vCenterOffset || 0
            hCenterOffset: modelData.hCenterOffset || Config.backgrounds.offsets.hCenterOffset || 0

            // Base settings
            rounding: modelData.rounding || Config.backgrounds.rounding || 0
            invertBaseRounding: modelData.invertBaseRounding ?? Config.backgrounds.invertBaseRounding ?? false

            // Access zone
            zWidth: root.width
            zHeight: root.height

            // Exclusions
            left_area: root.left_area
            top_area: root.top_area
            right_area: root.right_area
            bottom_area: root.bottom_area

            excludeBarArea: modelData.excludeBarArea ?? true// || modelData.excludeBarArea
        }
    }
}