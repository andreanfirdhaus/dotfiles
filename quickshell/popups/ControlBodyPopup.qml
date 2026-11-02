import QtQuick
import Quickshell
import "../components"
import "../services" as Services
BasePopup {
    id: root
    required property var controlPanel
    useGrab: false
    extraTop: controlPanel.height + Services.Theme.popupSpacing
    implicitWidth: Services.Theme.popupWidth
    readonly property int calendarFixedHeight: calendarCard.fixedHeight
    readonly property int maxStackedHeight: Math.max(0, root.anchorScreenHeight - Services.Theme.popupTopGap - Services.Theme.popupMargin - (root.anchorFullscreen ? 0 : Services.Theme.barHeight))
    readonly property int chromeHeight: controlPanel.height + Services.Theme.popupSpacing + root.calendarFixedHeight + (Services.Notifs.history.length > 0 ? Services.Theme.rowHeight + 2 * Services.Theme.popupSpacing : Services.Theme.popupSpacing)
    readonly property int listCap: Math.max(64, root.maxStackedHeight - root.chromeHeight)
    implicitHeight: (Services.Notifs.history.length > 0 ? Services.Theme.rowHeight + Services.Theme.popupSpacing + Math.min(root.listCap, historyList.contentHeight) : 0) + (Services.Notifs.history.length > 0 ? Services.Theme.popupSpacing : 0) + root.calendarFixedHeight
    visible: controlPanel.visible && !root.hidden
    property int lastPanelHeight: 0
    property bool hidden: false
    property bool reanchoring: false
    readonly property alias calendar: calendarCard
    required property var clock
    function close(): void {
        controlPanel.close();
    }
    function reanchor(window): void {
        const currentHeight = root.controlPanel.height;
        if (root.anchor.window === window && currentHeight === root.lastPanelHeight && root.visible)
            return;

        root.lastPanelHeight = currentHeight;
        root.reanchoring = true;
        root.hidden = true;
        root.anchor.window = window;
        root.hidden = false;
        root.reanchoring = false;
    }
    Connections {
        target: root.controlPanel
        function onHeightChanged(): void {
            if (root.visible)
                reanchorTimer.restart();
        }
    }
    Timer {
        id: reanchorTimer
        interval: 1
        repeat: false
        onTriggered: {
            if (!root.visible)
                return;
            root.reanchor(root.anchor.window);
            root.controlPanel.forceGrab();
        }
    }
    function cancelOrClose(): void {
        root.controlPanel.handleEscape();
    }
    function quitAction(): void {
        root.controlPanel.handleEscape();
    }
    function revealAt(i: int): void {
        historyList.positionViewAtIndex(i, ListView.Contain);
    }
    onVisibleChanged: {
        if (root.reanchoring)
            return;
        Services.Notifs.historyVisible = visible;
        if (visible) {
            Services.Notifs.markRead();
            calendarCard.resetToToday();
            polishTimer.restart();
        }
    }
    PanelNavKeys {
        host: root
        panel: root.controlPanel
    }
    Shortcut { sequence: "["; enabled: root.visible; onActivated: root.controlPanel.stepSection(-1) }
    Shortcut { sequence: "]"; enabled: root.visible; onActivated: root.controlPanel.stepSection(1) }
    Shortcut { sequence: "t"; enabled: root.visible && root.controlPanel.selectedKind() === "calendar"; onActivated: calendarCard.resetToToday() }
    Shortcut { sequence: "Shift+H"; enabled: root.visible && root.controlPanel.selectedKind() === "calendar"; onActivated: calendarCard.stepMonth(-1) }
    Shortcut { sequence: "Shift+L"; enabled: root.visible && root.controlPanel.selectedKind() === "calendar"; onActivated: calendarCard.stepMonth(1) }
    Shortcut { sequence: "Shift+K"; enabled: root.visible && root.controlPanel.selectedKind() === "calendar"; onActivated: calendarCard.stepMonth(-12) }
    Shortcut { sequence: "Shift+J"; enabled: root.visible && root.controlPanel.selectedKind() === "calendar"; onActivated: calendarCard.stepMonth(12) }
    Shortcut { sequence: "Shift+Left"; enabled: root.visible && root.controlPanel.selectedKind() === "calendar"; onActivated: calendarCard.stepMonth(-1) }
    Shortcut { sequence: "Shift+Right"; enabled: root.visible && root.controlPanel.selectedKind() === "calendar"; onActivated: calendarCard.stepMonth(1) }
    Shortcut { sequence: "Shift+Up"; enabled: root.visible && root.controlPanel.selectedKind() === "calendar"; onActivated: calendarCard.stepMonth(-12) }
    Shortcut { sequence: "Shift+Down"; enabled: root.visible && root.controlPanel.selectedKind() === "calendar"; onActivated: calendarCard.stepMonth(12) }
    Timer {
        id: polishTimer
        interval: Services.Theme.focusDelay
        repeat: false
        onTriggered: {
            if (root.visible)
                historyList.positionViewAtIndex(0, ListView.Beginning);
        }
    }
    Column {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: Services.Theme.popupSpacing
        Rectangle {
            width: parent.width
            height: Services.Theme.rowHeight
            visible: Services.Notifs.history.length > 0
            color: Services.Theme.bg
            Row {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 60
                    text: "Notifications (" + Services.Notifs.history.length + ")"
                    color: Services.Theme.dim
                    font.family: Services.Theme.font
                    font.pixelSize: Services.Theme.px12
                    elide: Text.ElideRight
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    horizontalAlignment: Text.AlignRight
                    text: "Clear"
                    readonly property bool selected: root.controlPanel.selectedKind() === "clear"
                    color: selected ? Services.Theme.accent : clearArea.containsMouse ? Services.Theme.fg : Services.Theme.dim
                    font.family: Services.Theme.font
                    font.pixelSize: Services.Theme.px12
                    font.underline: selected
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.controlPanel.actionIndex = -1;
                            Services.Notifs.clearHistory();
                            root.controlPanel.clampSelection();
                        }
                    }
                }
            }
        }
        Item {
            width: parent.width
            height: Services.Notifs.history.length > 0 ? Math.min(root.listCap, historyList.contentHeight) : 0
            visible: Services.Notifs.history.length > 0
            ListView {
                id: historyList
                anchors.fill: parent
                clip: true
                cacheBuffer: 400
                model: Services.Notifs.history
                spacing: Services.Theme.popupSpacing
                delegate: Rectangle {
                    id: historyCard
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.controlPanel.selectedIndex === root.controlPanel.firstHistIdx() + index
                    readonly property string rawIcon: modelData.icon ?? ""
                    readonly property bool isHovered: cardArea.containsMouse
                    width: historyList.width
                    height: content.height + 16
                    color: selected ? Services.Theme.activeBg : historyCard.isHovered ? Services.Theme.hoverBg : Services.Theme.bg
                    border.width: selected ? 1 : 0
                    border.color: historyCard.isHovered ? Services.Theme.fg : Services.Theme.accent
                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: 1
                        visible: modelData.critical
                        color: Services.Theme.danger
                    }
                    MouseArea {
                        id: cardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            mouse.accepted = true;
                            const idx = historyCard.index;
                            const live = historyCard.modelData.live;
                            if (live == null) {
                                root.controlPanel.actionIndex = -1;
                                Services.Notifs.dismissHistoryAt(idx);
                                root.controlPanel.clampSelection();
                                return;
                            }
                            try {
                                Services.Notifs.activateDefault(live);
                            } catch (_) {}
                            root.controlPanel.actionIndex = -1;
                            Services.Notifs.dismissHistoryAfterAction(idx, live);
                            root.controlPanel.clampSelection();
                            bar.closePopups();
                        }
                    }
                    Column {
                        id: content
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 8
                        }
                        spacing: 6
                        Row {
                            width: parent.width
                            spacing: 8
                            NotificationIcon {
                                id: historyIcon
                                rawIcon: historyCard.rawIcon
                                tint: historyCard.modelData.critical ? Services.Theme.danger : "transparent"
                            }
                            Column {
                                width: parent.width - (historyIcon.showIcon ? historyIcon.width + 8 : 0)
                                spacing: 2
                                Row {
                                    width: parent.width
                                    spacing: 8
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 52
                                        text: modelData.summary || modelData.app || ""
                                        color: Services.Theme.fg
                                        font.family: Services.Theme.font
                                        font.pixelSize: Services.Theme.px12
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 44
                                        horizontalAlignment: Text.AlignRight
                                        text: {
                                            Services.Notifs.timeTick;
                                            return Services.Notifs.timeAgo(modelData.time);
                                        }
                                        color: Services.Theme.dim
                                        font.family: Services.Theme.font
                                        font.pixelSize: Services.Theme.px10
                                    }
                                }
                                Text {
                                    width: parent.width
                                    visible: (modelData.body ?? "") !== ""
                                    text: Services.Notifs.richBody(modelData.body)
                                    color: Services.Theme.dim
                                    font.family: Services.Theme.font
                                    font.pixelSize: Services.Theme.px12
                                    textFormat: Text.StyledText
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: Services.Theme.historyBodyMaxLines
                                    elide: Text.ElideRight
                                }
                                ActionPills {
                                    width: parent.width
                                    actions: Services.Notifs.secondaryActionsOf(modelData.live?.actions ?? [])
                                    focusedIndex: historyCard.selected ? root.controlPanel.actionIndex : -1
                                    onPicked: action => {
                                        const idx = historyCard.index;
                                        try {
                                            Services.Notifs.activateAction(modelData.live, action);
                                        } catch (_) {}
                                        root.controlPanel.actionIndex = -1;
                                        Services.Notifs.dismissHistoryAfterAction(idx, modelData.live);
                                        root.controlPanel.clampSelection();
                                        bar.closePopups();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        CalendarCard {
            id: calendarCard
            clock: root.clock
            popup: root.controlPanel
            focused: root.controlPanel.selectedKind() === "calendar"
        }
    }
}
