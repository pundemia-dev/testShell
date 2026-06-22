import Quickshell.Io

// Shell-wide preferences that don't belong to a single module. Currently
// just the settings-UI basic/advanced disclosure state; grows over time.
JsonObject {
    // Settings UI disclosure level. false = basic (advanced elements hidden),
    // true = advanced (everything shown). One rule everywhere:
    //   visible: !element.advanced || Config.general.advanced
    property bool advanced: false
}
