// BackgroundSlots.qml
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import "components"

Item {
    id: root
    required property int border_area
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area
    required property var manager
    anchors.fill: parent
    
    property var slots: [
        slot0, slot1, slot2,
        slot3, slot4, slot5,
        slot6, slot7, slot8
    ]
    
    Component.onCompleted: {
        root.manager.registerSlots(root.slots);
    }
    
    // Компонент Background
    Component {
        id: backgroundComponent
        
        Background {
            wrapper: parent.wrapper
            excludeBarArea: parent.excludeBarArea
            
            // Anchors берутся из parent (Loader)
            aLeft: parent.aLeft
            aTop: parent.aTop
            aRight: parent.aRight
            aBottom: parent.aBottom
            aVerticalCenter: parent.aVerticalCenter
            aHorizontalCenter: parent.aHorizontalCenter
            
            zWidth: root.width
            zHeight: root.height
            
            left_area: root.left_area
            top_area: root.top_area
            right_area: root.right_area
            bottom_area: root.bottom_area
        }
    }
    
    // Slot 0: Top Left
    Loader {
        id: slot0
        active: false
        asynchronous: false
        property var wrapper: null
        property bool excludeBarArea: false
        
        // Статичные anchors для Top Left
        readonly property bool aLeft: true
        readonly property bool aTop: true
        readonly property bool aRight: false
        readonly property bool aBottom: false
        readonly property bool aVerticalCenter: false
        readonly property bool aHorizontalCenter: false
        
        sourceComponent: backgroundComponent
    }
    
    // Slot 1: Top Center
    Loader {
        id: slot1
        active: false
        asynchronous: false
        property var wrapper: null
        property bool excludeBarArea: false
        
        // Статичные anchors для Top Center
        readonly property bool aLeft: false
        readonly property bool aTop: true
        readonly property bool aRight: false
        readonly property bool aBottom: false
        readonly property bool aVerticalCenter: false
        readonly property bool aHorizontalCenter: true
        
        sourceComponent: backgroundComponent
    }
    
    // Slot 2: Top Right
    Loader {
        id: slot2
        active: false
        asynchronous: false
        property var wrapper: null
        property bool excludeBarArea: false
        
        // Статичные anchors для Top Right
        readonly property bool aLeft: false
        readonly property bool aTop: true
        readonly property bool aRight: true
        readonly property bool aBottom: false
        readonly property bool aVerticalCenter: false
        readonly property bool aHorizontalCenter: false
        
        sourceComponent: backgroundComponent
    }
    
    // Slot 3: Center Left
    Loader {
        id: slot3
        active: false
        asynchronous: false
        property var wrapper: null
        property bool excludeBarArea: false
        
        // Статичные anchors для Center Left
        readonly property bool aLeft: true
        readonly property bool aTop: false
        readonly property bool aRight: false
        readonly property bool aBottom: false
        readonly property bool aVerticalCenter: true
        readonly property bool aHorizontalCenter: false
        
        sourceComponent: backgroundComponent
    }
    
    // Slot 4: Center
    Loader {
        id: slot4
        active: false
        asynchronous: false
        property var wrapper: null
        property bool excludeBarArea: false
        
        // Статичные anchors для Center
        readonly property bool aLeft: false
        readonly property bool aTop: false
        readonly property bool aRight: false
        readonly property bool aBottom: false
        readonly property bool aVerticalCenter: true
        readonly property bool aHorizontalCenter: true
        
        sourceComponent: backgroundComponent
    }
    
    // Slot 5: Center Right
    Loader {
        id: slot5
        active: false
        asynchronous: false
        property var wrapper: null
        property bool excludeBarArea: false
        
        // Статичные anchors для Center Right
        readonly property bool aLeft: false
        readonly property bool aTop: false
        readonly property bool aRight: true
        readonly property bool aBottom: false
        readonly property bool aVerticalCenter: true
        readonly property bool aHorizontalCenter: false
        
        sourceComponent: backgroundComponent
    }
    
    // Slot 6: Bottom Left
    Loader {
        id: slot6
        active: false
        asynchronous: false
        property var wrapper: null
        property bool excludeBarArea: false
        
        // Статичные anchors для Bottom Left
        readonly property bool aLeft: true
        readonly property bool aTop: false
        readonly property bool aRight: false
        readonly property bool aBottom: true
        readonly property bool aVerticalCenter: false
        readonly property bool aHorizontalCenter: false
        
        sourceComponent: backgroundComponent
    }
    
    // Slot 7: Bottom Center
    Loader {
        id: slot7
        active: false
        asynchronous: false
        property var wrapper: null
        property bool excludeBarArea: false
        
        // Статичные anchors для Bottom Center
        readonly property bool aLeft: false
        readonly property bool aTop: false
        readonly property bool aRight: false
        readonly property bool aBottom: true
        readonly property bool aVerticalCenter: false
        readonly property bool aHorizontalCenter: true
        
        sourceComponent: backgroundComponent
    }
    
    // Slot 8: Bottom Right
    Loader {
        id: slot8
        active: false
        asynchronous: false
        property var wrapper: null
        property bool excludeBarArea: false
        
        // Статичные anchors для Bottom Right
        readonly property bool aLeft: false
        readonly property bool aTop: false
        readonly property bool aRight: true
        readonly property bool aBottom: true
        readonly property bool aVerticalCenter: false
        readonly property bool aHorizontalCenter: false
        
        sourceComponent: backgroundComponent
    }
    
    // Repeater для isolated backgrounds
    Instantiator {
        model: root.manager.isolatedBackgrounds
        
        delegate: Loader {
            required property int index
            
            parent: root
            active: true
            asynchronous: false
            
            property var bgData: root.manager.isolatedBackgrounds[index] ?? null
            property var wrapper: bgData?.wrapper ?? null
            property bool excludeBarArea: bgData?.excludeBarArea ?? false
            
            readonly property bool aLeft: wrapper?.aLeft ?? false
            readonly property bool aTop: wrapper?.aTop ?? false
            readonly property bool aRight: wrapper?.aRight ?? false
            readonly property bool aBottom: wrapper?.aBottom ?? false
            readonly property bool aVerticalCenter: wrapper?.aVerticalCenter ?? false
            readonly property bool aHorizontalCenter: wrapper?.aHorizontalCenter ?? false
            
            sourceComponent: backgroundComponent
        }
    }
}