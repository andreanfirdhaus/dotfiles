import QtQuick
import Quickshell
import Quickshell.Wayland
import "../components"
import "../services" as Services

PanelWindow {
    id: slim
    required property var targetScreen
    screen: slim.targetScreen
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Services.Theme.barHeight
    exclusiveZone: implicitHeight
    color: Services.Theme.barBg
    BarDivider {}
    WlrLayershell.namespace: "qs-bar"
    readonly property string slimName: slim.targetScreen?.name ?? ""
    readonly property var mainScreen: Services.Monitors.mainScreen(Quickshell.screens)
    readonly property string mainName: slim.mainScreen?.name ?? ""
    readonly property bool mainFullscreen: Services.HyprBridge.isAnyFullscreen(slim.mainName)
    MonitorHeader {
        screenName: slim.slimName
    }
    SystemClock {
        id: slimClock
        precision: SystemClock.Minutes
    }
    Text {
        anchors {
            right: parent.right
            rightMargin: Services.Theme.barMargin
            verticalCenter: parent.verticalCenter
        }
        visible: slim.mainFullscreen
        text: Qt.formatDateTime(slimClock.date, "ddd dd MMM HH:mm")
        color: Services.Theme.fg
        font.family: Services.Theme.font
        font.pixelSize: Services.Theme.px13
    }
}
