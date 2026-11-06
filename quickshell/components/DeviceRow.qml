import QtQuick
import "../services" as Services

Row {
    id: root
    property bool selected: false
    property bool hovered: false
    property bool accented: false
    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property int glyphWidth: 18
    property int reserveRight: 58
    property bool showForget: false
    signal forgetRequested()
    default property alias trailing: trailer.data
    anchors {
        fill: parent
        leftMargin: 8
        rightMargin: 8
    }
    spacing: Services.Theme.popupSpacing
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: root.glyphWidth
        text: root.glyph
        color: root.selected ? Services.Theme.accentFg : root.accented ? Services.Theme.accent : root.hovered ? Services.Theme.fg : Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px13
    }
    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - root.reserveRight
        spacing: 2
        Text {
            width: parent.width
            text: root.title
            color: root.selected ? Services.Theme.accentFg : (root.accented || root.hovered) ? Services.Theme.fg : Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px12
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.subtitle
            color: root.selected ? Services.Theme.accentFg : root.hovered ? Services.Theme.fg : Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px10
        }
    }
    Row {
        id: trailer
        anchors.verticalCenter: parent.verticalCenter
        spacing: Services.Theme.popupSpacing
    }
    Text {
        id: forgetButton
        visible: root.showForget
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        horizontalAlignment: Text.AlignHCenter
        text: "󰅖"
        color: root.selected ? Services.Theme.accentFg : forgetArea.containsMouse ? Services.Theme.fg : Services.Theme.dim
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px13
        MouseArea {
            id: forgetArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                mouse.accepted = true;
                root.forgetRequested();
            }
        }
    }
}
