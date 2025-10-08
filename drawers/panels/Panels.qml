
Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property Item bar
    required property int border_area
    required property int left_area
    required property int top_area
    required property int right_area
    required property int bottom_area

    // readonly property 

    anchors.fill: parent
    anchors.leftMargin: left_area
    anchors.topMargin: top_area
    anchors.rightMargin: right_area
    anchors.bottomMargin: bottom_area

    // Osd.Wrapper {
    //     id:

    //     visibilities:

    //     anchors.left: Config.osd.anchors.left ? parent.left : undefined
    //     anchors.top: Config.osd.anchors.top ? parent.top : undefined
    //     anchors.right: Config.osd.anchors.right ? parent.right : undefined
    //     anchors.bottom: Config.osd.anchors.bottom ? parent.bottom : undefined
    //     anchors.verticalCenter: Config.osd.anchors.verticalCenter ? parent.verticalCenter : undefined
    //     anchors.horizontalCenter: Config.osd.anchors.horizontalCenter ? parent.horizontalCenter : undefined

    //     anchors.marginsLeft: Config.osd.margins.vertical
    //     anchors.marginsTop: Config.osd.margins.horizontal
    //     anchors.marginsRight: Config.osd.margins.vertical
    //     anchors.marginsBottom: Config.osd.margins.horizontal
    //     anchors.verticalCenterOffset: min(wrapper.centerOffset+-wrapper.length/2, parent.verticalOffset)
    //     anchors.horizontalCenterOffset: wrapper.centerOffset
    // }
}