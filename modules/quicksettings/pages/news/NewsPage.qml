pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.containers
import qs.components.controls
import Quickshell
import QtQuick
import QtQuick.Layouts

// RSS news fed by the News service (feeds in Config.quicksettings.newsFeeds),
// grouped by source in the same card style as the notifications page. Rows
// open in the browser.
Item {
    id: root

    // Feed sources whose groups are currently expanded. Reassigned (not
    // mutated in place) so the NewsGroup `expanded` bindings re-evaluate.
    property list<string> expandedSources: []

    function setSourceExpanded(source: string, expand: bool): void {
        if (expand && !expandedSources.includes(source))
            expandedSources = [...expandedSources, source];
        else if (!expand && expandedSources.includes(source))
            expandedSources = expandedSources.filter(s => s !== source);
    }

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

    StyledFlickable {
        id: view

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Appearance.spacing.medium

        clip: true
        flickableDirection: Flickable.VerticalFlick
        contentWidth: width
        contentHeight: groupList.implicitHeight

        Column {
            id: groupList

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.small

            Repeater {
                model: ScriptModel {
                    values: {
                        const map = new Map();
                        for (const a of News.articles)
                            map.set(a.source, null);
                        return [...map.keys()];
                    }
                }

                delegate: NewsGroup {
                    page: root
                }
            }
        }
    }

    StyledScrollBar {
        flickable: view
        anchors.right: parent.right
        anchors.top: view.top
        anchors.bottom: view.bottom
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
