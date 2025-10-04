import QrQuick.Layouts

GridLayout {
    anchors.fill: parent
    required property int itemsCount

    states: [
        State {
            when: Config.bar.orientation
            PropertyChanges { target: root; columns: itemsCount }
            PropertyChanges { target: root; rows: 0 }
        },
        State {
            when: Config.bar.orientation
            PropertyChanges { target: root; columns: 0 }
            PropertyChanges { target: root; rows: itemsCount }
        }
    ]
}