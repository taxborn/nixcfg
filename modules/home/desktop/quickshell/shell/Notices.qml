pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The notification store. Toasts and the inbox read one list; the only
// difference between them is whether an entry is still allowed a toast.
Singleton {
    id: root

    readonly property int maxHistory: 50
    readonly property int maxToasts: 4
    // A notification asking for the server default gets a reading pause.
    readonly property int defaultTtlMs: 7000
    // One sweep for the whole list costs less than a timer per notice, and
    // buys half a second of slack on when a toast leaves.
    readonly property int sweepMs: 500

    property var all: []
    property bool quiet: false
    readonly property var toasts: all.filter(entry => entry.popup).slice(-maxToasts)

    // Entries are rebuilt wholesale rather than mutated, because assigning to
    // a field of one would not re-evaluate the bindings reading the list.
    // Each holds the live Notification, so inbox actions still reach the
    // sending application long after the toast is gone.
    function notice(notification, popup, until) {
        return {
            notification: notification,
            popup: popup,
            until: until
        };
    }

    function clear() {
        all.slice().forEach(entry => entry.notification.dismiss());
    }

    // Expiry is a resting time, not a deadline: until 0 means never.
    function expired(entry, now) {
        return entry.until > 0 && now >= entry.until;
    }

    onQuietChanged: {
        if (!quiet) {
            return;
        }

        all = all.map(entry => root.notice(entry.notification, false, entry.until));
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        persistenceSupported: true
        onNotification: notification => {
            notification.tracked = true;

            const ttl = notification.expireTimeout < 0 ? root.defaultTtlMs : notification.expireTimeout;
            const stays = notification.urgency === NotificationUrgency.Critical || ttl === 0;
            const fresh = root.notice(notification, !root.quiet && !notification.lastGeneration, stays ? 0 : Date.now() + ttl);

            root.all = root.all.filter(entry => entry.notification.id !== notification.id).concat([fresh]);
            notification.closed.connect(() => {
                root.all = root.all.filter(entry => entry.notification !== notification);
            });

            while (root.all.length > root.maxHistory) {
                root.all[0].notification.dismiss();
            }
        }
    }

    Timer {
        interval: root.sweepMs
        running: true
        repeat: true
        onTriggered: {
            const now = Date.now();

            // Transient notices leave no history, so their toast leaving is
            // the whole life of the notification. Close them for real.
            root.all.slice().forEach(entry => {
                if (root.expired(entry, now) && entry.notification.transient) {
                    entry.notification.expire();
                }
            });

            if (!root.all.some(entry => entry.popup && root.expired(entry, now))) {
                return;
            }

            root.all = root.all.map(entry => root.notice(entry.notification, entry.popup && !root.expired(entry, now), entry.until));
        }
    }
}
