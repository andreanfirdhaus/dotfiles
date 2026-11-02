import QtQuick
import "../services" as Services

Flow {
    id: root
    property var actions: []
    property int focusedIndex: -1
    signal picked(var action)
    visible: (root.actions ?? []).length > 0
    spacing: 6
    Repeater {
        model: root.actions
        delegate: Rectangle {
            required property var modelData
            required property int index
            readonly property bool focused: index === root.focusedIndex
            width: actionLabel.width + 16
            height: 24
            readonly property bool isHovered: actionArea.containsMouse
            color: focused ? Services.Theme.accent : isHovered ? Services.Theme.hoverBg : Services.Theme.surface
            border.width: focused && isHovered ? 1 : 0
            border.color: Services.Theme.accentFg
            Text {
                id: actionLabel
                anchors.centerIn: parent
                text: modelData.text
                color: parent.focused ? Services.Theme.accentFg : Services.Theme.fg
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px12
            }
            MouseArea {
                id: actionArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    mouse.accepted = true;
                    root.picked(modelData);
                }
            }
        }
    }
}
