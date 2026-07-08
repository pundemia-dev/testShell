pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.containers
import qs.components.controls
import Quickshell
import QtQuick
import QtQuick.Layouts

// RSS news list fed by the News service (feeds in
// Config.quicksettings.newsFeeds). Rows open in the browser.
Item {
    id: root

    function timeAgo(epochS: real): string {
        if (!epochS)
            return "";
        const m = Math.floor((Time.date.getTime() - epochS * 1000) / 60000);
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

    RowLayout {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("News")
            font: Appearance.font.title.small
        }

        LoadingIndicator {
            visible: News.loading
            implicitWidth: Appearance.font.size.large
            implicitHeight: Appearance.font.size.large
        }

        IconButton {
            icon: "\ueb13" // tabler refresh
            isRound: true
            type: IconButton.Text
            disabled: News.loading
            onClicked: News.refresh()
        }
    }

    StyledListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Appearance.spacing.medium

        clip: true
        spacing: Appearance.spacing.small
        model: News.articles

        delegate: StyledRect {
            id: row

            required property var modelData

            width: list.width
            implicitHeight: rowCol.implicitHeight + Appearance.padding.medium * 2
            radius: Appearance.rounding.medium
            color: Colours.tPalette.surface_container

            StateLayer {
                radius: row.radius
                function onClicked(): void {
                    if (row.modelData.link)
                        Quickshell.execDetached(["xdg-open", row.modelData.link]);
                }
            }

            ColumnLayout {
                id: rowCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Appearance.padding.medium
                spacing: Appearance.spacing.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.source
                        color: Colours.palette.primary
                        font: Appearance.font.label.small
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        text: root.timeAgo(row.modelData.published)
                        color: Colours.palette.on_surface_variant
                        font: Appearance.font.label.small
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.title
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    elide: Text.ElideRight
                    maximumLineCount: 3
                }
            }
        }
    }

    StyledScrollBar {
        flickable: list
        anchors.right: parent.right
        anchors.top: list.top
        anchors.bottom: list.bottom
    }

    // Empty state.
    ColumnLayout {
        anchors.centerIn: parent
        visible: News.articles.length === 0 && !News.loading
        spacing: Appearance.spacing.small

        StyledIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "\ueafd" // tabler news
            color: Colours.palette.on_surface_variant
            font.pointSize: Appearance.font.size.extraLarge
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: (Config.quicksettings.newsFeeds ?? []).length === 0 ? qsTr("Add feeds in Settings → Quicksettings") : qsTr("No news yet")
            color: Colours.palette.on_surface_variant
        }
    }
}
