import QtQuick
import "../services" as Services
Row {
    id: root
    required property int choice
    required property string noLabel
    required property string yesLabel
    property bool accentYes: false
    signal picked(int index)
    width: parent.width
    spacing: Services.Theme.popupSpacing
    PopupButton {
        label: root.noLabel
        columns: 2
        selected: root.choice === 0
        onClicked: root.picked(0)
    }
    PopupButton {
        label: root.yesLabel
        columns: 2
        accent: root.accentYes
        selected: root.choice === 1
        onClicked: root.picked(1)
    }
}
