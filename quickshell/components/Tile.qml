import QtQuick
import "../services" as Services
Rectangle {
    id: root
    required property string glyph
    required property string label
    property bool active: false
    property bool available: true
    property bool selected: false
    property bool accentButton: false
    property bool wide: false
    property int columns: 3
    signal clicked
    width: root.wide ? parent.width : (parent.width - 8) / columns
    height: Services.Theme.tileHeight
    readonly property bool isHovered: hover.containsMouse
    color: !root.available ? Services.Theme.transparent : root.accentButton ? Services.Theme.accent : root.selected ? Services.Theme.accent : root.active ? Services.Theme.activeBg : root.isHovered ? Services.Theme.hoverBg : Services.Theme.surface
    border.width: root.selected && root.isHovered ? 1 : 0
    border.color: Services.Theme.accentFg
    opacity: root.available ? 1 : 0.45
    Column {
        anchors.centerIn: parent
        spacing: 2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.glyph
            color: !root.available ? Services.Theme.dim : root.accentButton ? Services.Theme.accentFg : root.selected ? Services.Theme.accentFg : root.active ? Services.Theme.accent : hover.containsMouse ? Services.Theme.fg : Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px14
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: !root.available ? Services.Theme.dim : root.accentButton ? Services.Theme.accentFg : root.selected ? Services.Theme.accentFg : (root.active || hover.containsMouse) ? Services.Theme.fg : Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px10
        }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
