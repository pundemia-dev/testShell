pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick
import QtQuick.Layouts

// One card per feed source, mirroring the notifications page's NotifGroup:
// leading glyph circle, header row (source name, newest time, count pill with
// expand chevron), then the article list. Collapsed shows the first
// newsPreviewNum article titles; expanded shows everything with timestamps.
StyledRect {
    id: root

    required property string modelData
    required property var page

    readonly property list<var> articles: News.articles.filter(a => a.source === modelData)
    readonly property bool expanded: page.expandedSources.includes(modelData)

    function toggleExpand(expand: bool): void {
        page.setSourceExpanded(modelData, expand);
    }

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: Math.round(Math.max(Config.notifs.sizes.image, header.implicitHeight + (expanded ? Appearance.spacing.extraSmall : 0) + articleList.implicitHeight) + Appearance.padding.medium * 2)

    clip: true
    radius: Appearance.rounding.large
    color: Colours.tPalette.surface_container

    Behavior on implicitHeight {
        Anim {}
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.medium

        spacing: Appearance.spacing.medium

        StyledRect {
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            implicitWidth: Config.notifs.sizes.image
            implicitHeight: Config.notifs.sizes.image

            color: Colours.layer(Colours.palette.surface_container_high, 3)
            radius: Appearance.rounding.full

            StyledIcon {
                anchors.centerIn: parent
                text: "\ueb19" // tabler rss
                color: Colours.palette.on_surface
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: root.expanded ? Appearance.spacing.extraSmall : 0

            Behavior on spacing {
                Anim {}
            }

            RowLayout {
                id: header

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.modelData
                    color: Colours.palette.on_surface_variant
                    font: Appearance.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    animate: true
                    text: root.page.timeAgo(root.articles[0]?.published ?? 0)
                    color: Colours.palette.outline
                    font: Appearance.font.body.small
                }

                StyledRect {
                    implicitWidth: expandBtn.implicitWidth + Appearance.padding.large
                    implicitHeight: groupCount.implicitHeight + Appearance.padding.extraSmall

                    color: Colours.layer(Colours.palette.surface_container_high, 3)
                    radius: Appearance.rounding.full

                    StateLayer {
                        radius: parent.radius
                        function onClicked(): void {
                            root.toggleExpand(!root.expanded);
                        }
                    }

                    RowLayout {
                        id: expandBtn

                        anchors.centerIn: parent
                        spacing: Appearance.spacing.extraSmall

                        StyledText {
                            id: groupCount

                            Layout.leftMargin: Appearance.padding.extraSmall / 2
                            animate: true
                            text: root.articles.length
                            color: Colours.palette.on_surface_variant
                            font: Appearance.font.body.small
                        }

                        StyledIcon {
                            Layout.rightMargin: -Appearance.padding.extraSmall / 2
                            text: "\uea5f" // tabler chevron-down
                            color: Colours.palette.on_surface_variant
                            rotation: root.expanded ? 180 : 0

                            Behavior on rotation {
                                Anim {}
                            }
                        }
                    }
                }
            }

            Column {
                id: articleList

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Appearance.spacing.extraSmall

                Repeater {
                    model: ScriptModel {
                        values: root.expanded ? root.articles : root.articles.slice(0, Config.quicksettings.newsPreviewNum)
                    }

                    delegate: StyledRect {
                        id: article

                        required property var modelData

                        width: parent?.width ?? 0
                        implicitHeight: articleCol.implicitHeight + (article.expanded ? Appearance.padding.medium * 2 : 0)

                        readonly property bool expanded: root.expanded

                        radius: Appearance.rounding.medium
                        color: expanded ? Colours.layer(Colours.palette.surface_container_high, 2) : Qt.alpha(Colours.palette.surface_container_high, 0)

                        Behavior on implicitHeight {
                            Anim {}
                        }

                        StateLayer {
                            radius: article.radius
                            function onClicked(): void {
                                if (article.modelData.link)
                                    Quickshell.execDetached(["xdg-open", article.modelData.link]);
                            }
                        }

                        ColumnLayout {
                            id: articleCol

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: article.expanded ? Appearance.padding.medium : 0
                            spacing: Appearance.spacing.extraSmall

                            Behavior on anchors.margins {
                                Anim {}
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: article.modelData.title
                                elide: Text.ElideRight
                                wrapMode: Text.WordWrap
                                maximumLineCount: article.expanded ? 4 : 1
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: article.expanded
                                text: root.page.timeAgo(article.modelData.published)
                                color: Colours.palette.outline
                                font: Appearance.font.label.small
                            }
                        }
                    }
                }
            }
        }
    }
}
