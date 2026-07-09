import "weather"
import QtQuick
import qs.components
import qs.services
import qs.config

StyledRect {
    id: root

    required property int rootHeight
    readonly property bool showForecast: rootHeight >= Config.lock.sizes.showForecastHeight

    implicitHeight: {
        const base = brief.implicitHeight + brief.anchors.topMargin;
        if (showForecast)
            return base + Appearance.spacing.largeIncreased + forecast.implicitHeight + forecast.anchors.margins;
        return base + brief.anchors.topMargin;
    }
    radius: Appearance.rounding.extraExtraLarge
    color: Colours.tPalette.surface_container

    Timer {
        running: true
        triggeredOnStart: true
        repeat: true
        interval: 900000 // 15 minutes
        onTriggered: Weather.reload()
    }

    BriefInfo {
        id: brief

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Appearance.padding.extraLarge

        rootHeight: root.rootHeight
    }

    Loader {
        id: forecast

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.large

        active: root.showForecast
        asynchronous: true

        sourceComponent: Forecast {}
    }
}
