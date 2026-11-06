import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../services" as Services
Item {
    id: root
    required property var context
    property var ownScreen: null
    property bool locked: true
    readonly property string ownName: ownScreen && ownScreen.name ? String(ownScreen.name) : ""
    readonly property var mainScreen: Services.Monitors.mainScreen(Quickshell.screens)
    readonly property string mainName: mainScreen && mainScreen.name ? String(mainScreen.name) : ""
    readonly property bool isMain: ownName === "" || mainName === "" || ownName === mainName
    readonly property string focusedName: Hyprland.focusedMonitor?.name ?? ""
    readonly property bool claimsFocus: ownName !== "" && (focusedName === "" ? root.isMain : ownName === focusedName)
    onLockedChanged: root.context.surfaceShown(root.locked)
    Component.onCompleted: {
        if (root.locked)
            root.context.surfaceShown(true);
    }
    Component.onDestruction: {
        if (root.locked)
            root.context.surfaceShown(false);
    }
    onClaimsFocusChanged: {
        if (!root.claimsFocus || !root.locked)
            return;
        if (root.isMain)
            initialFocus.restart();
        else
            secInitial.restart();
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Item {
        id: secRoot
        anchors.fill: parent
        visible: !root.isMain
        Rectangle {
            anchors.fill: parent
            color: "#000000"
        }
        TextInput {
            id: secField
            width: 1
            height: 1
            opacity: 0
            enabled: !root.context.unlockInProgress && !root.context.faillockLocked
            echoMode: TextInput.Password
            onTextChanged: root.context.currentText = text
            onActiveFocusChanged: {
                if (!activeFocus && root.locked && root.claimsFocus && secField.enabled && secRoot.visible)
                    secRefocus.restart();
            }
            Keys.onReturnPressed: root.context.tryUnlock()
            Keys.onEnterPressed: root.context.tryUnlock()
            Keys.onEscapePressed: root.context.currentText = ""
            Component.onCompleted: {
                if (root.claimsFocus && root.locked)
                    secInitial.restart();
            }
            Connections {
                target: root.context
                function onCurrentTextChanged() {
                    if (secField.text !== root.context.currentText)
                        secField.text = root.context.currentText;
                }
            }
        }
        Timer {
            id: secInitial
            interval: 150
            repeat: false
            onTriggered: {
                if (!root.claimsFocus || !secRoot.visible || !secField.enabled)
                    return;
                secField.forceActiveFocus();
            }
        }
        Timer {
            id: secRefocus
            interval: 100
            repeat: false
            onTriggered: {
                if (root.claimsFocus && secRoot.visible && secField.enabled && !secField.activeFocus)
                    secField.forceActiveFocus();
            }
        }
        Timer {
            id: secGuard
            interval: 500
            repeat: true
            running: root.locked && secRoot.visible && secField.enabled
            onTriggered: {
                if (!root.claimsFocus || !secRoot.visible)
                    return;
                if (secField.activeFocus)
                    return;
                secField.forceActiveFocus();
            }
        }
        onVisibleChanged: {
            if (secRoot.visible && root.locked && root.claimsFocus)
                secInitial.restart();
        }
    }
    Item {
        id: mainRoot
        anchors.fill: parent
        visible: root.isMain
        Rectangle {
            anchors.fill: parent
            color: Services.Theme.bg
        }
        Image {
            anchors.fill: parent
            source: root.locked && root.isMain ? Services.Settings.wallpaperSource : ""
            visible: source !== ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            sourceSize.width: root.ownScreen?.width ?? 0
            sourceSize.height: root.ownScreen?.height ?? 0
        }
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.55
        }
        Column {
            id: contentCol
            anchors.centerIn: parent
            width: 360
            spacing: 20
            Column {
                width: parent.width
                spacing: 6
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Services.Theme.white
                    font.family: Services.Theme.font
                    font.pixelSize: 76
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: Services.Theme.fg
                    opacity: 0.85
                    font.family: Services.Theme.font
                    font.pixelSize: Services.Theme.px14
                }
            }
            Rectangle {
                id: card
                width: parent.width
                implicitHeight: cardCol.implicitHeight + 40
                color: Services.Theme.surface
                border.width: 1
                border.color: root.context.showFailure ? Services.Theme.danger : Services.Theme.border
                radius: 0
                transform: Translate {
                    id: shakeT
                    x: 0
                }
                Column {
                    id: cardCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 20
                    }
                    spacing: 12
                    Row {
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            text: "󰌾"
                            color: Services.Theme.accent
                            font.family: Services.Theme.font
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.context.unlockInProgress ? "Unlocking..." : "Enter password to unlock"
                            color: Services.Theme.fg
                            font.family: Services.Theme.font
                            font.pixelSize: Services.Theme.px13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Rectangle {
                        id: passBox
                        width: parent.width
                        height: Services.Theme.rowHeight + 6
                        color: Services.Theme.bg
                        border.width: 1
                        border.color: root.context.showFailure ? Services.Theme.danger : field.activeFocus ? Services.Theme.accent : Services.Theme.border
                        radius: 0
                        TextInput {
                            id: field
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                            }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Services.Theme.fg
                            echoMode: TextInput.Password
                            font.family: Services.Theme.font
                            font.pixelSize: Services.Theme.px13
                            enabled: root.isMain && !root.context.unlockInProgress && !root.context.faillockLocked
                            onTextChanged: root.context.currentText = text
                            onActiveFocusChanged: {
                                if (!activeFocus && root.locked && root.claimsFocus && field.enabled && mainRoot.visible)
                                    refocusDelay.restart();
                            }
                            Keys.onReturnPressed: root.context.tryUnlock()
                            Keys.onEnterPressed: root.context.tryUnlock()
                            Keys.onEscapePressed: root.context.currentText = ""
                            Component.onCompleted: {
                                if (root.claimsFocus && root.locked)
                                    initialFocus.restart();
                            }
                            Connections {
                                target: root.context
                                function onCurrentTextChanged() {
                                    if (field.text !== root.context.currentText)
                                        field.text = root.context.currentText;
                                }
                                function onShowFailureChanged() {
                                    if (root.context.showFailure && root.claimsFocus)
                                        field.forceActiveFocus();
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: Services.Theme.rowHeight
                        radius: 0
                        color: unlockBtn.enabled ? Services.Theme.accent : Services.Theme.hoverBg
                        border.width: 1
                        border.color: Services.Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: root.context.unlockInProgress ? "Unlocking..." : "Unlock"
                            color: unlockBtn.enabled ? Services.Theme.accentFg : Services.Theme.dim
                            font.family: Services.Theme.font
                            font.pixelSize: Services.Theme.px13
                        }
                        MouseArea {
                            id: unlockBtn
                            anchors.fill: parent
                            enabled: root.context.currentText !== "" && !root.context.unlockInProgress && !root.context.faillockLocked
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.context.tryUnlock()
                        }
                    }
                }
            }
        }
        Text {
            anchors {
                top: contentCol.bottom
                topMargin: 10
                horizontalCenter: parent.horizontalCenter
            }
            width: 360
            horizontalAlignment: Text.AlignHCenter
            visible: root.context.statusText !== ""
            text: root.context.statusText
            color: root.context.statusKind === "danger" ? Services.Theme.danger : root.context.statusKind === "warn" ? Services.Theme.warn : Services.Theme.fg
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px12
            wrapMode: Text.WordWrap
        }
        readonly property var lockPlayer: Services.Media.activePlayer
        Text {
            anchors {
                bottom: statusRow.top
                bottomMargin: 12
                horizontalCenter: parent.horizontalCenter
            }
            visible: Services.Notifs.unread > 0
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.RichText
            text: {
                const crit = Services.Notifs.criticalUnread;
                const norm = Services.Notifs.unread - crit;
                const bell = "";
                const gap = "&nbsp;&nbsp;";
                const label = bell + gap + norm + " Notification" + (norm === 1 ? "" : "s");
                const seg = function (color, content) {
                    return '<font color="' + color + '">' + content + "</font>";
                };
                if (norm > 0 && crit > 0)
                    return seg(Services.Theme.fg, label + "&nbsp;&middot;&nbsp;") + seg(Services.Theme.danger, crit + " Critical");
                if (crit > 0)
                    return seg(Services.Theme.danger, bell + gap + crit + " Critical");
                return seg(Services.Theme.fg, label);
            }
            opacity: 0.85
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px12
        }
        Row {
            id: statusRow
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 26
            }
            spacing: 18
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Services.Power.hasBattery
                text: {
                    const p = Services.Power.pct;
                    let icon = "󰂎";
                    if (Services.Power.charging)
                        icon = "󰂄";
                    else if (p >= 90)
                        icon = "󰁹";
                    else if (p >= 70)
                        icon = "󰂂";
                    else if (p >= 50)
                        icon = "󰁾";
                    else if (p >= 30)
                        icon = "󰁼";
                    else if (p >= 10)
                        icon = "󰁺";
                    return icon + "  " + p + "%";
                }
                color: Services.Power.levelColor(Services.Power.pct)
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px12
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (Services.Nmcli.wiredConnected)
                        return "󰈀  " + (Services.Nmcli.wiredDevice?.name ?? "Wired");
                    if (!Services.Nmcli.wifiEnabled)
                        return "󰤭  Wi-Fi off";
                    if (Services.Nmcli.connected == null)
                        return "󰤯  Not connected";
                    const level = Number(Services.Nmcli.connected?.signal ?? 0) || 0;
                    return Services.Nmcli.signalGlyph(level / 100) + "  " + (Services.Nmcli.connected.ssid ?? "Wi-Fi");
                }
                color: (Services.Nmcli.wiredConnected || (Services.Nmcli.wifiEnabled && Services.Nmcli.connected != null)) ? Services.Theme.fg : Services.Theme.dim
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px12
            }
            Text {
                id: mprisText
                anchors.verticalCenter: parent.verticalCenter
                visible: mainRoot.lockPlayer != null
                width: Math.min(implicitWidth, 420)
                elide: Text.ElideRight
                text: {
                    const p = mainRoot.lockPlayer;
                    if (p == null)
                        return "";
                    const glyph = (p.isPlaying ?? false) ? "󰐊" : "󰏤";
                    const title = p.trackTitle || p.identity || "Unknown";
                    const artist = p.trackArtist || "";
                    return glyph + "  " + (artist !== "" ? title + " · " + artist : title);
                }
                color: Services.Theme.fg
                font.family: Services.Theme.font
                font.pixelSize: Services.Theme.px12
            }
        }
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation {
                target: shakeT
                property: "x"
                from: 0
                to: 12
                duration: 55
            }
            NumberAnimation {
                target: shakeT
                property: "x"
                from: 12
                to: -10
                duration: 80
            }
            NumberAnimation {
                target: shakeT
                property: "x"
                from: -10
                to: 6
                duration: 70
            }
            NumberAnimation {
                target: shakeT
                property: "x"
                from: 6
                to: 0
                duration: 60
            }
        }
        Connections {
            target: root.context
            function onShowFailureChanged() {
                if (root.context.showFailure)
                    shakeAnim.restart();
            }
        }
        Timer {
            id: initialFocus
            interval: 150
            repeat: false
            onTriggered: {
                if (!root.claimsFocus || !mainRoot.visible || !field.enabled)
                    return;
                field.forceActiveFocus();
            }
        }
        Timer {
            id: refocusDelay
            interval: 100
            repeat: false
            onTriggered: {
                if (root.claimsFocus && mainRoot.visible && field.enabled && !field.activeFocus)
                    field.forceActiveFocus();
            }
        }
        Timer {
            id: focusGuard
            interval: 500
            repeat: true
            running: root.locked && root.isMain && mainRoot.visible
            onTriggered: {
                if (!root.claimsFocus || !mainRoot.visible)
                    return;
                if (!field.enabled || field.activeFocus)
                    return;
                field.forceActiveFocus();
            }
        }
        onVisibleChanged: {
            if (mainRoot.visible) {
                if (root.locked && root.claimsFocus)
                    initialFocus.restart();
            }
        }
    }
}
