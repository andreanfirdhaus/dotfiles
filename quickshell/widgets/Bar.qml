import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../components"
import "../services" as Services

PanelWindow {
    id: bar

    required property var lockContext
    required property var sessionLock
    required property var screenshotTool

    anchors {
        top: true
        left: true
        right: true
    }

    readonly property string focusedName: Hyprland.focusedMonitor?.name ?? ""
    property var mainScreen: Services.Monitors.mainScreen(Quickshell.screens)
    screen: bar.mainScreen ?? Quickshell.screens[0] ?? null
    readonly property string mainName: bar.mainScreen?.name ?? ""

    function currentPopupAnchor(): var {
        return Services.HyprBridge.anchorForScreen(bar.focusedName) ?? bar;
    }
    function syncPerfSuspend(): void {
        const req = bar.sessionLock ? bar.sessionLock.locked === true : false;
        const shown = bar.lockContext ? bar.lockContext.lockShown === true : false;
        Services.Perf.suspended = req || shown;
    }
    Component.onCompleted: {
        bar.syncPerfSuspend();
    }

    Connections {
        target: bar.sessionLock
        function onLockedChanged(): void {
            bar.syncPerfSuspend();
        }
    }
    Connections {
        target: bar.lockContext
        function onLockShownChanged(): void {
            bar.syncPerfSuspend();
        }
    }

    implicitHeight: Services.Theme.barHeight
    exclusiveZone: implicitHeight
    color: Services.Theme.barBg
    BarDivider {}
    WlrLayershell.namespace: "qs-bar"

    readonly property var bodyPanel: popups.bodyPanel
    readonly property int rightPopupBottom: popups.rightPopupBottom
    readonly property int rightPopupWidth: popups.rightPopupWidth
    function popupByName(name: string): var { return popups.popupByName(name); }
    function closePopups(): void { popups.closePopups(); }
    function togglePopup(name: string): void { popups.togglePopup(name); }
    function openFromPanel(name: string): void { popups.openFromPanel(name); }
    function openExclusive(target, returnTo = null): void { popups.openExclusive(target, returnTo); }
    function revealHistory(i: int): void { popups.revealHistory(i); }
    function followPopupAnchor(): void { popups.followPopupAnchor(bar.currentPopupAnchor()); }

    function lockScreen(): void {
        bar.closePopups();
        if (lockContext && typeof lockContext.reset === "function")
            lockContext.reset();
        if (sessionLock)
            sessionLock.locked = true;
    }
    function handlePowerKey(): void {
        bar.closePopups();
        bar.lockScreen();
        Services.Power.lock();
        if (Services.Power.hasLogind)
            suspendDelay.restart();
    }
    Timer {
        id: suspendDelay
        interval: 600
        repeat: false
        onTriggered: Quickshell.execDetached(["systemctl", "suspend", "-i"])
    }
    function screenshot(mode: string): void {
        const m = typeof mode === "string" ? mode : "";
        if (m !== "area" && m !== "window" && m !== "full" && m !== "") {
            console.warn("quickshell: rejecting invalid screenshot mode: " + m.slice(0, 32));
            return;
        }
        screenshotTool.capture(m === "" ? "full" : m);
    }
    function unlocked(): bool {
        return !(bar.sessionLock && bar.sessionLock.locked === true);
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged(): void { bar.followPopupAnchor(); }
    }
    onFocusedNameChanged: bar.followPopupAnchor()
    onScreenChanged: bar.followPopupAnchor()
    readonly property int screenCount: Quickshell.screens.length
    onScreenCountChanged: {
        bar.followPopupAnchor();
        Services.Monitors.refreshMonitors(true);
    }

    DepCheck {}

    MonitorHeader {
        screenName: bar.mainName
    }
    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }
    Row {
        id: systemStatus
        anchors {
            right: parent.right
            rightMargin: Services.Theme.barMargin
            verticalCenter: parent.verticalCenter
        }
        spacing: Services.Theme.groupSpacing
        SystemGroup {
            bar: bar
        }
        BellIcon {
            bar: bar
        }
        Clock {
            bar: bar
            clockSource: systemClock
        }
    }

    BarPopups {
        id: popups
        bar: bar
        clock: systemClock
    }
    BarShortcuts {
        bar: bar
    }

    component BellIcon: BarIcon {
        id: root
        required property var bar
        anchors.verticalCenter: parent.verticalCenter
        readonly property bool hasUnread: Services.Notifs.unread > 0
        readonly property bool dnd: Services.Modes.dndActive
        glyph: root.dnd ? "" : ""
        glyphColor: root.dnd ? Services.Theme.danger : root.hasUnread ? Services.Theme.accent : Services.Theme.dim
        tipText: root.dnd ? "Do not disturb" : "Notifications"
        tipAnchor: bar
        onClicked: bar.togglePopup("control")
        implicitWidth: Math.max(bellRef.implicitWidth, slashRef.implicitWidth) + root.hPadding * 2
        Text {
            id: bellRef
            visible: false
            text: ""
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px13
        }
        Text {
            id: slashRef
            visible: false
            text: ""
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px13
        }
        Rectangle {
            anchors {
                top: parent.top
                right: parent.right
                topMargin: -1
                rightMargin: -1
            }
            width: 8
            height: 8
            radius: 4
            visible: !root.dnd && root.hasUnread
            color: root.dnd ? Services.Theme.danger : Services.Theme.accent
            border.color: Services.Theme.barBg
            border.width: 1
            z: 1
        }
    }

    component Clock: BarIcon {
        required property var bar
        required property var clockSource
        anchors.verticalCenter: parent.verticalCenter
        glyph: Qt.formatDateTime(clockSource?.date ?? new Date(), "ddd dd MMM HH:mm")
        onClicked: bar.togglePopup("control")
    }

    component DepCheck: Process {
        id: root
        command: ["sh", "-c", "for b in cliphist wl-copy hyprctl jq brightnessctl notify-send systemd-inhibit hypridle upower loginctl systemctl qs btop; do command -v \"$b\" >/dev/null || printf '%s\\n' \"$b\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const missing = text.trim().split("\n").filter(s => s !== "");
                if (missing.length === 0)
                    return;
                console.warn("quickshell: missing helper binaries: " + missing.join(", "));
                if (missing.includes("notify-send"))
                    return;
                Quickshell.execDetached(["notify-send", "-a", "quickshell", "-t", "8000", "-i", "dialog-warning-symbolic", "Missing helper binaries", missing.join(", ")]);
            }
        }
        Component.onCompleted: root.running = true
    }

    component CaffeineIcon: BarIcon {
        required property var bar
        visible: Services.Modes.caffeineActive
        glyph: "󰅶"
        glyphColor: Services.Theme.accent
        tipText: "Caffeine"
        tipAnchor: bar
        onClicked: Services.Modes.toggleCaffeine()
    }

    component MemCpu: Item {
        id: root
        required property var bar
        property int hPadding: Services.Theme.barIconPadding
        property bool tipHover: false
        implicitWidth: row.width + hPadding * 2
        implicitHeight: row.height
        width: implicitWidth
        height: row.height
        function fmtTemp(v: real): string {
            if (!isFinite(v) || v < 0)
                return "--";
            return v.toFixed(1) + "°C";
        }
        function fmtFan(v: int): string {
            if (!isFinite(v) || v < 0)
                return "--";
            return v + " RPM";
        }
        function showTip(): void {
            if (!root.tipHover || !root.bar)
                return;
            const target = root.bar.contentItem;
            if (!target)
                return;
            const pt = root.mapToItem(target, 0, root.height);
            tip.anchor.rect.x = Math.max(Services.Theme.popupMargin, pt.x + root.width / 2 - tip.width / 2);
            tip.anchor.rect.y = pt.y + 4;
            tip.visible = true;
        }
        function hideTip(): void {
            root.tipHover = false;
            tipTimer.stop();
            tip.visible = false;
        }
        function armTip(): void {
            root.tipHover = true;
            tipTimer.restart();
        }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Services.Theme.tightSpacing
            Text {
                text: Services.Perf.memUsed > 0 ? " " + Services.Perf.memUsed.toFixed(1) + "G" : " --G"
                color: Services.Theme.fg
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px13
            }
            Text {
                text: "󰍛 " + Services.Perf.cpuUsage + "%"
                color: Services.Theme.fg
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px13
            }
        }
        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.armTip()
            onExited: root.hideTip()
            onClicked: {
                root.hideTip();
                if (!btop.running) {
                    const term = Quickshell.env("TERMINAL") ?? "foot";
                    btop.command = term === "foot" ? ["foot", "--app-id", "btop", "btop"] : [term, "-e", "btop"];
                    btop.running = true;
                }
            }
        }
        Timer {
            id: tipTimer
            interval: 400
            repeat: false
            onTriggered: root.showTip()
        }
        PopupWindow {
            id: tip
            visible: false
            grabFocus: false
            anchor.window: root.bar
            implicitWidth: tipCol.implicitWidth + 16
            implicitHeight: tipCol.implicitHeight + 12
            Rectangle {
                anchors.fill: parent
                color: Services.Theme.bg
                border.width: 1
                border.color: Services.Theme.border
                Column {
                    id: tipCol
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        text: "CPU  " + Services.Perf.cpuUsage + "% · " + root.fmtTemp(Services.Perf.cpuTemp)
                        color: Services.Theme.fg
                        font.family: Services.Theme.font
                        font.pixelSize: Services.Theme.px11
                    }
                    Text {
                        text: Services.Perf.memTotal > 0 ? "MEM  " + Services.Perf.memUsed.toFixed(1) + " / " + Services.Perf.memTotal.toFixed(1) + "G (" + Services.Perf.memPct + "%)" : "MEM  --"
                        color: Services.Theme.fg
                        font.family: Services.Theme.font
                        font.pixelSize: Services.Theme.px11
                    }
                    Text {
                        text: "GPU  " + root.fmtTemp(Services.Perf.gpuTemp)
                        color: Services.Theme.fg
                        font.family: Services.Theme.font
                        font.pixelSize: Services.Theme.px11
                    }
                    Text {
                        text: "FAN  CPU " + root.fmtFan(Services.Perf.cpuFan) + " · GPU " + root.fmtFan(Services.Perf.gpuFan)
                        color: Services.Theme.fg
                        font.family: Services.Theme.font
                        font.pixelSize: Services.Theme.px11
                    }
                    Text {
                        visible: Services.Power.asusAvailable
                        text: "Profile  " + Services.Power.asusProfileLabel
                        color: Services.Theme.dim
                        font.family: Services.Theme.font
                        font.pixelSize: Services.Theme.px11
                    }
                }
            }
        }
        Process {
            id: btop
            command: ["foot", "--app-id", "btop", "btop"]
            running: false
            onExited: btop.running = false
        }
    }

    component SystemGroup: Item {
        id: root
        required property var bar
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: row.width
        implicitHeight: row.height
        width: row.width
        height: row.height
        Row {
            id: row
            spacing: Services.Theme.groupSpacing
            CaffeineIcon {
                bar: root.bar
            }
            MemCpu {
                bar: root.bar
            }
        }
    }

    component BarShortcuts: Item {
        id: root
        required property var bar

        function unlocked(): bool {
            return root.bar.unlocked();
        }

        QsShortcut {
            appid: "qs-bar"
            name: "control"; description: "Open the control panel"
            onPressed: { if (root.unlocked()) root.bar.togglePopup("control"); }
        }
        QsShortcut {
            appid: "qs-bar"
            name: "power"; description: "Open the power menu"
            onPressed: { if (root.unlocked()) root.bar.togglePopup("power"); }
        }
        QsShortcut {
            appid: "qs-bar"
            name: "settings"; description: "Open settings"
            onPressed: { if (root.unlocked()) root.bar.togglePopup("settings"); }
        }

        QsShortcut {
            name: "launcher"; description: "Open the application launcher"
            onPressed: { if (root.unlocked()) root.bar.togglePopup("launcher"); }
        }
        QsShortcut {
            name: "clipboard"; description: "Open the clipboard history picker"
            onPressed: { if (root.unlocked()) root.bar.togglePopup("clipboard"); }
        }
        QsShortcut {
            name: "emoji"; description: "Open the emoji picker"
            onPressed: { if (root.unlocked()) root.bar.togglePopup("emoji"); }
        }

        QsShortcut {
            name: "lock"; description: "Lock the session"
            onPressed: root.bar.lockScreen()
        }
        QsShortcut {
            name: "powerkey"; description: "Handle the power key per settings"
            onPressed: root.bar.handlePowerKey()
        }
        QsShortcut {
            name: "caffeine"; description: "Toggle caffeine mode (block idle)"
            onPressed: Services.Modes.toggleCaffeine()
        }
        QsShortcut {
            name: "dnd"; description: "Toggle do-not-disturb mode"
            onPressed: Services.Modes.toggleDnd()
        }

        QsShortcut {
            name: "screenshot-area"; description: "Screenshot a selected area"
            onPressed: { if (root.unlocked()) root.bar.screenshot("area"); }
        }
        QsShortcut {
            name: "screenshot-full"; description: "Screenshot the full screen"
            onPressed: { if (root.unlocked()) root.bar.screenshot("full"); }
        }
        QsShortcut {
            name: "screenshot-window"; description: "Screenshot the active window"
            onPressed: { if (root.unlocked()) root.bar.screenshot("window"); }
        }

        QsShortcut {
            name: "volume-up"; description: "Raise the volume"
            onPressed: Services.Media.volumeUp()
        }
        QsShortcut {
            name: "volume-down"; description: "Lower the volume"
            onPressed: Services.Media.volumeDown()
        }
        QsShortcut {
            name: "volume-mute"; description: "Mute the volume"
            onPressed: Services.Media.toggleVolumeMute()
        }
        QsShortcut {
            name: "mic-mute"; description: "Mute the microphone"
            onPressed: Services.Media.toggleMicMute()
        }

        QsShortcut {
            name: "media-toggle"; description: "Play or pause media"
            onPressed: Services.Media.mediaToggle()
        }
        QsShortcut {
            name: "media-next"; description: "Next media track"
            onPressed: Services.Media.mediaNext()
        }
        QsShortcut {
            name: "media-prev"; description: "Previous media track"
            onPressed: Services.Media.mediaPrev()
        }

        QsShortcut {
            name: "brightness-up"; description: "Raise the brightness"
            onPressed: Services.Media.brightnessUp()
        }
        QsShortcut {
            name: "brightness-down"; description: "Lower the brightness"
            onPressed: Services.Media.brightnessDown()
        }
    }
}
