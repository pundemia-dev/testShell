pragma Singleton
pragma ComponentBehavior: Bound

import qs.components.misc
import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    property list<Notif> list: []
    readonly property list<Notif> notClosed: list.filter(n => !n.closed)
    readonly property list<Notif> popups: list.filter(n => n.popup)
    property bool dnd: false

    onListChanged: {
        if (loaded)
            saveTimer.restart();
    }

    property bool loaded

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: storage.setText(JSON.stringify((Config.notifs.historyLimit > 0 ? root.notClosed.slice(0, Config.notifs.historyLimit) : root.notClosed).map(n => ({
                    time: n.time,
                    id: n.id,
                    summary: n.summary,
                    body: n.body,
                    appIcon: n.appIcon,
                    appName: n.appName,
                    image: n.image,
                    expireTimeout: n.expireTimeout,
                    urgency: n.urgency,
                    resident: n.resident,
                    hasActionIcons: n.hasActionIcons,
                    actions: n.actions
                }))))
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;

            const comp = notifComp.createObject(root, {
                popup: !root.dnd,
                notification: notif
            });
            const limit = Config.notifs.historyLimit;
            const next = [comp, ...root.list];
            if (limit > 0 && next.length > limit) {
                const overflow = next.slice(limit);
                root.list = next.slice(0, limit);
                // Drop the oldest entries past the cap so the in-memory list
                // (and the persisted file) stays bounded across a long session.
                for (const old of overflow)
                    old.destroy();
            } else {
                root.list = next;
            }
        }
    }

    FileView {
        id: storage

        path: `${Paths.state}/notifs.json`
        onLoaded: {
            // Sort + cap the raw data BEFORE materialising Notif objects, then
            // assign root.list exactly once. Pushing in a loop made the derived
            // `notClosed`/`popups` filter bindings recompute on every insert
            // (O(n²)) and created one live QObject per history entry — with a
            // large notifs.json this stalled shell startup for 30-50s.
            const data = JSON.parse(text());
            data.sort((a, b) => b.time - a.time);
            const limit = Config.notifs.historyLimit;
            const kept = limit > 0 ? data.slice(0, limit) : data;
            root.list = kept.map(notif => notifComp.createObject(root, notif));
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                setText("[]");
            }
        }
    }

    IpcHandler {
        target: "notifs"

        function clear(): void {
            for (const notif of root.list.slice())
                notif.close();
        }

        function isDndEnabled(): bool {
            return root.dnd;
        }

        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }

        function enableDnd(): void {
            root.dnd = true;
        }

        function disableDnd(): void {
            root.dnd = false;
        }
    }

    component Notif: QtObject {
        id: notif

        property bool popup
        property bool closed
        property var locks: new Set()

        property date time: new Date()
        readonly property string timeStr: {
            const diff = Time.date.getTime() - time.getTime();
            const m = Math.floor(diff / 60000);

            if (m < 1)
                return qsTr("now");

            const h = Math.floor(m / 60);
            const d = Math.floor(h / 24);

            if (d > 0)
                return `${d}d`;
            if (h > 0)
                return `${h}h`;
            return `${m}m`;
        }

        property Notification notification
        property string id
        property string summary
        property string body
        property string appIcon
        property string appName
        property string image
        property real expireTimeout: Config.notifs.defaultExpireTimeout
        property int urgency: NotificationUrgency.Normal
        property bool resident
        property bool hasActionIcons
        property list<var> actions

        readonly property Timer timer: Timer {
            // Only run while the notification is actually a live popup. Loaded
            // history entries (popup === false) must not each spin up a Timer.
            running: notif.popup
            interval: notif.expireTimeout > 0 ? notif.expireTimeout : Config.notifs.defaultExpireTimeout
            onTriggered: {
                if (Config.notifs.expire)
                    notif.popup = false;
            }
        }

        readonly property LazyLoader dummyImageLoader: LazyLoader {
            active: false

            PanelWindow {
                implicitWidth: Config.notifs.sizes.image
                implicitHeight: Config.notifs.sizes.image
                color: "transparent"
                mask: Region {}

                Image {
                    function tryCache(): void {
                        if (status !== Image.Ready || width != Config.notifs.sizes.image || height != Config.notifs.sizes.image)
                            return;

                        const cacheKey = notif.appName + notif.summary + notif.id;
                        let h1 = 0xdeadbeef, h2 = 0x41c6ce57, ch;
                        for (let i = 0; i < cacheKey.length; i++) {
                            ch = cacheKey.charCodeAt(i);
                            h1 = Math.imul(h1 ^ ch, 2654435761);
                            h2 = Math.imul(h2 ^ ch, 1597334677);
                        }
                        h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507);
                        h1 ^= Math.imul(h2 ^ (h2 >>> 13), 3266489909);
                        h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507);
                        h2 ^= Math.imul(h1 ^ (h1 >>> 13), 3266489909);
                        const hash = (h2 >>> 0).toString(16).padStart(8, 0) + (h1 >>> 0).toString(16).padStart(8, 0);

                        const cache = `${Paths.notifimagecache}/${hash}.png`;
                        this.grabToImage(result => {
                            if (result && result.saveToFile(cache)) {
                                notif.image = cache;
                            }
                            notif.dummyImageLoader.active = false;
                        });
                    }

                    anchors.fill: parent
                    source: Qt.resolvedUrl(notif.image)
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: true
                    opacity: 0

                    onStatusChanged: tryCache()
                    onWidthChanged: tryCache()
                    onHeightChanged: tryCache()
                }
            }
        }

        readonly property Connections conn: Connections {
            target: notif.notification

            function onClosed(): void {
                notif.close();
            }

            function onSummaryChanged(): void {
                notif.summary = notif.notification.summary;
            }

            function onBodyChanged(): void {
                notif.body = notif.notification.body;
            }

            function onAppIconChanged(): void {
                notif.appIcon = notif.notification.appIcon;
            }

            function onAppNameChanged(): void {
                notif.appName = notif.notification.appName;
            }

            function onImageChanged(): void {
                notif.image = notif.notification.image;
                if (notif.notification?.image)
                    notif.dummyImageLoader.active = true;
            }

            function onExpireTimeoutChanged(): void {
                notif.expireTimeout = notif.notification.expireTimeout;
            }

            function onUrgencyChanged(): void {
                notif.urgency = notif.notification.urgency;
            }

            function onResidentChanged(): void {
                notif.resident = notif.notification.resident;
            }

            function onHasActionIconsChanged(): void {
                notif.hasActionIcons = notif.notification.hasActionIcons;
            }

            function onActionsChanged(): void {
                notif.actions = notif.notification.actions.map(a => ({
                            identifier: a.identifier,
                            text: a.text,
                            invoke: () => a.invoke()
                        }));
            }
        }

        function lock(item: Item): void {
            locks.add(item);
        }

        function unlock(item: Item): void {
            locks.delete(item);
            if (closed)
                close();
        }

        function close(): void {
            closed = true;
            if (locks.size === 0 && root.list.includes(this)) {
                root.list = root.list.filter(n => n !== this);
                notification?.dismiss();
                destroy();
            }
        }

        Component.onCompleted: {
            if (!notification)
                return;

            id = notification.id;
            summary = notification.summary;
            body = notification.body;
            appIcon = notification.appIcon;
            appName = notification.appName;
            image = notification.image;
            if (notification?.image)
                dummyImageLoader.active = true;
            expireTimeout = notification.expireTimeout;
            urgency = notification.urgency;
            resident = notification.resident;
            hasActionIcons = notification.hasActionIcons;
            actions = notification.actions.map(a => ({
                        identifier: a.identifier,
                        text: a.text,
                        invoke: () => a.invoke()
                    }));
        }
    }

    Component {
        id: notifComp

        Notif {}
    }
}
