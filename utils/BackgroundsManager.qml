// BackgroundsApi.qml
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

QtObject {
    id: root
    
    property var slots: null
    property var isolatedBackgrounds: []
    property var pendingRequests: []
    
    function registerSlots(slotsArray) {
        root.slots = slotsArray;
        console.log("BackgroundsApi: Registered", slotsArray.length, "background slots");
        
        if (root.pendingRequests.length > 0) {
            console.log("BackgroundsApi: Processing", root.pendingRequests.length, "pending requests");
            for (let i = 0; i < root.pendingRequests.length; i++) {
                const req = root.pendingRequests[i];
                root.requestBackground(req.wrapper, req.isolate, req.excludeBarArea);
            }
            root.pendingRequests = [];
        }
    }
    
    function determineSlotIndex(wrapper) {
        const left = wrapper.aLeft ?? false;
        const right = wrapper.aRight ?? false;
        const top = wrapper.aTop ?? false;
        const bottom = wrapper.aBottom ?? false;
        const hCenter = wrapper.aHorizontalCenter ?? false;
        const vCenter = wrapper.aVerticalCenter ?? false;
        
        if (top && !vCenter) {
            if (left && !hCenter) return 0;
            if (hCenter) return 1;
            if (right && !hCenter) return 2;
        }
        
        if (vCenter || (!top && !bottom)) {
            if (left && !hCenter) return 3;
            if (hCenter || (!left && !right)) return 4;
            if (right && !hCenter) return 5;
        }
        
        if (bottom && !vCenter) {
            if (left && !hCenter) return 6;
            if (hCenter) return 7;
            if (right && !hCenter) return 8;
        }
        
        return 4;
    }
    
    function requestBackground(wrapper, isolate = false, excludeBarArea = true) {
        if (!wrapper) {
            console.error("BackgroundsApi: wrapper is null!");
            return;
        }
        
        if (!root.slots && !isolate) {
            console.warn("BackgroundsApi: Slots not registered yet. Queuing request.");
            root.pendingRequests.push({
                wrapper: wrapper,
                isolate: isolate,
                excludeBarArea: excludeBarArea
            });
            return;
        }
        
        if (isolate) {
            console.log("BackgroundsApi: Creating isolated background");
            root.isolatedBackgrounds.push({
                wrapper: wrapper,
                excludeBarArea: excludeBarArea
            });
            root.isolatedBackgrounds = root.isolatedBackgrounds;
        } else {
            const slotIndex = determineSlotIndex(wrapper);
            const slot = root.slots[slotIndex];
            
            if (!slot) {
                console.error("BackgroundsApi: Slot", slotIndex, "not found");
                return;
            }
            
            console.log("BackgroundsApi: Assigning wrapper to slot", slotIndex);
            
            // Просто присваиваем wrapper - биндинги сделают всё остальное
            slot.wrapper = wrapper;
            slot.excludeBarArea = excludeBarArea;
            
            if (!slot.active) {
                slot.active = true;
            }
        }
    }
}