import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../services" as Services
Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: Services.Theme.tightSpacing
    visible: Services.Theme.trayOnBar && trayRepeater.count > 0
    Repeater {
        id: trayRepeater
        model: SystemTray.items
        delegate: Item {
            id: trayIcon
            required property var modelData
            width: Services.Theme.traySize
            height: Services.Theme.traySize
            Image {
                anchors.fill: parent
                source: modelData?.icon ?? ""
                sourceSize.width: Services.Theme.traySize
                sourceSize.height: Services.Theme.traySize
                fillMode: Image.PreserveAspectFit
                cache: true
                asynchronous: true
                visible: (modelData?.icon ?? "") !== ""
            }
            QsMenuAnchor {
                id: menuAnchor
                menu: trayIcon.modelData?.menu ?? null
                anchor.item: trayIcon
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    const item = trayIcon.modelData;
                    if (!item)
                        return;
                    try {
                        if (mouse.button === Qt.MiddleButton && typeof item.secondaryActivate === "function")
                            item.secondaryActivate();
                        else if (mouse.button === Qt.LeftButton && !item.onlyMenu)
                            item.activate();
                        else if (item.hasMenu)
                            menuAnchor.open();
                        else
                            item.secondaryActivate();
                    } catch (_) {}
                }
            }
        }
    }
}
