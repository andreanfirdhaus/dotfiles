import QtQuick
import "../services" as Services

Rectangle {
    id: root
    required property bool selected
    property bool highlighted: false
    property int rowHeight: Services.Theme.rowHeight
    property color baseColor: Services.Theme.transparent
    signal clicked()
    readonly property bool isHovered: rowArea.containsMouse
    width: ListView.view.width
    height: root.rowHeight
    color: root.selected ? Services.Theme.accent : root.isHovered ? Services.Theme.hoverBg : (root.highlighted ? Services.Theme.activeBg : root.baseColor)
    border.width: root.selected && root.isHovered ? 1 : 0
    border.color: Services.Theme.accentFg
    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
