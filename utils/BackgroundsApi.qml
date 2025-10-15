pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell

// Singleton {
//     id: root

//     property var backgroundModel: null
//     property var pendingRequest: null

//     onBackgroundModelChanged: {
//         if (root.backgroundModel && root.pendingRequest) {
//             root.requestBackground(root.pendingRequest.wrapper, root.pendingRequest.forceNew);
//             root.pendingRequest = null; // Очищаем отложенный запрос
//         }
//     }

//     // Эта функция будет вызывать BarWrapper.qml
//     function requestBackground(position, forceNew = false) {
//         // Если модель еще не готова, сохраняем запрос и выходим
//         if (!root.backgroundModel) {
//             console.warn("BackgroundsApi: backgroundModel is not yet registered. Queuing request.")
//             root.pendingRequest = { "position": position, "forceNew": forceNew };
//             return;
//         }

//         // const newConfig = getAnchorConfig(wrapper);
//         // newConfig.forceNew = forceNew;
//         // newConfig.wrapperHeight = wrapper.height;
//         // newConfig.wrapperWidth = wrapper.width;

//         for (let i = 0; i < root.backgroundModel.count; i++) {
//             const existingConfig = root.backgroundModel.get(i);
//             if (root.compareConfigs(existingConfig, position) && !forceNew) {
//                 root.backgroundModel.setProperty(i, "position", position);
//                 return;
//             }
//         }
//         // console.warn(newConfig.wrapper.anchors.right)
//         root.backgroundModel.append(position);
//     }

//     // Вспомогательные функции, перенесенные из Backgrounds.qml
//     function getAnchorConfig(wrapper) {
//         return {
//             aLeft: wrapper.anchors.left !== undefined,
//             aTop: wrapper.anchors.top !== undefined,
//             aRight: wrapper.anchors.right !== undefined,
//             aBottom: wrapper.anchors.bottom !== undefined,
//             aVerticalCenter: wrapper.anchors.verticalCenter !== undefined,
//             aHorizontalCenter: wrapper.anchors.horizontalCenter !== undefined
//         };
//     }

//     function compareConfigs(conf1, conf2) {
//         return conf1.aLeft === conf2.aLeft &&
//                conf1.aTop === conf2.aTop &&
//                conf1.aRight === conf2.aRight &&
//                conf1.aBottom === conf2.aBottom &&
//                conf1.aVerticalCenter === conf2.aVerticalCenter &&
//                conf1.aHorizontalCenter === conf2.aHorizontalCenter;
//     }
// }

// pragma ComponentBehavior: Bound
// pragma Singleton
// import QtQuick
// import Quickshell

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

    // Конвертирует QtObject в plain JavaScript объект
    function positionToPlainObject(position) {
        if (!position) {
            console.error("BackgroundsApi: position is null or undefined!");
            return null;
        }
        
        return {
            aLeft: position.aLeft ?? false,
            aTop: position.aTop ?? false,
            aRight: position.aRight ?? false,
            aBottom: position.aBottom ?? false,
            aVerticalCenter: position.aVerticalCenter ?? false,
            aHorizontalCenter: position.aHorizontalCenter ?? false,
            wrapperWidth: position.wrapperWidth ?? 200,
            wrapperHeight: position.wrapperHeight ?? 200
        };
    }

    function requestBackground(position, forceNew = false) {
        console.log("BackgroundsApi: requestBackground called with position:", position);
        
        // Конвертируем QtObject в plain object
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

        // Проверяем, существует ли уже такая конфигурация
        for (let i = 0; i < root.backgroundModel.count; i++) {
            const existingConfig = root.backgroundModel.get(i);
            if (root.compareConfigs(existingConfig, plainPosition) && !forceNew) {
                console.log("BackgroundsApi: Found existing background, updating");
                root.backgroundModel.set(i, plainPosition);
                return;
            }
        }

        // Добавляем новый элемент
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
               conf1.aHorizontalCenter === conf2.aHorizontalCenter;
    }
}