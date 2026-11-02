import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Networking
import "../components"
import "../services" as Services
import "control"
BasePopup {
    id: root
    property var body: null
    extraGrabWindows: root.body != null ? [root.body] : []
    implicitWidth: Services.Theme.popupWidth
    implicitHeight: 2 * Services.Theme.popupPadding + card.contentHeight
    PanelNavKeys {
        host: root
        panel: root
    }
    Shortcut { sequence: "["; enabled: root.visible; onActivated: root.stepSection(-1) }
    Shortcut { sequence: "]"; enabled: root.visible; onActivated: root.stepSection(1) }
    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
            actionIndex = -1;
            mprisCol = 1;
            root.clampSelection();
            trayRow.reset();
        }
        Services.Notifs.setSuppressed(visible);
        Services.Notifs.markRead();
    }
    readonly property var mprisPlayer: Services.Media.activePlayer
    readonly property int playerCount: Services.Media.usableCount
    property int selectedIndex: 0
    property int actionIndex: -1
    property double lastEscapeAt: 0
    property double lastCalendarExitAt: 0
    property int mprisCol: 1
    property var micSource: Services.Media.source
    readonly property var audioSink: Services.Media.sink
    readonly property var sections: {
        const s = [];
        if (Services.Media.brightnessAvailable)
            s.push({ kind: "brightness", count: 1 });
        s.push({ kind: "volume", count: 1 });
        if (root.mprisPlayer !== null)
            s.push({ kind: "mpris", count: 1 });
        s.push({ kind: "tile", count: 9 });
        if (trayRow.visible)
            s.push({ kind: "tray", count: 1 });
        if (Services.Notifs.history.length > 0) {
            s.push({ kind: "clear", count: 1 });
            s.push({ kind: "history", count: Services.Notifs.history.length });
        }
        s.push({ kind: "calendar", count: 1 });
        let start = 0;
        for (const e of s) {
            e.start = start;
            start += e.count;
        }
        return s;
    }
    function sectionStart(kind: string): int {
        const s = root.sections.find(e => e.kind === kind);
        return s ? s.start : -1;
    }
    function volumeIdx(): int {
        return root.sectionStart("volume");
    }
    function mprisIdx(): int {
        return root.sectionStart("mpris");
    }
    function trayIdx(): int {
        return root.sectionStart("tray");
    }
    function mprisMaxCol(): int {
        return root.playerCount > 1 ? 3 : 2;
    }
    function firstTileIdx(): int {
        return root.sectionStart("tile");
    }
    function clearIdx(): int {
        return root.sectionStart("clear");
    }
    function firstHistIdx(): int {
        return root.sectionStart("history");
    }
    function firstCalIdx(): int {
        return root.sectionStart("calendar");
    }
    function calCard(): var {
        return root.body?.calendar ?? null;
    }
    function exitCalendarFocus(): void {
        if (root.selectedKind() !== "calendar")
            return;
        actionIndex = -1;
        root.stepSelection(-1);
    }
    function handleEscape(): void {
        const now = Date.now();
        if (now - root.lastEscapeAt < 200)
            return;
        root.lastEscapeAt = now;
        if (trayRow.visible && trayRow.expanded) {
            trayRow.back();
            return;
        }
        if (root.selectedKind() === "calendar") {
            root.exitCalendarFocus();
            return;
        }
        root.close();
    }
    function cancelOrClose(): void {
        root.handleEscape();
    }
    function quitAction(): void {
        root.handleEscape();
    }
    function escArmed(): bool {
        return true;
    }
    function quitArmed(): bool {
        return true;
    }
    function itemCount(): int {
        const last = root.sections[root.sections.length - 1];
        return last.start + last.count;
    }
    function clampSelection(): void {
        selectedIndex = Services.Theme.clamp(selectedIndex, 0, root.itemCount() - 1);
        root.clampAction();
    }
    function selectedActions(): var {
        if (root.selectedKind() !== "history")
            return [];
        const item = Services.Notifs.history[root.selectedHistItem()] ?? null;
        return Services.Notifs.secondaryActionsOf(item?.live?.actions ?? []);
    }
    function actionCount(): int {
        return root.selectedActions().length;
    }
    function clampAction(): void {
        if (root.selectedKind() !== "history" || root.actionCount() === 0)
            actionIndex = -1;
        else
            actionIndex = Services.Theme.clamp(actionIndex, -1, root.actionCount() - 1);
    }
    function selectIndex(i: int): void {
        if (selectedIndex === i && actionIndex === -1)
            return;
        selectedIndex = i;
        actionIndex = -1;
        root.clampSelection();
        root.revealSelection();
    }
    function selectAction(histItem: int, actIdx: int): void {
        selectedIndex = root.firstHistIdx() + histItem;
        actionIndex = actIdx;
        root.clampSelection();
        root.revealSelection();
    }
    function selectTray(): void {
        if (trayRow.visible)
            root.selectIndex(trayIdx());
    }
    Connections {
        target: Services.Notifs
        function onHistoryChanged() {
            root.clampSelection();
            root.revealSelection();
        }
    }
    onMprisPlayerChanged: {
        if (root.visible)
            root.clampSelection();
    }
    function revealSelection(): void {
        const kind = root.selectedKind();
        if (kind === "calendar")
            return;
        if (kind === "history")
            bar.revealHistory(root.selectedHistItem());
        else if (kind === "clear")
            bar.revealHistory(0);
    }
    function stepSelection(dir: int): void {
        actionIndex = -1;
        if (trayRow.visible && root.selectedKind() === "tray" && trayRow.expanded) {
            trayRow.moveInList(dir);
            return;
        }
        selectedIndex += dir;
        root.clampSelection();
        root.revealSelection();
    }
    function sectionBounds(): var {
        return root.sections.map(s => s.start);
    }
    function stepSection(dir: int): void {
        actionIndex = -1;
        const bounds = root.sectionBounds();
        let target = selectedIndex;
        if (dir > 0) {
            for (const b of bounds) {
                if (b > selectedIndex) {
                    target = b;
                    break;
                }
            }
        } else {
            for (let i = bounds.length - 1; i >= 0; i--) {
                if (bounds[i] < selectedIndex) {
                    target = bounds[i];
                    break;
                }
            }
        }
        selectedIndex = target;
        root.clampSelection();
        root.revealSelection();
    }
    function stepVertical(dir: int): void {
        actionIndex = -1;
        if (root.selectedKind() === "calendar") {
            root.calCard()?.moveSelection(dir * 7);
            return;
        }
        if (root.selectedKind() !== "tile") {
            root.stepSelection(dir);
            return;
        }
        const tileStart = root.firstTileIdx();
        const tileEnd = tileStart + 8;
        const target = selectedIndex + dir * 3;
        const tileSection = root.sections.findIndex(s => s.kind === "tile");
        if (target > tileEnd)
            selectedIndex = root.sections[tileSection + 1] ? root.sections[tileSection + 1].start : tileEnd;
        else if (target < tileStart)
            selectedIndex = tileSection > 0 ? root.sections[tileSection - 1].start : tileStart;
        else
            selectedIndex = target;
        root.clampSelection();
        root.revealSelection();
    }
    function selectedKind(): string {
        for (const s of root.sections) {
            if (selectedIndex >= s.start && selectedIndex < s.start + s.count)
                return s.kind;
        }
        return "tile";
    }
    function selectedTile(): int {
        return selectedIndex - root.firstTileIdx();
    }
    function selectedHistItem(): int {
        return selectedIndex - root.firstHistIdx();
    }
    function adjustVolume(delta: real): void {
        Services.Media.adjustVolume(delta);
    }
    function toggleVolumeMute(): void {
        const audio = root.audioSink?.audio;
        if (audio)
            audio.muted = !audio.muted;
    }
    function toggleMicMute(): void {
        const audio = root.micSource?.audio;
        if (audio)
            audio.muted = !audio.muted;
    }
    function cycleProfileTile(): void {
        if (Services.Asus.available)
            Services.Asus.cycleProfile(1);
        else
            Services.Power.cycleProfile();
    }
    function adjustSelected(dir: int): void {
        const kind = root.selectedKind();
        if (kind === "brightness")
            Services.Media.setBrightness(Services.Media.brightness + dir * Services.Theme.brightnessStep, true);
        else if (kind === "volume")
            root.adjustVolume(dir * Services.Theme.volumeStep);
        else if (kind === "mpris")
            mprisCol = Services.Theme.clamp(mprisCol + dir, 0, root.mprisMaxCol());
        else if (kind === "tray") {
            if (dir > 0)
                trayRow.forward();
            else
                trayRow.back();
        }
        else if (kind === "calendar")
            root.calCard()?.moveSelection(dir);
        else if (kind === "history")
            root.moveAction(dir);
        else
            root.stepSelection(dir);
    }
    function moveAction(dir: int): void {
        const count = root.actionCount();
        if (count === 0) {
            root.stepSelection(dir);
            return;
        }
        if (actionIndex === -1) {
            if (dir > 0)
                actionIndex = 0;
            else
                root.stepSelection(dir);
            return;
        }
        const next = actionIndex + dir;
        if (next < 0)
            actionIndex = -1;
        else if (next >= count)
            actionIndex = count - 1;
        else
            actionIndex = next;
    }
    function focusNext(): void {
        const kind = root.selectedKind();
        if (kind === "history" && root.actionCount() > 0) {
            if (actionIndex === -1) {
                actionIndex = 0;
                return;
            }
            if (actionIndex < root.actionCount() - 1) {
                actionIndex += 1;
                return;
            }
            actionIndex = -1;
        }
        root.stepSelection(1);
    }
    function focusPrev(): void {
        const kind = root.selectedKind();
        if (kind === "history" && actionIndex >= 0) {
            actionIndex -= 1;
            return;
        }
        root.stepSelection(-1);
    }
    function activateMpris(col: int): void {
        const player = root.mprisPlayer;
        if (col === 0)
            Services.Media.mediaPrev(player);
        else if (col === 2)
            Services.Media.mediaNext(player);
        else if (col === 3) {
            Services.Media.cyclePlayer();
            root.mprisCol = Services.Theme.clamp(root.mprisCol, 0, root.mprisMaxCol());
        } else
            Services.Media.mediaToggle(player);
    }
    function activateActionAt(actIdx: int): void {
        const histItem = root.selectedHistItem();
        const item = Services.Notifs.history[histItem] ?? null;
        const live = item?.live ?? null;
        const actions = Services.Notifs.secondaryActionsOf(live?.actions ?? []);
        if (!live || actIdx < 0 || actIdx >= actions.length) {
            actionIndex = -1;
            return;
        }
        try {
            Services.Notifs.activateAction(live, actions[actIdx]);
        } catch (_) {}
        Services.Notifs.dismissHistoryAfterAction(histItem, live);
        actionIndex = -1;
        root.clampSelection();
        bar.closePopups();
    }
    function dismissSelected(): void {
        if (root.selectedKind() !== "history")
            return;
        actionIndex = -1;
        Services.Notifs.dismissHistoryAt(root.selectedHistItem());
        root.clampSelection();
    }
    function activateDefaultAction(): void {
        const histItem = root.selectedHistItem();
        const item = Services.Notifs.history[histItem] ?? null;
        const live = item?.live ?? null;
        if (!live || (live?.actions ?? []).length === 0) {
            if (live && live.resident === true) {
                actionIndex = -1;
                root.clampSelection();
                bar.closePopups();
            } else {
                root.dismissSelected();
            }
            return;
        }
        try {
            Services.Notifs.activateDefault(live);
        } catch (_) {}
        Services.Notifs.dismissHistoryAfterAction(histItem, live);
        actionIndex = -1;
        root.clampSelection();
        bar.closePopups();
    }
    function activateSelected(): void {
        const kind = root.selectedKind();
        if (kind === "volume") {
            root.toggleVolumeMute();
            return;
        }
        if (kind === "brightness")
            return;
        if (kind === "mpris") {
            root.activateMpris(mprisCol);
            return;
        }
        if (kind === "tray") {
            trayRow.activate();
            return;
        }
        if (kind === "clear") {
            actionIndex = -1;
            Services.Notifs.clearHistory();
            root.clampSelection();
            return;
        }
        if (kind === "calendar") {
            root.calCard()?.openSelected();
            return;
        }
        if (kind === "history") {
            if (actionIndex >= 0) {
                root.activateActionAt(actionIndex);
                return;
            }
            root.activateDefaultAction();
            return;
        }
        tileGrid.activateTile(root.selectedTile());
    }
    PwObjectTracker {
        objects: [root.micSource]
    }
    PopupCard {
        id: card
        StatusRow {
            id: statusRow
        }
        BrightnessRow {
            id: brightnessRow
            popup: root
        }
        VolumeRow {
            id: volumeRow
            popup: root
        }
        MprisRow {
            id: mprisRow
            popup: root
        }
        TileGrid {
            id: tileGrid
            popup: root
        }
        TrayRow {
            id: trayRow
            popup: root
        }
    }
}
