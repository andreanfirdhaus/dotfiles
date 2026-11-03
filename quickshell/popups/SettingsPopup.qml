import QtQuick
import "../components"
import "../services" as Services
import "../services/SettingsUtil.js" as SettingsUtil
import "settings"
BasePopup {
    id: root
    implicitWidth: Services.Theme.settingsWidth
    implicitHeight: Math.min(16 + tabRow.height + Services.Theme.popupSpacing + root.contentHeight(), (Screen.height ?? 800) - 60)
    property int tab: 0
    function cancelOrClose(): void {
        if (root.wallFocus) {
            root.cancelWallFocus();
            return;
        }
        if (root.previewGrab) {
            root.cancelPreviewGrab(true);
            return;
        }
        if (root.openMenu !== null)
            root.closeDrop();
        else
            root.close();
    }
    Shortcut { sequence: "1"; enabled: root.visible; onActivated: root.tab = 0 }
    Shortcut { sequence: "2"; enabled: root.visible; onActivated: root.tab = 1 }
    Shortcut { sequence: "3"; enabled: root.visible; onActivated: root.tab = 2 }
    Shortcut { sequence: "j"; enabled: root.visible; onActivated: root.stepSelection(1) }
    Shortcut { sequence: "k"; enabled: root.visible; onActivated: root.stepSelection(-1) }
    Shortcut { sequence: "h"; enabled: root.visible; onActivated: root.adjustSelected(-1) }
    Shortcut { sequence: "l"; enabled: root.visible; onActivated: root.adjustSelected(1) }
    Shortcut { sequence: "Up"; enabled: root.visible; onActivated: root.stepSelection(-1) }
    Shortcut { sequence: "Down"; enabled: root.visible; onActivated: root.stepSelection(1) }
    Shortcut { sequence: "Left"; enabled: root.visible; onActivated: root.adjustSelected(-1) }
    Shortcut { sequence: "Right"; enabled: root.visible; onActivated: root.adjustSelected(1) }
    Shortcut { sequence: "Tab"; enabled: root.visible; onActivated: root.tabStep(1) }
    Shortcut { sequence: "Shift+Tab"; enabled: root.visible; onActivated: root.tabStep(-1) }
    Shortcut { sequence: "["; enabled: root.visible; onActivated: root.stepSection(-1) }
    Shortcut { sequence: "]"; enabled: root.visible; onActivated: root.stepSection(1) }
    Shortcut { sequence: "Space"; enabled: root.visible; onActivated: root.activateSelected() }
    Shortcut { sequence: "Return"; enabled: root.visible; onActivated: root.activateSelected() }
    Shortcut { sequence: "Enter"; enabled: root.visible; onActivated: root.activateSelected() }

    Connections {
        target: Services.Monitors
        function onLastApplyMsgChanged(): void {
            if (!root.preventClose)
                return;
            root.kickBusy();
        }
    }
    Connections {
        target: Services.Asus
        function onAvailableChanged(): void {
            root.keepSysRow();
            root.clampSelection();
        }
    }

    property int selectedIndex: 0
    property var openMenu: null
    readonly property int openDropdown: root.openMenu && root.openMenu.kind === "sys" ? root.openMenu.index : -1
    readonly property string openMonRes: root.openMenu && root.openMenu.kind === "res" ? root.openMenu.name : ""
    readonly property bool openMainDrop: root.openMenu !== null && root.openMenu.kind === "main"
    readonly property bool paletteDropOpen: root.openMenu !== null && root.openMenu.kind === "palette"
    property int dropCursor: 0
    property bool previewGrab: false
    property string previewGrabName: ""
    property var previewBaseOrder: []
    property string previewBaseAxis: "row"
    property bool wallFocus: false
    property int wallCursor: 0
    function ensureWallCursor(): void {
        if (root.wpCount <= 0) {
            root.wallCursor = 0;
            return;
        }
        if (root.wallCursor >= 0 && root.wallCursor < root.wpCount)
            return;
        const cur = Services.Settings.wallpaperOverride ?? "";
        const at = Services.Settings.wallpapers.indexOf(cur);
        root.wallCursor = at >= 0 ? at : 0;
    }
    function cancelWallFocus(): bool {
        if (!root.wallFocus)
            return false;
        root.wallFocus = false;
        return true;
    }
    function cancelPreviewGrab(revert: bool): bool {
        if (!root.previewGrab)
            return false;
        let kicked = false;
        if (revert) {
            const cur = displaysTab.previewOrder.slice();
            const base = (root.previewBaseOrder ?? []).filter(n => cur.includes(n));
            for (const n of cur) {
                if (!base.includes(n))
                    base.push(n);
            }
            const axis = root.previewBaseAxis || "row";
            if (JSON.stringify(base) !== JSON.stringify(cur) || axis !== displaysTab.previewAxis) {
                root.beginMonitorChange();
                displaysTab.applyOrder(base, axis);
                kicked = true;
            }
        }
        root.previewGrab = false;
        root.previewGrabName = "";
        root.previewBaseOrder = [];
        root.previewBaseAxis = "row";
        return kicked;
    }
    onTabChanged: {
        root.selectedIndex = 0;
        root.closeDrop();
        root.cancelWallFocus();
        root.cancelPreviewGrab(false);
        root.syncWallCursor();
        root.syncLastAsusRows();
        if (root.visible && root.tab === 2)
            Services.Monitors.refreshMonitors(false);
        if (root.visible && root.tab === 1)
            Services.Asus.refresh();
    }
    onWpCountChanged: {
        if (root.wpCount === 0)
            root.cancelWallFocus();
        root.syncWallCursor();
    }
    onMonCountChanged: {
        if (root.openMonRes !== "" && Services.Monitors.monitorLive(root.openMonRes) === null)
            root.closeDrop();
        root.clampSelection();
    }
    onEnabledCountChanged: {
        if (root.enabledCount < 2 && root.openMainDrop)
            root.closeDrop();
        root.clampSelection();
    }

    onVisibleChanged: {
        if (visible) {
            root.selectedIndex = 0;
            root.closeDrop();
            root.cancelWallFocus();
            root.syncWallCursor();
            root.syncLastAsusRows();
            displaysTab.syncPreviewOrder();
            Services.Settings.refreshWallpapers(false);
            if (root.tab === 2)
                Services.Monitors.refreshMonitors(false);
            if (root.tab === 1)
                Services.Asus.refresh();
        } else {
            root.calmBusy();
            root.cancelWallFocus();
            root.cancelPreviewGrab(false);
            root.closeDrop();
        }
    }

    function beginMonitorChange(): void {
        root.kickBusy();
    }
    function toggleMonitorEnabled(name: string): void {
        if (name === "")
            return;
        if (Services.Monitors.monitorEnabled(name) && !Services.Monitors.canDisableMonitor(name)) {
            Services.Monitors.setMonitorEnabled(name, false);
            return;
        }
        root.beginMonitorChange();
        Services.Monitors.setMonitorEnabled(name, !Services.Monitors.monitorEnabled(name));
    }
    function itemCount(): int {
        if (root.tab === 0)
            return root.inputBase + root.inputRows;
        if (root.tab === 1)
            return 9 + root.asusRows;
        return root.monFirst + root.monCount * root.monRows + 1;
    }
    function monLastIndex(): int {
        return root.monFirst + root.monCount * root.monRows;
    }
    function anyDropOpen(): bool {
        return root.openMenu !== null;
    }
    function clampSelection(): void {
        selectedIndex = Services.Theme.clamp(selectedIndex, 0, Math.max(0, root.itemCount() - 1));
    }
    property int lastAsusRows: 0
    function keepSysRow(): void {
        const delta = root.asusRows - root.lastAsusRows;
        root.lastAsusRows = root.asusRows;
        if (delta === 0 || root.tab !== 1)
            return;
        root.closeDrop();
        if (root.selectedIndex >= 4)
            root.selectedIndex = Math.max(4, root.selectedIndex + delta);
    }
    function syncLastAsusRows(): void {
        root.lastAsusRows = root.asusRows;
    }
    function syncWallCursor(): void {
        root.ensureWallCursor();
        root.clampSelection();
        if (root.tab === 0 && root.wpCount > 0 && selectedIndex === 0) {
            generalTab.wallList.currentIndex = root.wallCursor;
            generalTab.wallList.positionViewAtIndex(root.wallCursor, GridView.Contain);
        } else {
            generalTab.wallList.currentIndex = -1;
        }
    }
    function stepSelection(dir: int): void {
        if (root.tab === 2 && root.previewGrab) {
            if (displaysTab.shiftGrabbed(dir, "column"))
                root.beginMonitorChange();
            return;
        }
        if (root.tab === 1 && root.openDropdown >= 0) {
            root.moveCursor(root.dropdownOptions(root.openDropdown), dir);
            return;
        }
        if (root.tab === 0 && root.paletteDropOpen) {
            root.moveCursor(root.paletteOptions(), dir);
            return;
        }
        if (root.tab === 2 && root.openMainDrop) {
            root.moveCursor(root.mainOptions(), dir);
            return;
        }
        if (root.tab === 2 && root.openMonRes !== "") {
            root.moveCursor(Services.Monitors.monitorModes(root.openMonRes), dir);
            return;
        }
        if (root.tab === 0 && root.wpCount > 0) {
            if (root.wallFocus && selectedIndex === 0) {
                let nxt = root.wallCursor + dir * root.wpCols;
                if (nxt < 0)
                    nxt = 0;
                else if (nxt >= root.wpCount)
                    nxt = root.wpCount - 1;
                root.wallCursor = nxt;
                root.syncWallCursor();
                return;
            }
            selectedIndex += dir;
            root.clampSelection();
            root.syncWallCursor();
            return;
        }
        selectedIndex += dir;
        root.clampSelection();
        root.syncWallCursor();
    }
    function sectionBounds(): var {
        if (root.tab === 0) {
            const bounds = [];
            if (root.wpCount > 0)
                bounds.push(0);
            bounds.push(root.themeBase, root.inputBase);
            return bounds;
        }
        if (root.tab === 1)
            return [0, 4, root.sysIdx(7)];
        const bounds = [0, 1];
        for (let i = 0; i < root.monCount; i++)
            bounds.push(root.monFirst + i * root.monRows);
        bounds.push(root.monLastIndex());
        return bounds;
    }
    function stepSection(dir: int): void {
        if (root.wallFocus)
            return;
        if (root.tab === 2 && root.previewGrab)
            return;
        if (root.anyDropOpen()) {
            root.closeDrop();
            return;
        }
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
        root.syncWallCursor();
    }
    function tabStep(dir: int): void {
        root.cancelWallFocus();
        root.cancelPreviewGrab(false);
        root.closeDrop();
        const n = 3;
        root.tab = (root.tab + dir + n) % n;
    }
    function monitorNameAt(i: int): string {
        if (i < root.monFirst || i >= root.monFirst + root.monCount * root.monRows)
            return "";
        const m = Services.Monitors.monitors[Math.floor((i - root.monFirst) / root.monRows)] ?? null;
        return m && typeof m.name === "string" ? m.name : "";
    }
    function adjustSelected(dir: int): void {
        if (root.tab === 0) {
            if (root.wpCount > 0 && selectedIndex === 0) {
                if (root.wallFocus) {
                    root.wallCursor = Services.Theme.clamp(root.wallCursor + dir, 0, root.wpCount - 1);
                    root.syncWallCursor();
                }
                return;
            }
            if (selectedIndex === root.themeBase) {
                if (root.paletteDropOpen) {
                    if (dir < 0)
                        root.closeDrop();
                    else
                        root.commitPaletteCursor();
                    return;
                }
                root.cyclePalette(dir);
                return;
            }
            switch (selectedIndex - root.inputBase) {
            case 0: Services.Settings.setSensitivity(Services.Settings.sensitivity + dir * 0.1); break;
            case 1: Services.Settings.setTouchScroll(Services.Settings.touchScroll + dir * 0.1); break;
            case 2: Services.Settings.setNaturalScroll(!Services.Settings.naturalScroll); break;
            }
            return;
        }
        if (root.tab === 1) {
            if (root.openDropdown === selectedIndex && root.openDropdown >= 0) {
                if (dir < 0)
                    root.closeDrop();
                else
                    root.commitDropCursor();
                return;
            }
            if (root.asusRows === 1 && selectedIndex === 4) {
                Services.Asus.setChargeLimit(Services.Asus.chargeLimit + dir * 5);
                return;
            }
            const rel = selectedIndex >= 4 + root.asusRows ? selectedIndex - root.asusRows : selectedIndex;
            switch (rel) {
            case 0: Services.Settings.setDimTimeout(Services.Settings.dimTimeout + dir * 30); break;
            case 1: Services.Settings.setLockTimeout(Services.Settings.lockTimeout + dir * 60); break;
            case 2: Services.Settings.setScreenOffTimeout(Services.Settings.screenOffTimeout + dir * 60); break;
            case 3: Services.Settings.setSuspendTimeout(Services.Settings.suspendTimeout + dir * 300); break;
            case 4: Services.Settings.setLowBatteryPct(Services.Settings.lowBatteryPct + dir * 5); break;
            case 5: Services.Settings.setCriticalBatteryPct(Services.Settings.criticalBatteryPct + dir * 2); break;
            case 6: Services.Settings.setLidCloseAction(SettingsUtil.cycleOpt(Services.Power.lidOptions, Services.Settings.lidCloseAction, dir)); break;
            case 7: root.cycleActiveProfile(dir); break;
            case 8: Services.Settings.setPowerProfileOnBattery(SettingsUtil.cycleOpt(Services.Power.profileOptions, Services.Settings.powerProfileOnBattery, dir)); break;
            }
            return;
        }
        if (root.tab === 2 && root.selectedIndex === 0) {
            if (root.openMainDrop) {
                if (dir < 0)
                    root.closeDrop();
                else
                    root.commitMainCursor();
                return;
            }
            root.cycleMainMonitor(dir);
            return;
        }
        if (root.tab === 2 && root.selectedIndex === 1) {
            if (root.previewGrab) {
                if (displaysTab.shiftGrabbed(dir, "row"))
                    root.beginMonitorChange();
            }
            return;
        }
        if (root.tab === 2 && root.selectedIndex === root.monLastIndex())
            return;
        const name = root.monitorNameAt(selectedIndex);
        if (name === "")
            return;
        const kind = (selectedIndex - root.monFirst) % root.monRows;
        if (kind === 0) {
            root.toggleMonitorEnabled(name);
        } else if (kind === 1) {
            root.beginMonitorChange();
            Services.Monitors.cycleValidScale(name, dir);
        } else if (kind === 2) {
            if (root.openMonRes === name) {
                if (dir < 0)
                    root.closeDrop();
                else
                    root.commitMonModeCursor();
            } else {
                root.beginMonitorChange();
                Services.Monitors.cycleMonitorResolution(name, dir);
            }
        }
        return;
    }
    function activateSelected(): void {
        if (root.tab === 0) {
            if (root.wpCount > 0 && selectedIndex === 0) {
                if (!root.wallFocus) {
                    root.ensureWallCursor();
                    root.wallFocus = true;
                    root.syncWallCursor();
                } else {
                    const p = Services.Settings.wallpapers[root.wallCursor] ?? "";
                    if (p !== "")
                        Services.Settings.setWallpaper(p);
                    root.syncWallCursor();
                }
                return;
            } else if (selectedIndex === root.themeBase) {
                if (root.paletteDropOpen)
                    root.commitPaletteCursor();
                else
                    root.togglePaletteDrop();
                return;
            } else if (selectedIndex === root.inputBase + 2)
                Services.Settings.setNaturalScroll(!Services.Settings.naturalScroll);
            return;
        }
        if (root.tab === 1) {
            if (root.openDropdown === selectedIndex && root.openDropdown >= 0) {
                root.commitDropCursor();
                return;
            }
            if (root.isDropdownIndex(selectedIndex)) {
                if (root.dropEnabled(selectedIndex))
                    root.openDrop(selectedIndex);
                return;
            }
            return;
        }
        if (root.tab === 2 && root.selectedIndex === 0) {
            if (root.openMainDrop)
                root.commitMainCursor();
            else
                root.toggleMainDrop();
            return;
        }
        if (root.tab === 2 && root.selectedIndex === 1) {
            if (root.previewGrab)
                root.cancelPreviewGrab(false);
            else
                displaysTab.startGrab();
            return;
        }
        if (root.tab === 2 && root.selectedIndex === root.monLastIndex()) {
            Services.Monitors.refreshMonitors(true);
            return;
        }
        const name = root.monitorNameAt(selectedIndex);
        if (name === "")
            return;
        const rowKind = (selectedIndex - root.monFirst) % root.monRows;
        if (rowKind === 0)
            root.toggleMonitorEnabled(name);
        else if (rowKind === 2) {
            if (root.openMonRes === name)
                root.commitMonModeCursor();
            else
                root.toggleMonModeDrop(name);
        }
    }

    function cycleActiveProfile(dir: int): void {
        if (Services.Asus.available) {
            Services.Asus.cycleProfile(dir);
            return;
        }
        if (!Services.Power.profilesAvailable)
            return;
        const order = Services.Power.hasPerformanceProfile ? ["balanced", "powersaver", "performance"] : ["balanced", "powersaver"];
        Services.Power.setProfileByName(SettingsUtil.cycleOpt(order, Services.Power.profileName, dir), false);
    }

    function activeProfileOptions(): var {
        if (Services.Asus.available)
            return Services.Asus.profileOptions;
        return Services.Power.hasPerformanceProfile ? ["balanced", "powersaver", "performance"] : ["balanced", "powersaver"];
    }
    function isDropdownIndex(i: int): bool {
        return root.tab === 1 && i >= root.sysIdx(6) && i <= root.sysIdx(8);
    }
    function dropEnabled(i: int): bool {
        if (i === root.sysIdx(7))
            return Services.Asus.available || Services.Power.profilesAvailable;
        return true;
    }
    function dropdownOptions(i: int): var {
        if (i === root.sysIdx(6))
            return Services.Power.lidOptions;
        if (i === root.sysIdx(7))
            return root.activeProfileOptions();
        if (i === root.sysIdx(8))
            return Services.Power.profileOptions;
        return [];
    }
    function dropdownCurrent(i: int): string {
        if (i === root.sysIdx(6))
            return Services.Settings.lidCloseAction;
        if (i === root.sysIdx(7)) {
            if (Services.Asus.available)
                return Services.Asus.profile !== "" ? Services.Asus.profile : "…";
            return Services.Power.profilesAvailable ? Services.Power.profileName : "no ppd";
        }
        if (i === root.sysIdx(8))
            return Services.Power.profilesAvailable ? Services.Settings.powerProfileOnBattery : "no ppd";
        return "";
    }
    function applyDropValue(i: int, value: string): void {
        if (i === root.sysIdx(6))
            Services.Settings.setLidCloseAction(value);
        else if (i === root.sysIdx(7)) {
            if (Services.Asus.available)
                Services.Asus.setProfile(value, false);
            else if (Services.Power.profilesAvailable)
                Services.Power.setProfileByName(value, false);
        } else if (i === root.sysIdx(8))
            Services.Settings.setPowerProfileOnBattery(value);
    }
    function openDrop(i: int): void {
        if (!root.dropEnabled(i))
            return;
        const opts = root.dropdownOptions(i);
        let at = opts.indexOf(root.dropdownCurrent(i));
        if (at < 0)
            at = 0;
        root.dropCursor = at;
        root.openMenu = {kind: "sys", index: i};
    }
    function closeDrop(): void {
        root.openMenu = null;
    }
    function toggleDrop(i: int): void {
        if (root.openDropdown === i)
            root.closeDrop();
        else
            root.openDrop(i);
    }
    function moveCursor(opts: var, dir: int): void {
        if (!opts || opts.length === 0)
            return;
        root.dropCursor = (root.dropCursor + dir + opts.length) % opts.length;
    }
    function commitDropCursor(): void {
        const i = root.openDropdown;
        const opts = root.dropdownOptions(i);
        if (i < 0 || opts.length === 0) {
            root.closeDrop();
            return;
        }
        root.applyDropValue(i, opts[Services.Theme.clamp(root.dropCursor, 0, opts.length - 1)]);
        root.closeDrop();
    }
    function paletteOptions(): var {
        return Services.Theme.schemeLabels;
    }
    function togglePaletteDrop(): void {
        if (root.paletteDropOpen) {
            root.closeDrop();
            return;
        }
        const opts = root.paletteOptions();
        if (opts.length === 0)
            return;
        root.dropCursor = Math.max(0, opts.indexOf(Services.Theme.activeLabel));
        root.openMenu = {kind: "palette"};
    }
    function commitPaletteCursor(): void {
        const opts = root.paletteOptions();
        if (!root.paletteDropOpen || opts.length === 0) {
            root.closeDrop();
            return;
        }
        root.applyPalette(opts[Services.Theme.clamp(root.dropCursor, 0, opts.length - 1)]);
        root.closeDrop();
    }
    function applyPalette(label: string): void {
        Services.Theme.applyScheme(Services.Theme.schemeIdFor(label));
    }
    function cyclePalette(dir: int): void {
        const opts = root.paletteOptions();
        if (opts.length === 0)
            return;
        root.applyPalette(SettingsUtil.cycleOpt(opts, Services.Theme.activeLabel, dir));
    }
    function toggleMonModeDrop(name: string): void {
        if (root.openMonRes === name) {
            root.closeDrop();
            return;
        }
        const opts = Services.Monitors.monitorModes(name);
        let at = opts.indexOf(Services.Monitors.monitorRes(name));
        if (at < 0)
            at = 0;
        root.dropCursor = at;
        root.openMenu = {kind: "res", name: name};
    }
    function mainOptions(): var {
        return Services.Monitors.mainMonitorOptions();
    }
    function toggleMainDrop(): void {
        if (root.enabledCount < 2)
            return;
        if (root.openMainDrop) {
            root.closeDrop();
            return;
        }
        const opts = root.mainOptions();
        let at = opts.indexOf(Services.Monitors.mainMonitor);
        if (at < 0)
            at = 0;
        root.dropCursor = at;
        root.openMenu = {kind: "main"};
    }
    function cycleMainMonitor(dir: int): void {
        if (root.enabledCount < 2)
            return;
        const opts = root.mainOptions();
        if (opts.length === 0)
            return;
        Services.Monitors.setMainMonitor(SettingsUtil.cycleOpt(opts, Services.Monitors.mainMonitor, dir));
    }
    function commitMainCursor(): void {
        const opts = root.mainOptions();
        if (!root.openMainDrop || opts.length === 0) {
            root.closeDrop();
            return;
        }
        Services.Monitors.setMainMonitor(opts[Services.Theme.clamp(root.dropCursor, 0, opts.length - 1)]);
        root.closeDrop();
    }
    function commitMonMode(name: string, mode: string): void {
        root.beginMonitorChange();
        Services.Monitors.setMonitorRes(name, mode);
        root.closeDrop();
    }
    function commitMonModeCursor(): void {
        const name = root.openMonRes;
        const opts = Services.Monitors.monitorModes(name);
        if (name === "" || opts.length === 0) {
            root.closeDrop();
            return;
        }
        root.commitMonMode(name, opts[Services.Theme.clamp(root.dropCursor, 0, opts.length - 1)]);
    }

    property int wpCols: 3
    property int wpCellH: 102
    property int wpGap: 4
    property int wpCount: Services.Settings.wallpapers.length
    property int wpVisible: Math.min(root.wpCount, 9)
    property int wpRowsVisible: Math.ceil(root.wpVisible / root.wpCols)
    property int wpListH: root.wpRowsVisible * root.wpCellH + Math.max(0, root.wpRowsVisible - 1) * root.wpGap
    property int wpInputBase: root.wpCount > 0 ? 1 : 0
    property int themeBase: root.wpInputBase
    property int inputBase: root.themeBase + 1
    property int swatchH: 14
    property int themeHintH: 14
    property int paletteMenuMax: 6
    property int paletteMenuH: Services.Theme.schemeLabels.length === 0 ? 0 : Services.Theme.listHeight(Math.min(Services.Theme.schemeLabels.length, root.paletteMenuMax)) + 8
    function paletteRowTop(): int {
        return root.sectionH + Services.Theme.popupSpacing + root.wallColH + (root.wpCount > 0 ? Services.Theme.popupSpacing + root.wallHintH : 0) + Services.Theme.popupSpacing + root.sectionH + Services.Theme.popupSpacing;
    }
    property int wallHintH: 14
    property int wallWrapPad: 6
    property int inputRows: 3
    property int sectionH: 18
    property int enabledCount: Services.Monitors.enabledMonitors().length
    property int monFirst: 2
    property int monRows: 3
    property int monCardPad: 8
    property int monHeaderH: 22
    property int monSubH: 16
    property int monBlockH: root.monHeaderH + root.monSubH + root.monRows * Services.Theme.rowHeight + (root.monRows + 1) * Services.Theme.listSpacing + 2 * root.monCardPad
    property int monCount: Services.Monitors.monitors.length
    property int monFootH: Services.Theme.rowHeight + Services.Theme.popupSpacing + 14
    property int monFullH: root.monCount * root.monBlockH + Math.max(0, root.monCount - 1) * Services.Theme.popupSpacing
    property int previewH: displaysTab.previewAreaH
    property int previewHintH: 14

    property int mainSelH: Services.Theme.rowHeight
    property int wallColH: root.wpListH + (root.wpCount > 0 ? root.wallWrapPad * 2 : 0)
    property int inputColH: 3 * Services.Theme.rowHeight + 2 * Services.Theme.listSpacing
    property int sysIdleH: 4 * Services.Theme.rowHeight + 3 * Services.Theme.listSpacing
    property int sysBattH: (3 + root.asusRows) * Services.Theme.rowHeight + (2 + root.asusRows) * Services.Theme.listSpacing
    property int sysProfH: 2 * Services.Theme.rowHeight + Services.Theme.listSpacing
    property int asusRows: Services.Asus.available ? 1 : 0
    function sysIdx(n: int): int {
        return n + root.asusRows;
    }
    function contentHeight(): int {
        if (root.tab === 0) {
            const top = root.paletteRowTop() + Services.Theme.rowHeight;
            const base = top + Services.Theme.popupSpacing + root.swatchH + Services.Theme.popupSpacing + root.themeHintH + Services.Theme.popupSpacing + root.sectionH + Services.Theme.popupSpacing + root.inputColH;
            if (root.paletteDropOpen)
                return Math.max(base, top + Services.Theme.listSpacing + root.paletteMenuH);
            return base;
        }
        if (root.tab === 1) {
            let h = root.sysIdleH + root.sysBattH + root.sysProfH + 3 * root.sectionH + 30 + 6 * Services.Theme.popupSpacing;
            return h;
        }
        if (root.monCount === 0)
            return root.mainSelH + Services.Theme.popupSpacing + 30 + Services.Theme.popupSpacing + root.monFootH;
        const preview = root.enabledCount > 1 ? root.previewH + Services.Theme.popupSpacing + root.previewHintH + Services.Theme.popupSpacing : 0;
        return root.mainSelH + Services.Theme.popupSpacing + preview + root.monFullH + Services.Theme.popupSpacing + root.monFootH;
    }
    PopupCard {
        Row {
            id: tabRow
            width: parent.width
            height: Services.Theme.rowHeight
            spacing: Services.Theme.popupSpacing
            PopupButton {
                label: "General"
                columns: 3
                accent: root.tab === 0
                selected: root.tab === 0
                onClicked: root.tab = 0
            }
            PopupButton {
                label: "System"
                columns: 3
                accent: root.tab === 1
                selected: root.tab === 1
                onClicked: root.tab = 1
            }
            PopupButton {
                label: "Displays"
                columns: 3
                accent: root.tab === 2
                selected: root.tab === 2
                onClicked: root.tab = 2
            }
        }

        GeneralTab {
            id: generalTab
            popup: root
        }

        SystemTab {
            popup: root
        }

        DisplaysTab {
            id: displaysTab
            popup: root
        }
    }
}
