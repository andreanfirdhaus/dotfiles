//@ pragma IconTheme Adwaita
//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "widgets"
import "popups"
import "lock"
import "screenshot"
import "services" as Services

ShellRoot {
    Bar {
        id: bar
        lockContext: lockContext
        sessionLock: sessionLock
        screenshotTool: screenshotTool
    }
    Variants {
        model: {
            const main = Services.Monitors.mainScreen(Quickshell.screens);
            const mainName = main && main.name ? main.name : "";
            return Quickshell.screens.filter(s => s && s.name && s.name !== mainName);
        }
        SlimBar {
            required property var modelData
            targetScreen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        PopupAnchor {
            required property var modelData
            targetScreen: modelData
        }
    }

    IpcHandler {
        target: "bar"
        function closePopups(): void { bar.closePopups(); }
        function toggle(name: string): void {
            if (typeof name !== "string" || name === "" || name.length > 64)
                return;
            if (!/^[A-Za-z0-9_-]+$/.test(name))
                return;
            bar.togglePopup(name);
        }
        function lock(): void { bar.lockScreen(); }
        function powerKey(): void { bar.handlePowerKey(); }
        function screenshot(mode: string): void {
            if (typeof mode !== "string" || mode.length > 16)
                return;
            bar.screenshot(mode);
        }
    }

    Variants {
        model: Quickshell.screens
        WallpaperWindow {}
    }
    LockContext {
        id: lockContext
        onUnlocked: sessionLock.locked = false
        onLockShownChanged: Services.Notifs.setSuppressed(lockContext.lockShown)
    }
    WlSessionLock {
        id: sessionLock
        WlSessionLockSurface {
            id: lockSurf
            LockSurface {
                anchors.fill: parent
                context: lockContext
                ownScreen: lockSurf.screen
                locked: lockSurf.visible || sessionLock.locked
            }
        }
    }
    NotificationStack {
        id: notifStack
        bar: bar
        pickerCovered: screenshotTool.pickerCovered
    }
    Screenshot {
        id: screenshotTool
    }

    component PopupAnchor: PanelWindow {
        id: anchor
        required property var targetScreen
        screen: anchor.targetScreen
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 1
        readonly property string anchorName: anchor.targetScreen?.name ?? ""
        readonly property bool screenFullscreen: Services.HyprBridge.isAnyFullscreen(anchor.anchorName)
        exclusiveZone: anchor.screenFullscreen ? -1 : 0
        color: Services.Theme.transparent
        WlrLayershell.namespace: "qs-popup-anchor"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        Component.onCompleted: Services.HyprBridge.syncAnchor(anchor, anchor.anchorName)
        Component.onDestruction: Services.HyprBridge.unregisterAnchor(anchor)
        onAnchorNameChanged: Services.HyprBridge.syncAnchor(anchor, anchor.anchorName)
    }

    component WallpaperWindow: PanelWindow {
        id: root
        required property var modelData
        screen: modelData
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: -1
        color: Services.Theme.bg
        WlrLayershell.namespace: "wallpaper"
        WlrLayershell.layer: WlrLayer.Background

        property int fadeMs: 350
        property real zoomFrom: 1.04
        property string current: Services.Settings.wallpaperSource

        onCurrentChanged: {
            if (root.current === "")
                return;
            if (bottom.source.toString() === "" && top.source.toString() === "") {
                bottom.source = root.current;
                return;
            }
            if (root.current === bottom.source.toString())
                return;
            crossfade.stop();
            top.opacity = 0;
            top.source = root.current;
        }

        Image {
            id: bottom
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            opacity: 0
            sourceSize.width: root.modelData?.width ?? 0
            sourceSize.height: root.modelData?.height ?? 0
            onStatusChanged: {
                if (status === Image.Ready && opacity === 0 && top.source.toString() === "")
                    startupFade.restart();
            }
        }

        Image {
            id: top
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            opacity: 0
            scale: root.zoomFrom
            transformOrigin: Item.Center
            sourceSize.width: root.modelData?.width ?? 0
            sourceSize.height: root.modelData?.height ?? 0
            onStatusChanged: {
                if (status === Image.Ready && source.toString() !== "" && source.toString() !== bottom.source.toString())
                    crossfade.restart();
            }
        }

        ParallelAnimation {
            id: startupFade
            NumberAnimation {
                target: bottom
                property: "opacity"
                from: 0
                to: 1
                duration: root.fadeMs
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: bottom
                property: "scale"
                from: root.zoomFrom
                to: 1.0
                duration: root.fadeMs
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            id: crossfade
            NumberAnimation {
                target: top
                property: "opacity"
                from: 0
                to: 1
                duration: root.fadeMs
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: top
                property: "scale"
                from: root.zoomFrom
                to: 1.0
                duration: root.fadeMs
                easing.type: Easing.OutCubic
            }
            onFinished: {
                bottom.source = top.source;
                bottom.opacity = 1;
                bottom.scale = 1.0;
                top.opacity = 0;
                top.scale = root.zoomFrom;
                top.source = "";
            }
        }

        Component.onCompleted: {
            if (root.current !== "")
                bottom.source = root.current;
        }
    }
}
