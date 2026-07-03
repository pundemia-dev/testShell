import QtQuick

// Manifest for one modular dashboard page. Each page lives in its own folder
// under modules/dashboard/pages/<id>/ and ships a lightweight `<Name>.page.qml`
// that is a DashboardPage declaring the page's own title + icon (the contract),
// plus a lazily-instantiated `content` Component. DashboardRegistry discovers
// these manifests (cheap: metadata only, content isn't built until a Loader
// uses it) and the tab view renders them. See modules/dashboard/content/.
QtObject {
    // Stable key, assigned by the registry from the page's folder name. Used by
    // Config.dashboard.order / .disabled so persistence survives renames of the
    // human-readable title.
    property string id: ""

    // Declared by the page itself:
    property string title: ""
    property string icon: ""          // tabler glyph (Appearance.font.family.tabler)

    // Default ordering hint for pages not yet listed in Config.dashboard.order.
    property int order: 100

    // The actual page UI, built on demand by the tab view's Loader.
    property Component content: null
}
