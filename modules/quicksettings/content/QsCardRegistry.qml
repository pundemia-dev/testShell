import qs.config
import qs.components.misc

// Card slot of the quicksettings module: scans ../cards/<id>/ for
// `<id>.card.qml` manifests. Cards render stacked between the tab-page area
// and the fixed QuickToggles card.
PluginRegistry {
    readonly property var cards: active

    folder: Qt.resolvedUrl("../cards")
    suffix: "card"
    order: Config.quicksettings.cardsOrder ?? []
    disabled: Config.quicksettings.cardsDisabled ?? []
}
