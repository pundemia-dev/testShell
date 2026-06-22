import QtQuick

// Declarative settings contract for third-party modules. A module ships one
// of these (a lightweight sibling `<Name>.settings.qml`, or — for launcher
// modules — a `settingsSchema` property on the instance) and the settings UI
// renders it generically via SchemaForm, persisting values into
// Config.custom[key]. Official modules don't need this (they have typed
// sub-configs + hand-written pages). See docs/development/settings.md.
QtObject {
    id: root

    property string title: ""
    property string icon: ""          // tabler glyph for the nav entry
    property string key: ""           // subtree key inside Config.custom

    // Whole-schema advanced gate (hide the page in basic mode). Individual
    // fields can also carry their own `advanced: true`.
    property bool advanced: false

    // Each entry:
    // {
    //   key: "interval",            // key inside Config.custom[key]
    //   type: "bool"|"int"|"real"|"string"|"enum",
    //   label: "Refresh, min",
    //   description: "...",         // optional secondary line
    //   default: 30,
    //   advanced: false,            // optional, hidden unless advanced mode
    //   hint: { text: "...", media: "preview.gif" },  // optional
    //   min: 5, max: 120, step: 1,  // int / real
    //   options: ["C", "F"]         // enum
    // }
    property var fields: []
}
