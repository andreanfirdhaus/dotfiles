import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../components"
import "../services" as Services
Item {
    id: root
    required property var bar
    property bool pickerCovered: false
    readonly property int shellLayer: root.pickerCovered ? WlrLayer.Top : WlrLayer.Overlay
    readonly property string focusedName: Hyprland.focusedMonitor?.name ?? ""
    readonly property var popupScreen: Services.Monitors.popupScreen(Quickshell.screens, root.focusedName)
    readonly property var osdScreen: Services.Monitors.mainScreen(Quickshell.screens)
    PanelWindow {
        id: toastWin
        screen: root.popupScreen
        anchors {
            top: true
            right: true
        }
        margins.top: (toastWin.screenFullscreen ? 0 : Services.Theme.barHeight) + Services.Theme.popupTopGap
        margins.right: Services.Theme.popupMargin
        readonly property bool screenFullscreen: Services.HyprBridge.isAnyFullscreen(root.popupScreen?.name ?? "")
        exclusiveZone: -1
        readonly property bool parked: root.bar.rightPopupBottom > 0
        readonly property int stackWidth: toastWin.parked ? root.bar.rightPopupWidth : Services.Theme.toastWidth
        readonly property int parkOffset: toastWin.parked ? root.bar.rightPopupBottom + Services.Theme.popupSpacing - Services.Theme.popupTopGap : 0
        implicitWidth: toastWin.stackWidth
        implicitHeight: toastWin.parkOffset + toastList.contentHeight
        mask: Region { item: toastList }
        visible: root.popupScreen !== null
        color: Services.Theme.transparent
        WlrLayershell.namespace: "qs-notifications"
        WlrLayershell.layer: root.shellLayer
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        ListView {
            id: toastList
            anchors {
                left: parent.left
                right: parent.right
            }
            y: toastWin.parkOffset
            width: toastWin.stackWidth
            height: contentHeight
            clip: true
            interactive: false
            spacing: Services.Theme.popupSpacing
            model: Services.Notifs.toasts.filter(t => !Services.Notifs.isOsd(t) && (!toastWin.screenFullscreen || Services.Notifs.showInFullscreen(t)))
            delegate: ToastCard {
                required property var modelData
                notification: modelData
                width: toastWin.stackWidth
            }
        }
    }
    PanelWindow {
        id: osdWin
        screen: root.osdScreen
        anchors {
            bottom: true
        }
        margins.bottom: Services.Theme.osdBottomMargin
        exclusiveZone: 0
        implicitWidth: Services.Theme.osdWidth
        implicitHeight: osdList.contentHeight
        visible: osdList.count > 0 && root.osdScreen !== null
        color: Services.Theme.transparent
        WlrLayershell.namespace: "qs-osd"
        WlrLayershell.layer: root.shellLayer
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        ListView {
            id: osdList
            width: Services.Theme.osdWidth
            height: contentHeight
            clip: true
            interactive: false
            spacing: Services.Theme.popupSpacing
            model: Services.Notifs.toasts.filter(t => Services.Notifs.isOsd(t)).slice(0, 1)
            delegate: OsdCard {
                required property var modelData
                notification: modelData
            }
        }
    }
}
