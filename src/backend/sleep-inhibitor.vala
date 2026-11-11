// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class SleepInhibitor : GLib.Object {
        private int fd = -1;
        private GLib.DBusConnection? connection = null;

        public int timeout_msec = 2000;

        public bool active { get { return fd >= 0; } }

        public bool acquire () {
            if (fd >= 0)
                return true;
            try {
                if (connection == null)
                    connection = GLib.Bus.get_sync (GLib.BusType.SYSTEM, null);
                var reply = connection.call_sync (
                    "org.freedesktop.login1", "/org/freedesktop/login1",
                    "org.freedesktop.login1.Manager", "Inhibit",
                    new GLib.Variant ("(ssss)", "sleep", "Gradio", "Playing radio", "block"),
                    new GLib.VariantType ("(h)"), GLib.DBusCallFlags.NONE, timeout_msec, null);
                int32 handle = -1;
                reply.get ("(h)", out handle);
                fd = (int) handle;
                return fd >= 0;
            } catch (GLib.Error e) {
                fd = -1;
                return false;
            }
        }

        public void release () {
            if (fd < 0)
                return;
            GLib.FileUtils.close (fd);
            fd = -1;
        }
    }
}
