import QtQuick

// Base manifest for one unit of an intra-module extension point (a dashboard
// page, an AI page, a future widget, …). Each unit lives in its own folder
// under the host's slot dir (`<slot>/<id>/`) and ships a lightweight
// `<id>.<slot-singular>.qml` extending this type — metadata only; the actual
// UI is the lazily-instantiated `content` Component, so discovery stays cheap.
// PluginRegistry scans the slot dir and stamps `id`; hosts render `content`
// through a Loader. Subclass per slot when extra contract fields are needed.
QtObject {
    // Stable key, stamped by the registry from the unit's folder name. Host
    // config order/disabled lists key on it so persistence survives renames
    // of the human-readable title.
    property string id: ""

    // Declared by the unit itself:
    property string title: ""
    property string icon: ""          // tabler glyph (Appearance.font.family.tabler)

    // Default ordering hint for units not listed in the host's order config.
    property int order: 100

    // Optional SettingsSchema — lets the settings module surface the unit's
    // settings generically (values live in Config.custom[schema.key]).
    property var settingsSchema: null

    // The unit's UI, built on demand by the host's Loader.
    property Component content: null
}
