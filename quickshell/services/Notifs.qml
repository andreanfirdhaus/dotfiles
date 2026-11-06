pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
Singleton {
    id: notifs
    property var toasts: []
    property var pending: []
    property bool suppressToasts: false
    property var history: []
    property int historySeq: 0
    property int readSeq: 0
    property bool historyVisible: false
    function isUnread(h): bool {
        return (h?.seq ?? 0) > notifs.readSeq;
    }
    readonly property int unread: notifs.history.filter(h => notifs.isUnread(h)).length
    readonly property int criticalUnread: notifs.history.filter(h => notifs.isUnread(h) && h?.critical === true).length
    property int toastSeq: 0
    readonly property string historyFile: Paths.dataPath("notif-history.json")
    function syncIdOf(n): var {
        return n?.hints ? n.hints["x-canonical-private-synchronous"] : undefined;
    }
    function valueOf(n): var {
        return n?.hints ? n.hints["value"] : undefined;
    }
    function isOwnFeedback(app: string): bool {
        if (app === "dnd" || app === "caffeine" || app === "bluelight" || app === "screenshot")
            return true;
        return app === "volume" || app === "brightness" || app === "media" || app === "power" || app === "emoji" || app === "clipboard" || app === "settings";
    }
    function isOsd(n): bool {
        if (!n || n.qsInternal !== true)
            return false;
        const k = n.qsSyncKey;
        return k === "volume" || k === "brightness" || k === "mic" || k === "media" || k === "charger" || k === "caffeine" || k === "dnd";
    }
    function bypassesDnd(n): bool {
        if (n?.qsInternal === true)
            return true;
        if (notifs.isOwnFeedback(n?.appName ?? ""))
            return true;
        return n?.urgency === NotificationUrgency.Critical;
    }
    function showInFullscreen(n): bool {
        return n?.urgency === NotificationUrgency.Critical;
    }
    function toastKey(t): var {
        return t && t.qsToastId !== undefined ? t.qsToastId : t;
    }
    function sameToast(a, b): bool {
        if (a === b)
            return true;
        if (!a || !b)
            return false;
        return notifs.toastKey(a) === notifs.toastKey(b);
    }
    function unlistToast(n): void {
        if (!n)
            return;
        notifs.toasts = notifs.toasts.filter(t => !notifs.sameToast(t, n));
        notifs.pending = notifs.pending.filter(t => !notifs.sameToast(t, n));
    }
    function hideToast(n): void {
        if (!n) {
            console.warn("quickshell: hideToast called without notification");
            return;
        }
        notifs.unlistToast(n);
        notifs.purgeTransientLive(n);
    }
    function purgeTransientLive(n): void {
        if (!n)
            return;
        const before = notifs.history.length;
        notifs.history = notifs.history.filter(h => !(h && h.transient === true && h.live === n));
        if (notifs.history.length !== before)
            notifs.schedulePersist();
    }
    function dismissToast(n): void {
        if (!n)
            return;
        notifs.hideToast(n);
        notifs.releaseHistoryLive(n);
        notifs.safeDismiss(n);
    }
    function expireToast(n): void {
        if (!n || n.resident === true)
            return;
        notifs.dismissToast(n);
    }
    function consumeToast(n): void {
        if (!n)
            return;
        notifs.hideToast(n);
        notifs.safeDismiss(n);
        notifs.forgetLive(n);
    }
    function finishToastAfterAction(n, ok): void {
        if (!ok) {
            notifs.hideToast(n);
            return;
        }
        if (n && n.resident === true)
            notifs.dismissToast(n);
        else
            notifs.consumeToast(n);
    }
    function dismissHistoryAfterAction(i: int, live): void {
        if (live && live.resident === true)
            return;
        notifs.dismissHistoryAt(i);
    }
    function shelveToasts(): void {
        if (notifs.toasts.length === 0)
            return;
        notifs.pending = [...notifs.toasts, ...notifs.pending].slice(0, Theme.toastMax);
        notifs.toasts = [];
    }
    function setSuppressed(suppressed: bool): void {
        notifs.suppressToasts = suppressed;
        if (suppressed)
            notifs.shelveToasts();
        else
            notifs.flushPending();
    }
    function markRead(): void {
        if (notifs.readSeq !== notifs.historySeq) {
            notifs.readSeq = notifs.historySeq;
            notifs.schedulePersist();
        }
    }
    function effectiveTimeout(t): int {
        if (!t)
            return Theme.toastTimeout;
        const exp = t.expireTimeout;
        if (exp > 0) {
            if (t.urgency === NotificationUrgency.Low)
                return Math.min(exp, Theme.lowToastTimeout);
            return exp;
        }
        if (t.resident === true || exp === 0)
            return -1;
        if (t.urgency === NotificationUrgency.Critical)
            return Theme.criticalToastTimeout;
        if (t.urgency === NotificationUrgency.Low)
            return Theme.lowToastTimeout;
        return Theme.toastTimeout;
    }
    function flushPending(): void {
        const room = Math.max(0, Theme.toastMax - notifs.toasts.length);
        const now = Date.now();
        const fresh = notifs.pending.slice(0, room).filter(t => {
                if (notifs.isExpired(t, now)) {
                    notifs.purgeTransientLive(t);
                    return false;
                }
                return true;
            });
        for (const t of fresh)
            notifs.stampToast(t);
        notifs.toasts = [...fresh, ...notifs.toasts];
        notifs.pending = notifs.pending.slice(room);
    }
    function stampToast(n): void {
        if (!n)
            return;
        try {
            n.addedAt = Date.now();
        } catch (_) {}
    }
    property int timeTick: 0
    function timeAgo(when): string {
        // Read the tick so this re-evaluates when the refresh timer fires.
        notifs.timeTick;
        const t = when instanceof Date ? when.getTime() : Number(when ?? 0);
        if (!(t > 0) || !isFinite(t))
            return "";
        const s = Math.max(0, Math.floor((Date.now() - t) / 1000));
        if (s < 60)
            return "now";
        const m = Math.floor(s / 60);
        if (m < 60)
            return m + "m";
        const h = Math.floor(m / 60);
        if (h < 24)
            return h + "h";
        const d = Math.floor(h / 24);
        if (d < 7)
            return d + "d";
        return Qt.formatDateTime(new Date(t), "d MMM");
    }
    function isExpired(t, now): bool {
        const timeout = notifs.effectiveTimeout(t);
        if (!(timeout > 0))
            return false;
        return (now - (t.addedAt ?? now)) > timeout + 2000;
    }
    function sweepExpired(): void {
        const now = Date.now();
        for (const t of [...notifs.toasts, ...notifs.pending]) {
            if (notifs.isExpired(t, now))
                notifs.expireToast(t);
        }
    }
    function safeDismiss(n): void {
        if (!n)
            return;
        try {
            n.dismiss();
        } catch (_) {}
        notifs.detachClosed(n);
    }
    function detachClosed(n): void {
        if (!n || !n._qsOnClosed)
            return;
        try {
            n.closed.disconnect(n._qsOnClosed);
        } catch (_) {}
        n._qsOnClosed = null;
    }
    function releaseHistoryLive(n): void {
        if (!n)
            return;
        let changed = false;
        for (const h of notifs.history) {
            if (h && h.live === n) {
                h.live = null;
                changed = true;
            }
        }
        if (changed) {
            notifs.history = notifs.history.slice();
            notifs.schedulePersist();
        }
    }
    function trackClosed(n): void {
        if (!n || n._qsOnClosed)
            return;
        try {
            n._qsOnClosed = function () {
                notifs.hideToast(n);
                notifs.releaseHistoryLive(n);
                notifs.detachClosed(n);
            };
            n.closed.connect(n._qsOnClosed);
        } catch (_) {
            n._qsOnClosed = null;
        }
    }
    function dropLive(item): void {
        if (!item || !item.live)
            return;
        const n = item.live;
        item.live = null;
        notifs.hideToast(n);
        notifs.safeDismiss(n);
    }
    function forgetLive(n): void {
        notifs.detachClosed(n);
        notifs.history = notifs.history.filter(h => h.live !== n);
        notifs.unlistToast(n);
        notifs.schedulePersist();
    }
    function filepathOf(notification): string {
        const hints = notification?.hints;
        const p = hints && typeof hints["filepath"] === "string" ? hints["filepath"] : "";
        return notifs.safeFilepath(p);
    }
    function safeFilepath(p: string): string {
        if (typeof p !== "string" || p === "" || p.length > 4096)
            return "";
        if (p.startsWith("file://")) {
            const stripped = p.slice(7);
            if (!stripped.startsWith("/") || stripped.includes("\n") || stripped.includes("\0"))
                return "";
            const lower = stripped.toLowerCase();
            if (lower.endsWith(".desktop") || lower.endsWith(".sh") || lower.endsWith(".exe"))
                return "";
            return stripped;
        }
        if (!p.startsWith("/") || p.includes("\n") || p.includes("\0") || p.includes(".."))
            return "";
        const lower = p.toLowerCase();
        if (lower.endsWith(".desktop") || lower.endsWith(".sh") || lower.endsWith(".exe"))
            return "";
        return p;
    }
    function activateAction(notification, action): bool {
        if (!notification || !action)
            return false;
        const path = notifs.filepathOf(notification);
        const id = action?.identifier ?? "";
        if (path !== "" && (id === "open" || id === "path" || id === "default")) {
            if (id === "path") {
                if (path.length > 4096)
                    return false;
                Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy', "qs", path]);
            } else {
                Quickshell.execDetached(["xdg-open", path]);
            }
            return true;
        }
        try {
            action.invoke();
        } catch (_) {
            return false;
        }
        return true;
    }
    function defaultActionOf(actions): var {
        const list = actions ?? [];
        return list.find(a => (a?.identifier ?? "") === "default") ?? null;
    }
    function secondaryActionsOf(actions): var {
        const list = actions ?? [];
        return list.filter(a => (a?.identifier ?? "") !== "default").slice(0, 3);
    }
    function activateDefault(live): bool {
        if (!live)
            return false;
        const act = notifs.defaultActionOf(live?.actions ?? []);
        if (!act)
            return false;
        return notifs.activateAction(live, act);
    }
    function clearHistory(): void {
        for (const h of notifs.history)
            notifs.dropLive(h);
        notifs.history = [];
        notifs.readSeq = notifs.historySeq;
        notifs.schedulePersist();
    }
    function dismissHistoryAt(i: int): void {
        if (i < 0 || i >= notifs.history.length)
            return;
        notifs.dropLive(notifs.history[i]);
        notifs.history = notifs.history.filter((_, idx) => idx !== i);
        notifs.schedulePersist();
    }
    function truncStr(v, max: int): string {
        const s = typeof v === "string" ? v : String(v ?? "");
        return s.length > max ? s.slice(0, max) : s;
    }
    function richBody(body): string {
        let s = String(body ?? "");
        if (s === "")
            return "";
        const tags = [];
        const keep = function (m) {
            tags.push(m);
            return "\uE000" + (tags.length - 1) + "\uE001";
        };
        s = s.replace(/<\/?(?:b|i|u)>/gi, keep);
        s = s.replace(/<a\s+href="[^"]*">|<\/a>|<img\s+src="[^"]*"\s*\/?>/gi, keep);
        s = s.replace(/&(?!amp;|lt;|gt;|quot;|#\d+;|#x[0-9a-fA-F]+;)/g, "&amp;");
        s = s.replace(/</g, "&lt;").replace(/>/g, "&gt;");
        s = s.replace(/\uE000(\d+)\uE001/g, function (m, k) {
                return tags[Number(k)] ?? "";
            });
        return s;
    }
    function snapshot(n): var {
        const cands = [n.image, n.appIcon];
        const hit = cands.find(s => typeof s === "string" && s !== "");
        const syncId = notifs.syncIdOf(n);
        return {
            seq: ++notifs.historySeq,
            app: notifs.truncStr(n.appName ?? "", 128),
            summary: notifs.truncStr(n.summary ?? "", 256),
            body: notifs.truncStr(n.body ?? "", 1024),
            icon: notifs.truncStr(hit ?? "", 512),
            critical: n.urgency === NotificationUrgency.Critical,
            time: new Date(),
            syncId: typeof syncId === "string" ? notifs.truncStr(syncId, 128) : syncId,
            transient: n.transient === true,
            live: n
        };
    }
    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true
        onNotification: notification => notifs.handleNotification(notification)
    }
    function handleNotification(notification): void {
        const syncId = notifs.syncIdOf(notification);
        if (syncId !== undefined) {
            for (const old of [...notifs.toasts, ...notifs.pending]) {
                if (notifs.syncIdOf(old) === syncId) {
                    notifs.hideToast(old);
                    notifs.safeDismiss(old);
                    notifs.forgetLive(old);
                }
            }
        }
        if ((syncId === undefined || (notification.actions ?? []).length > 0) && notifs.valueOf(notification) === undefined) {
            let next = [notifs.snapshot(notification), ...notifs.history];
            if (syncId !== undefined)
                next = [next[0], ...next.slice(1).filter(h => h.syncId !== syncId)];
            for (const h of next.slice(Theme.historyMax))
                notifs.dropLive(h);
            notifs.history = next.slice(0, Theme.historyMax);
            notifs.schedulePersist();
        }
        notification.tracked = true;
        notifs.trackClosed(notification);
        notifs.stampToast(notification);
        if (Modes.dndActive && !notifs.bypassesDnd(notification))
            return;
        if (notifs.suppressToasts) {
            if (syncId === undefined || (notification.actions ?? []).length > 0)
                notifs.pending = [notification, ...notifs.pending].slice(0, Theme.toastMax);
            return;
        }
        let next = [notification, ...notifs.toasts].slice(0, Theme.toastMax);
        if (notifs.isOsd(notification))
            next = [next[0], ...next.slice(1).filter(t => !notifs.isOsd(t))];
        notification.qsToastId = ++notifs.toastSeq;
        notifs.toasts = next;
    }
    function notify(opts): void {
        const o = opts ?? {};
        if (o.syncId !== undefined && !(Modes.dndActive && !notifs.isOwnFeedback(o.app ?? ""))) {
            const cur = [...notifs.toasts, ...notifs.pending].find(t => t && t.qsInternal === true && t.qsSyncKey === o.syncId);
            if (cur) {
                cur.appName = o.app ?? cur.appName;
                cur.summary = o.summary ?? "";
                cur.body = o.body ?? "";
                cur.urgency = o.urgency ?? NotificationUrgency.Normal;
                cur.appIcon = o.icon ?? "";
                cur.expireTimeout = o.timeout ?? Theme.toastTimeout;
                notifs.stampToast(cur);
                cur.hints = {};
                if (o.hints !== undefined && typeof o.hints === "object" && o.hints !== null)
                    for (const hk in o.hints)
                        cur.hints[hk] = o.hints[hk];
                if (o.value !== undefined)
                    cur.hints["value"] = o.value;
                cur.hints["x-canonical-private-synchronous"] = o.syncId;
                if (o.filepath !== undefined)
                    cur.hints["filepath"] = o.filepath;
                notifs.toastSeq += 1;
                notifs.toasts = notifs.toasts.slice();
                return;
            }
        }
        const hints = {};
        if (o.hints !== undefined && typeof o.hints === "object" && o.hints !== null)
            for (const hk in o.hints)
                hints[hk] = o.hints[hk];
        if (o.value !== undefined)
            hints["value"] = o.value;
        if (o.syncId !== undefined)
            hints["x-canonical-private-synchronous"] = o.syncId;
        if (o.filepath !== undefined)
            hints["filepath"] = o.filepath;
        notifs.handleNotification({
            appName: o.app ?? "",
            summary: o.summary ?? "",
            body: o.body ?? "",
            urgency: o.urgency ?? NotificationUrgency.Normal,
            transient: false,
            resident: false,
            hints: hints,
            actions: o.actions ?? [],
            image: "",
            appIcon: o.icon ?? "",
            expireTimeout: o.timeout ?? Theme.toastTimeout,
            qsInternal: true,
            qsSyncKey: o.syncId,
            tracked: false,
            dismiss: () => {},
            closed: {
                connect: () => {},
                disconnect: () => {}
            }
        });
    }
    function schedulePersist(): void {
        persistTimer.restart();
    }
    function persistHistory(): void {
        if (notifs.historyFile === "")
            return;
        if (saver.running) {
            persistTimer.restart();
            return;
        }
        const kept = notifs.history.filter(h => h?.transient !== true).slice(0, Theme.historyMax);
        const data = kept.map(h => ({
                    seq: typeof h?.seq === "number" && isFinite(h.seq) ? Math.floor(h.seq) : 0,
                    app: notifs.truncStr(h?.app ?? "", 128),
                    summary: notifs.truncStr(h?.summary ?? "", 256),
                    body: notifs.truncStr(h?.body ?? "", 1024),
                    icon: notifs.truncStr(h?.icon ?? "", 512),
                    critical: !!h?.critical,
                    time: h?.time instanceof Date ? h.time.getTime() : Date.now(),
                    syncId: typeof h?.syncId === "string" ? notifs.truncStr(h.syncId, 128) : (h?.syncId ?? null)
                }));
        saver.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")"; printf "%s\\n" "$1" > "$2.tmp"; mv -f "$2.tmp" "$2"', "qs", JSON.stringify({version: 2, readSeq: notifs.readSeq, historySeq: notifs.historySeq, history: data}), notifs.historyFile];
        saver.running = true;
    }
    Timer {
        id: persistTimer
        interval: 1000
        repeat: false
        onTriggered: notifs.persistHistory()
    }
    Timer {
        id: expirySweep
        interval: 10000
        repeat: true
        running: notifs.toasts.length + notifs.pending.length > 0
        onTriggered: notifs.sweepExpired()
    }
    Timer {
        id: timeRefresh
        interval: 60000
        repeat: true
        running: notifs.toasts.length + notifs.pending.length > 0 || notifs.historyVisible
        onTriggered: notifs.timeTick += 1
    }
    onHistoryVisibleChanged: {
        if (notifs.historyVisible)
            notifs.timeTick += 1;
    }
    Process {
        id: saver
        onExited: exitCode => {
            if (exitCode !== 0)
                persistTimer.restart();
        }
    }
    function restoreEntry(e): var {
        return {
            app: notifs.truncStr(e?.app ?? "", 128),
            summary: notifs.truncStr(e?.summary ?? "", 256),
            body: notifs.truncStr(e?.body ?? "", 1024),
            icon: notifs.truncStr(e?.icon ?? "", 512),
            critical: !!e?.critical,
            time: new Date(typeof e?.time === "number" && isFinite(e.time) ? e.time : Date.now()),
            syncId: typeof e?.syncId === "string" ? notifs.truncStr(e.syncId, 128) : undefined,
            transient: false,
            live: null
        };
    }
    Process {
        id: historyLoader
        command: ["cat", notifs.historyFile]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (text.length > 1048576)
                        return;
                    const parsed = JSON.parse(text);
                    let arr = null, savedReadSeq = -1, savedHistorySeq = -1, savedReadCount = -1, isV2 = false;
                    if (Array.isArray(parsed)) {
                        arr = parsed;
                    } else if (parsed && typeof parsed === "object" && Array.isArray(parsed.history)) {
                        arr = parsed.history;
                        if (typeof parsed.readSeq === "number" && isFinite(parsed.readSeq))
                            savedReadSeq = Math.max(0, Math.floor(parsed.readSeq));
                        if (typeof parsed.historySeq === "number" && isFinite(parsed.historySeq))
                            savedHistorySeq = Math.max(0, Math.floor(parsed.historySeq));
                        if (typeof parsed.readCount === "number" && isFinite(parsed.readCount))
                            savedReadCount = Math.max(0, Math.min(Math.floor(parsed.readCount), Theme.historyMax));
                        isV2 = parsed.version === 2 && savedReadSeq >= 0;
                    } else {
                        return;
                    }
                    if (isV2) {
                        const restored = arr.slice(0, Theme.historyMax).map(e => {
                                const h = notifs.restoreEntry(e);
                                h.seq = typeof e?.seq === "number" && isFinite(e.seq) ? Math.max(0, Math.floor(e.seq)) : 0;
                                return h;
                            });
                        notifs.history = [...notifs.history, ...restored].slice(0, Theme.historyMax);
                        let maxSeq = savedHistorySeq;
                        for (const h of notifs.history)
                            maxSeq = Math.max(maxSeq, h?.seq ?? 0);
                        maxSeq = Math.max(maxSeq, notifs.historySeq);
                        notifs.historySeq = maxSeq;
                        notifs.readSeq = Math.max(0, Math.min(savedReadSeq, maxSeq));
                        return;
                    }
                    const liveCount = notifs.history.length;
                    const plain = arr.slice(0, Theme.historyMax).map(e => notifs.restoreEntry(e));
                    const merged = [...notifs.history, ...plain].slice(0, Theme.historyMax);
                    let seq = 0;
                    for (let i = merged.length - 1; i >= 0; i--)
                        merged[i].seq = ++seq;
                    notifs.history = merged;
                    notifs.historySeq = seq;
                    if (savedReadCount >= 0) {
                        const restoredUnread = Math.max(0, plain.length - savedReadCount);
                        const totalUnread = Math.min(merged.length, liveCount + restoredUnread);
                        if (totalUnread <= 0)
                            notifs.readSeq = seq;
                        else if (totalUnread >= merged.length)
                            notifs.readSeq = 0;
                        else
                            notifs.readSeq = merged[totalUnread]?.seq ?? 0;
                    } else {
                        notifs.readSeq = seq;
                    }
                } catch (_) {}
            }
        }
        Component.onCompleted: {
            if (notifs.historyFile !== "")
                historyLoader.running = true;
        }
    }

}
