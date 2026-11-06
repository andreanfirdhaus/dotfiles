import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import "../components"
import "../services" as Services
Scope {
    id: root
    readonly property string runtimeDir: {
        const r = Quickshell.env("XDG_RUNTIME_DIR") ?? "";
        if (r !== "")
            return r;
        const home = Quickshell.env("HOME") ?? "";
        if (home !== "")
            return home + "/.cache";
        return "/tmp";
    }
    readonly property string shotDir: {
        const home = Quickshell.env("HOME") ?? "";
        if (home === "")
            return "";
        return home + "/Pictures/Screenshots";
    }
    readonly property var targetScreen: {
        const want = Hyprland.focusedMonitor?.name ?? "";
        return Quickshell.screens.find(s => s.name === want) ?? Quickshell.screens[0] ?? null;
    }
    property string pendingMode: ""
    property var snapScreen: null
    property var shotScreen: null
    property bool winResolved: false
    property string tmpFile: ""
    property string shotTmp: ""
    property string saveFile: ""
    property string copySource: ""
    property string copyKind: ""
    property bool saveAlsoCopy: false
    property bool busyAction: false
    property real lastScale: 1
    property bool dirsReady: false
    property int stillAttempts: 0
    property int captureSeq: 0
    readonly property bool pickerActive: picker.visible || chooser.visible
    readonly property bool pickerCovered: (picker.visible && picker.stillReady) || chooser.visible
    function stamp(): string {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss-zzz") + "-" + (root.captureSeq++);
    }
    function removePath(path: string): void {
        if (path !== "")
            Quickshell.execDetached(["rm", "-f", path]);
    }
    function cleanupTmp(): void {
        const f = root.tmpFile;
        root.tmpFile = "";
        root.removePath(f);
    }
    function cleanupShot(): void {
        const f = root.shotTmp;
        root.shotTmp = "";
        root.removePath(f);
    }
    function finishAction(): void {
        root.cleanupShot();
        root.busyAction = false;
    }
    Component.onCompleted: mkdir.running = true
    function capture(mode: string): void {
        if (captureWin.visible || pickerActive || winProbe.running)
            return;
        const m = typeof mode === "string" ? mode : "";
        if (m !== "area" && m !== "window" && m !== "full" && m !== "") {
            console.warn("quickshell: rejecting invalid screenshot mode");
            return;
        }
        if (root.shotDir === "") {
            Services.Notifs.notify({app: "screenshot", summary: "Screenshot folder unavailable", body: "HOME is not set", timeout: 5000});
            return;
        }
        root.pendingMode = m === "" ? "full" : m;
        root.snapScreen = root.targetScreen;
        if (root.dirsReady)
            root.startPending();
        else if (!mkdir.running)
            mkdir.running = true;
    }
    function startPending(): void {
        if (winProbe.running)
            return;
        if (root.pendingMode === "window") {
            root.winResolved = false;
            winProbe.running = true;
            winTimeout.restart();
            return;
        }
        if (root.pendingMode === "full") {
            root.freezeStill();
            return;
        }
        picker.pickMode = "area";
        picker.visible = true;
    }
    function showChooser(file: string): void {
        if (!file || file === "") {
            Services.Notifs.notify({app: "screenshot", summary: "Capture failed", body: "Empty frame", timeout: 5000});
            return;
        }
        if (root.shotTmp !== "" && root.shotTmp !== file)
            root.cleanupShot();
        root.shotTmp = file;
        root.shotScreen = root.snapScreen ?? root.targetScreen;
        root.snapScreen = null;
        root.busyAction = false;
        chooser.visible = true;
    }
    function failCapture(body: string): void {
        captureTimeout.stop();
        Services.Notifs.notify({app: "screenshot", summary: "Capture failed", body: body, timeout: 5000});
        root.pendingMode = "";
        root.snapScreen = null;
        captureView.captureSource = null;
        captureWin.visible = false;
        if (picker.visible)
            picker.close();
        else
            root.cleanupTmp();
    }
    function tryStill(): void {
        if (!captureWin.visible)
            return;
        const src = captureView.sourceSize;
        const w = root.snapScreen?.width ?? root.targetScreen?.width ?? 0;
        if (src.width > 0 && w > 0)
            root.lastScale = src.width / w;
        captureView.grabToImage(result => {
            if (!result) {
                if (root.stillAttempts < 6 && captureWin.visible) {
                    root.stillAttempts += 1;
                    stillRetry.restart();
                    return;
                }
                root.failCapture("Empty frame");
                return;
            }
            captureTimeout.stop();
            if (!result.saveToFile(root.tmpFile)) {
                root.pendingMode = "";
                captureView.captureSource = null;
                captureWin.visible = false;
                if (picker.visible)
                    picker.close();
                else
                    root.cleanupTmp();
                return;
            }
            const mode = root.pendingMode;
            root.pendingMode = "";
            captureView.captureSource = null;
            captureWin.visible = false;
            if (mode === "full") {
                const file = root.tmpFile;
                root.tmpFile = "";
                root.showChooser(file);
                return;
            }
            still.source = "file://" + root.tmpFile;
            picker.stillReady = true;
        });
    }
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.shotDir]
        onExited: exitCode => {
            if (exitCode !== 0) {
                Services.Notifs.notify({app: "screenshot", summary: "Screenshot folder unavailable", body: root.shotDir, timeout: 5000});
                return;
            }
            root.dirsReady = true;
            if (root.pendingMode !== "")
                root.startPending();
        }
    }
    function notifySaved(file: string, copied: bool): void {
        Services.Notifs.notify({
            app: "screenshot",
            summary: copied ? "Screenshot saved and copied" : "Screenshot saved",
            body: file.split("/").pop(),
            icon: file,
            filepath: file,
            timeout: 10000,
            actions: [{identifier: "default", text: "Open"}, {identifier: "path", text: "Copy path"}]
        });
    }
    Process {
        id: saveProc
        onExited: exitCode => {
            if (exitCode !== 0) {
                Services.Notifs.notify({app: "screenshot", summary: "Screenshot save failed", body: root.shotDir, timeout: 5000});
                root.finishAction();
                return;
            }
            if (root.saveAlsoCopy) {
                root.copyKind = "both";
                root.copySource = root.saveFile;
                root.startCopy();
            } else {
                root.notifySaved(root.saveFile, false);
                root.finishAction();
            }
        }
    }
    function startCopy(): void {
        if (root.copySource === "") {
            root.finishAction();
            return;
        }
        copyProc.command = ["sh", "-c", 'wl-copy -t image/png < "$1"', "qs", root.copySource];
        copyProc.running = true;
    }
    Process {
        id: copyProc
        onExited: exitCode => {
            const kind = root.copyKind;
            root.copyKind = "";
            root.copySource = "";
            if (kind === "both") {
                if (exitCode !== 0) {
                    Services.Notifs.notify({app: "screenshot", summary: "Clipboard copy failed", body: "wl-copy failed, file kept", timeout: 5000});
                    root.notifySaved(root.saveFile, false);
                } else {
                    root.notifySaved(root.saveFile, true);
                }
            } else if (exitCode !== 0) {
                Services.Notifs.notify({app: "screenshot", summary: "Clipboard copy failed", body: "wl-copy failed", timeout: 5000});
            } else {
                Services.Notifs.notify({app: "screenshot", summary: "Copied to clipboard", body: "Screenshot", timeout: 2000});
            }
            root.finishAction();
        }
    }
    function freezeStill(): void {
        root.tmpFile = root.runtimeDir + "/qs-screenshot-" + root.stamp() + ".png";
        captureView.captureSource = root.snapScreen ?? root.targetScreen;
        if (!captureView.captureSource) {
            root.cleanupTmp();
            return;
        }
        captureWin.visible = true;
        captureTimeout.start();
    }
    function failWindowProbe(): void {
        winTimeout.stop();
        if (winProbe.running)
            winProbe.running = false;
        root.pendingMode = "";
        root.snapScreen = null;
        Services.Notifs.notify({app: "screenshot", summary: "Window capture failed", body: "Window info unavailable, aborted", timeout: 3000});
    }
    Process {
        id: winProbe
        command: ["sh", "-c", "W=$(hyprctl activewindow -j 2>/dev/null); M=$(hyprctl monitors -j 2>/dev/null); [ -n \"$M\" ] && [ -n \"$W\" ] && printf \"%s\\\\n%s\" \"$M\" \"$W\" | jq -r -s '.[1] as $w | select($w.address != null and $w.address != \"\") | (.[0] | ([.[] | select(.id == ($w.monitor // -1))][0] // ([.[] | select(.focused == true)][0]))) as $m | select($m != null) | \"\\($m.x) \\($m.y) \\($w.at[0]) \\($w.at[1]) \\($w.size[0]) \\($w.size[1])\"' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                winTimeout.stop();
                root.winResolved = true;
                const m = text.trim().match(/(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(\d+)\s+(\d+)/);
                if (!m) {
                    Services.Notifs.notify({app: "screenshot", summary: "Window capture failed", body: "Window info unavailable, aborted", timeout: 3000});
                    root.pendingMode = "";
                    root.snapScreen = null;
                    return;
                }
                const mx = parseInt(m[1]), my = parseInt(m[2]);
                picker.winRect = Qt.rect(parseInt(m[3]) - mx, parseInt(m[4]) - my, parseInt(m[5]), parseInt(m[6]));
                picker.pickMode = "window";
                picker.visible = true;
            }
        }
        onExited: exitCode => {
            winTimeout.stop();
            if (exitCode !== 0 && !root.winResolved)
                root.failWindowProbe();
        }
    }
    Timer {
        id: winTimeout
        interval: 5000
        repeat: false
        onTriggered: {
            if (winProbe.running) {
                winProbe.running = false;
                root.failWindowProbe();
            }
        }
    }
    PanelWindow {
        id: captureWin
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        screen: root.snapScreen ?? root.targetScreen
        exclusiveZone: -1
        visible: false
        color: Services.Theme.transparent
        ScreencopyView {
            id: captureView
            anchors.fill: parent
            live: false
            paintCursor: false
            onHasContentChanged: {
                if (hasContent) {
                    root.stillAttempts = 0;
                    root.tryStill();
                }
            }
        }
        Timer {
            id: stillRetry
            interval: 50
            repeat: false
            onTriggered: root.tryStill()
        }
        Timer {
            id: captureTimeout
            interval: 5000
            repeat: false
            onTriggered: root.failCapture("Timed out")
        }
    }
    PanelWindow {
        id: picker
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        screen: root.snapScreen ?? root.targetScreen
        exclusiveZone: -1
        visible: false
        color: Services.Theme.transparent
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-screenshot-picker"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        property bool stillReady: false
        property bool cropArmed: false
        property string cropFile: ""
        property string pickMode: "area"
        property rect winRect: Qt.rect(0, 0, 0, 0)
        property real startX: 0
        property real startY: 0
        property rect selection: Qt.rect(0, 0, 0, 0)
        property bool selecting: false
        readonly property rect normalized: {
            const s = picker.selection;
            return Qt.rect(Math.min(s.x, s.x + s.width), Math.min(s.y, s.y + s.height), Math.abs(s.width), Math.abs(s.height));
        }
        onStillReadyChanged: {
            if (stillReady && pickMode === "window") {
                picker.selection = Qt.rect(picker.winRect.x, picker.winRect.y, picker.winRect.width, picker.winRect.height);
                picker.acceptSelection();
            }
        }
        onVisibleChanged: {
            if (visible) {
                root.freezeStill();
            } else {
                focusGrab.active = false;
                stillReady = false;
                cropArmed = false;
                cropFile = "";
                selecting = false;
                selection = Qt.rect(0, 0, 0, 0);
                still.source = "";
                root.pendingMode = "";
                root.snapScreen = null;
                root.cleanupTmp();
            }
        }
        HyprlandFocusGrab {
            id: focusGrab
            windows: [picker]
            onCleared: picker.close()
        }
        Timer {
            id: grabTimer
            interval: Services.Theme.grabDelay
            running: picker.visible
            repeat: false
            onTriggered: focusGrab.active = true
        }
        function close(): void {
            picker.visible = false;
        }
        function acceptSelection(): void {
            const n = picker.normalized;
            const x1 = Services.Theme.clamp(n.x, 0, picker.width);
            const y1 = Services.Theme.clamp(n.y, 0, picker.height);
            const x2 = Services.Theme.clamp(n.x + n.width, 0, picker.width);
            const y2 = Services.Theme.clamp(n.y + n.height, 0, picker.height);
            const r = Qt.rect(x1, y1, Math.max(0, x2 - x1), Math.max(0, y2 - y1));
            if (r.width < 4 || r.height < 4) {
                picker.close();
                return;
            }
            picker.cropFile = root.runtimeDir + "/qs-screenshot-crop-" + root.stamp() + ".png";
            cropBox.x = r.x;
            cropBox.y = r.y;
            cropBox.width = r.width;
            cropBox.height = r.height;
            cropBox.visible = true;
            picker.cropArmed = true;
            if (cropImg.status === Image.Ready)
                picker.doCrop();
            else
                cropGrab.restart();
        }
        function doCrop(): void {
            if (!picker.cropArmed)
                return;
            picker.cropArmed = false;
            cropGrab.stop();
            const r = picker.normalized;
            const k = root.lastScale;
            const file = picker.cropFile;
            cropBox.grabToImage(result => {
                cropBox.visible = false;
                picker.cropFile = "";
                if (!result || file === "" || !result.saveToFile(file)) {
                    picker.close();
                    Services.Notifs.notify({app: "screenshot", summary: "Capture failed", body: "Empty frame", timeout: 5000});
                    return;
                }
                root.showChooser(file);
                picker.close();
            }, Qt.size(Math.max(1, Math.round(r.width * k)), Math.max(1, Math.round(r.height * k))));
        }
        Image {
            id: still
            anchors.fill: parent
            fillMode: Image.Stretch
            cache: false
            asynchronous: true
            visible: picker.stillReady
        }
        readonly property real dimOpacity: 0.75
        Rectangle {
            x: 0
            y: 0
            width: picker.width
            height: Math.max(0, picker.normalized.y)
            color: Services.Theme.bg
            opacity: picker.dimOpacity
            visible: picker.stillReady
        }
        Rectangle {
            x: 0
            y: picker.normalized.y + picker.normalized.height
            width: picker.width
            height: Math.max(0, picker.height - (picker.normalized.y + picker.normalized.height))
            color: Services.Theme.bg
            opacity: picker.dimOpacity
            visible: picker.stillReady
        }
        Rectangle {
            x: 0
            y: picker.normalized.y
            width: Math.max(0, picker.normalized.x)
            height: Math.max(0, picker.normalized.height)
            color: Services.Theme.bg
            opacity: picker.dimOpacity
            visible: picker.stillReady
        }
        Rectangle {
            x: picker.normalized.x + picker.normalized.width
            y: picker.normalized.y
            width: Math.max(0, picker.width - (picker.normalized.x + picker.normalized.width))
            height: Math.max(0, picker.normalized.height)
            color: Services.Theme.bg
            opacity: picker.dimOpacity
            visible: picker.stillReady
        }
        MouseArea {
            anchors.fill: parent
            enabled: picker.stillReady && picker.pickMode === "area"
            hoverEnabled: picker.pickMode === "area"
            cursorShape: picker.pickMode === "area" ? Qt.CrossCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton
            onPressed: mouse => {
                picker.startX = mouse.x;
                picker.startY = mouse.y;
                picker.selection = Qt.rect(mouse.x, mouse.y, 0, 0);
                picker.selecting = true;
            }
            onPositionChanged: mouse => {
                if (picker.selecting)
                    picker.selection = Qt.rect(picker.startX, picker.startY, mouse.x - picker.startX, mouse.y - picker.startY);
            }
            onReleased: mouse => {
                if (!picker.selecting)
                    return;
                picker.selecting = false;
                picker.selection = Qt.rect(picker.startX, picker.startY, mouse.x - picker.startX, mouse.y - picker.startY);
                picker.acceptSelection();
            }
        }
        Rectangle {
            x: picker.normalized.x
            y: picker.normalized.y
            width: picker.normalized.width
            height: picker.normalized.height
            visible: picker.selecting || (picker.stillReady && picker.normalized.width > 0)
            color: Services.Theme.transparent
            border.width: 1
            border.color: Services.Theme.accent
        }
        Text {
            x: Math.min(picker.normalized.x, picker.width - 80)
            y: picker.normalized.y > 26 ? picker.normalized.y - 22 : picker.normalized.y + picker.normalized.height + 4
            visible: picker.selecting && picker.normalized.width > 0 && picker.normalized.height > 0
            text: Math.round(picker.normalized.width * root.lastScale) + "x" + Math.round(picker.normalized.height * root.lastScale)
            color: Services.Theme.fg
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px12
        }
        Item {
            id: cropBox
            visible: false
            Image {
                id: cropImg
                x: -cropBox.x
                y: -cropBox.y
                width: picker.width
                height: picker.height
                fillMode: Image.Stretch
                cache: false
                asynchronous: true
                source: picker.stillReady ? "file://" + root.tmpFile : ""
                onStatusChanged: {
                    if (status === Image.Ready && picker.cropArmed)
                        picker.doCrop();
                }
            }
        }
        Timer {
            id: cropGrab
            interval: 250
            repeat: false
            onTriggered: picker.doCrop()
        }
        Text {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 24
            }
            visible: picker.stillReady && !picker.selecting && picker.pickMode === "area"
            text: "drag to select · esc cancels"
            color: Services.Theme.dim
            font.family: Services.Theme.font
            font.pixelSize: Services.Theme.px12
        }
        Shortcut {
            sequence: "Escape"
            enabled: picker.visible
            onActivated: picker.close()
        }
    }
    PanelWindow {
        id: chooser
        screen: root.shotScreen ?? root.targetScreen
        anchors {
            bottom: true
            right: true
        }
        margins.bottom: 20
        margins.right: Services.Theme.popupMargin
        implicitWidth: Services.Theme.toastWidth
        implicitHeight: card.height
        visible: false
        color: Services.Theme.transparent
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-screenshot-chooser"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        property int autoLeft: 10
        onVisibleChanged: {
            if (visible) {
                autoLeft = 10;
            } else {
                chooserGrab.active = false;
                root.shotScreen = null;
                if (!root.busyAction)
                    root.cleanupShot();
            }
        }
        HyprlandFocusGrab {
            id: chooserGrab
            windows: [chooser]
            onCleared: chooser.close()
        }
        Timer {
            id: chooserGrabTimer
            interval: Services.Theme.grabDelay
            running: chooser.visible
            repeat: false
            onTriggered: chooserGrab.active = true
        }
        Timer {
            id: countdown
            interval: 1000
            repeat: true
            running: chooser.visible
            onTriggered: {
                chooser.autoLeft -= 1;
                if (chooser.autoLeft <= 0)
                    chooser.choose("copy");
            }
        }
        function close(): void {
            chooser.visible = false;
        }
        function choose(action: string): void {
            if (!chooser.visible)
                return;
            if (action === "discard") {
                chooser.close();
                return;
            }
            if (action !== "copy" && action !== "save" && action !== "both") {
                chooser.close();
                return;
            }
            if (root.shotTmp === "") {
                chooser.close();
                return;
            }
            root.busyAction = true;
            if (action === "copy") {
                root.copyKind = "only";
                root.copySource = root.shotTmp;
                root.startCopy();
            } else {
                root.saveFile = root.shotDir + "/" + root.stamp() + ".png";
                root.saveAlsoCopy = action === "both";
                saveProc.command = ["cp", "--", root.shotTmp, root.saveFile];
                saveProc.running = true;
            }
            chooser.close();
        }
        Rectangle {
            id: card
            width: chooser.width
            height: content.height + 16
            color: Services.Theme.bg
            border.width: 1
            border.color: Services.Theme.dim
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
                    height: 20
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - kindText.width - parent.spacing
                        text: "Screenshot"
                        color: Services.Theme.fg
                        font.family: Services.Theme.font
                        font.pixelSize: Services.Theme.px12
                        elide: Text.ElideRight
                    }
                    Text {
                        id: kindText
                        anchors.verticalCenter: parent.verticalCenter
                        text: "auto-copy in " + chooser.autoLeft + "s · PNG"
                        color: Services.Theme.dim
                        font.family: Services.Theme.font
                        font.pixelSize: Services.Theme.px10
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 150
                    color: Services.Theme.surface
                    Image {
                        id: preview
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        source: root.shotTmp !== "" ? "file://" + root.shotTmp : ""
                    }
                }
                ActionPills {
                    width: parent.width
                    actions: [
                        {text: "Copy", action: "copy"},
                        {text: "Save", action: "save"},
                        {text: "Save + Copy", action: "both"},
                        {text: "Discard", action: "discard"}
                    ]
                    onPicked: action => chooser.choose(action.action)
                }
                Text {
                    width: parent.width
                    text: "C copy · S save · B save+copy · esc discard"
                    color: Services.Theme.dim
                    font.family: Services.Theme.font
                    font.pixelSize: Services.Theme.px10
                    wrapMode: Text.WordWrap
                }
            }
        }
        Shortcut {
            sequence: "C"
            enabled: chooser.visible
            onActivated: chooser.choose("copy")
        }
        Shortcut {
            sequence: "S"
            enabled: chooser.visible
            onActivated: chooser.choose("save")
        }
        Shortcut {
            sequence: "B"
            enabled: chooser.visible
            onActivated: chooser.choose("both")
        }
        Shortcut {
            sequence: "Return"
            enabled: chooser.visible
            onActivated: chooser.choose("copy")
        }
        Shortcut {
            sequence: "Escape"
            enabled: chooser.visible
            onActivated: chooser.choose("discard")
        }
    }
}
