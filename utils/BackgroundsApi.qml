pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property var backgroundModel: null
    property var pendingRequests: []

    onBackgroundModelChanged: {
        if (root.backgroundModel && root.pendingRequests.length > 0) {
            console.log("BackgroundsApi: Processing", root.pendingRequests.length, "pending requests");
            for (let i = 0; i < root.pendingRequests.length; i++) {
                const req = root.pendingRequests[i];
                root.requestBackground(req.position, req.forceNew);
            }
            root.pendingRequests = [];
        }
    }

    function positionToPlainObject(position) {
        if (!position) {
            console.error("BackgroundsApi: position is null or undefined!");
            return null;
        }
        
        return {
            // Content size
            wrapperWidth: position.wrapperWidth ?? undefined,
            wrapperHeight: position.wrapperHeight ?? undefined,
            // Anchors
            aLeft: position.aLeft ?? undefined,
            aTop: position.aTop ?? undefined,
            aRight: position.aRight ?? undefined,
            aBottom: position.aBottom ?? undefined,
            aVerticalCenter: position.aVerticalCenter ?? undefined,
            aHorizontalCenter: position.aHorizontalCenter ?? undefined,
            // Margins & offsets
            mLeft: position.mLeft ?? undefined,
            mRight: position.mRight ?? undefined,
            mTop: position.mTop ?? undefined,
            mBottom: position.mBottom ?? undefined,
            vCenterOffset: position.vCenterOffset ?? undefined,
            hCenterOffset: position.hCenterOffset ?? undefined,
            // Base settings
            rounding: position.rounding,
            invertBaseRounding: position.invertBaseRounding ?? undefined,
            // Bar exclusion
            excludeBarArea: position.excludeBarArea,// ?? undefined,
            // Reusability
            reusable: position.reusable ?? undefined,
        };
    }

    function requestBackground(position, forceNew = false) {
        console.log("BackgroundsApi: requestBackground called with position:", position);
        
        const plainPosition = root.positionToPlainObject(position);
        
        if (!plainPosition) {
            console.error("BackgroundsApi: Failed to convert position to plain object");
            return;
        }
        
        if (!root.backgroundModel) {
            console.warn("BackgroundsApi: backgroundModel is not yet registered. Queuing request.");
            root.pendingRequests.push({ "position": plainPosition, "forceNew": forceNew });
            root.pendingRequests = root.pendingRequests;
            return;
        }

        for (let i = 0; i < root.backgroundModel.count; i++) {
            const existingConfig = root.backgroundModel.get(i);
            if (root.compareConfigs(existingConfig, plainPosition) && !forceNew) {
                console.log("BackgroundsApi: Found existing background, updating");
                root.backgroundModel.set(i, plainPosition);
                return;
            }
        }

        console.log("BackgroundsApi: Adding new background", plainPosition.wrapperWidth, "x", plainPosition.wrapperHeight);
        root.backgroundModel.append(plainPosition);
        return;
    }

    function compareConfigs(conf1, conf2) {
        return conf1.aLeft === conf2.aLeft &&
               conf1.aTop === conf2.aTop &&
               conf1.aRight === conf2.aRight &&
               conf1.aBottom === conf2.aBottom &&
               conf1.aVerticalCenter === conf2.aVerticalCenter &&
               conf1.aHorizontalCenter === conf2.aHorizontalCenter &&
               conf1.reusable;
    }
}