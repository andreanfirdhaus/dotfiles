import QtQuick
import "../services" as Services
Rectangle {
    id: root
    required property string title
    property string value: ""
    property int titleWidth: 110
    property bool selected: false
    default property alias control: slot.data
    width: parent.width
    height: Services.Theme.rowHeight
    readonly property bool isHovered: hoverArea.containsMouse
    color: root.selected ? Services.Theme.activeBg : root.isHovered ? Services.Theme.hoverBg : Services.Theme.surface
    border.width: root.selected ? 1 : 0
    border.color: root.isHovered ? Services.Theme.fg : Services.Theme.accent
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
    }
    Text {
        anchors {
            left: parent.left
            leftMargin: 10
            verticalCenter: parent.verticalCenter
        }
        width: root.titleWidth
        text: root.title
        color: Services.Theme.fg
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px12
        elide: Text.ElideRight
    }
    Item {
        id: slot
        anchors {
            left: parent.left
            leftMargin: 10 + root.titleWidth + 14
            right: parent.right
            rightMargin: root.value !== "" ? 48 : 10
            verticalCenter: parent.verticalCenter
        }
        height: parent.height
    }
    Text {
        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        visible: root.value !== ""
        text: root.value
        color: Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px12
    }
}
