// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class SleepInhibitor : GLib.Object {
        private int fd = -1;
        private GLib.DBusConnection? connection = null;
        private uint request_generation = 0;

        public int timeout_msec = 2000;

        public bool active { get { return fd >= 0; } }

        // Exposed so tests can verify that acquire() keeps a real descriptor
        // alive rather than the (h) index from the reply body.
        public int handle { get { return fd; } }

        public bool acquire () {
            if (fd >= 0)
                return true;
            try {
                if (connection == null)
                    connection = GLib.Bus.get_sync (GLib.BusType.SYSTEM, null);
                GLib.UnixFDList? fd_list = null;
                connection.call_with_unix_fd_list_sync (
                    "org.freedesktop.login1", "/org/freedesktop/login1",
                    "org.freedesktop.login1.Manager", "Inhibit",
                    new GLib.Variant ("(ssss)", "sleep", "Gradio", "Playing radio", "block"),
                    new GLib.VariantType ("(h)"), GLib.DBusCallFlags.NONE, timeout_msec,
                    null, out fd_list, null);
                if (fd_list == null || fd_list.get_length () < 1)
                    return false;
                // UnixFDList.get() dups the descriptor, so it stays live after
                // the reply list is freed.
                fd = fd_list.get (0);
                return fd >= 0;
            } catch (GLib.Error e) {
                fd = -1;
                return false;
            }
        }

        // Non-blocking variant used by the UI: a slow or absent system bus must
        // never freeze the main loop for the D-Bus timeout.
        public async bool acquire_async (GLib.Cancellable? cancellable = null) {
            if (fd >= 0)
                return true;
            uint generation = ++request_generation;
            try {
                var conn = connection;
                if (conn == null) {
                    conn = yield GLib.Bus.get (GLib.BusType.SYSTEM, cancellable);
                    connection = conn;
                }
                GLib.UnixFDList? fd_list = null;
                yield conn.call_with_unix_fd_list (
                    "org.freedesktop.login1", "/org/freedesktop/login1",
                    "org.freedesktop.login1.Manager", "Inhibit",
                    new GLib.Variant ("(ssss)", "sleep", "Gradio", "Playing radio", "block"),
                    new GLib.VariantType ("(h)"), GLib.DBusCallFlags.NONE, timeout_msec,
                    null, cancellable, out fd_list);
                if (generation != request_generation)
                    return false;
                if (fd_list == null || fd_list.get_length () < 1)
                    return false;
                fd = fd_list.get (0);
                return fd >= 0;
            } catch (GLib.Error e) {
                if (generation == request_generation)
                    fd = -1;
                return false;
            }
        }

        public void release () {
            request_generation++;
            if (fd < 0)
                return;
            GLib.FileUtils.close (fd);
            fd = -1;
        }
    }
}
