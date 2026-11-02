import QtQuick
import "../services" as Services
Rectangle {
    id: root
    required property string label
    property bool selected: false
    property bool accent: false
    property int columns: 2
    signal clicked
    width: (parent.width - (columns - 1) * Services.Theme.popupSpacing) / columns
    height: Services.Theme.rowHeight
    readonly property bool lit: root.accent || root.selected
    readonly property bool isHovered: hover.containsMouse
    color: root.lit ? Services.Theme.accent : root.isHovered ? Services.Theme.hoverBg : Services.Theme.surface
    border.width: root.lit && root.isHovered ? 1 : 0
    border.color: Services.Theme.accentFg
    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.lit ? Services.Theme.accentFg : Services.Theme.fg
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px12
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
