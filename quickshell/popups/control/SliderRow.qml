import QtQuick
import "../../components"
import "../../services" as Services

Rectangle {
    id: root
    required property var popup
    property int rowIndex: 0
    property string glyph: ""
    property real sliderValue: 0
    property real sliderMaximum: 1
    property real sliderStep: 0
    property string valueLabel: ""
    signal sliderMoved(real newValue)
    signal glyphClicked()

    width: parent.width
    height: Services.Theme.rowHeight
    readonly property bool isHovered: rowHover.containsMouse
    color: popup.selectedIndex === root.rowIndex ? Services.Theme.activeBg : root.isHovered ? Services.Theme.hoverBg : Services.Theme.surface
    border.width: popup.selectedIndex === root.rowIndex ? 1 : 0
    border.color: root.isHovered ? Services.Theme.fg : Services.Theme.accent
    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
    }
    Row {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
        }
        spacing: 10
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            text: root.glyph
            color: Services.Theme.fg
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px14
            MouseArea {
                anchors.fill: parent
                onClicked: root.glyphClicked()
            }
        }
        SliderBar {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 80
            maximum: root.sliderMaximum
            wheelStep: root.sliderStep
            value: root.sliderValue
            onSliderMoved: value => root.sliderMoved(value)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            horizontalAlignment: Text.AlignRight
            text: root.valueLabel
            color: Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px12
        }
    }
}
