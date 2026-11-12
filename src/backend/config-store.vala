// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {
    // Config serialization and persistence. UI calls save() on the main
    // thread; writes use FileIO async. Latest snapshot wins.
    public class ConfigStore : GLib.Object {
        public signal void saved ();
        public signal void save_failed (string message);

        public AppConfig config { get; private set; }
        public string path { get; private set; }

        private bool load_failed;
        private bool read_only;
        private bool dirty;
        private bool backup_pending;
        private bool writing = false;
        private uint generation = 0;
        private string? pending_data = null;

        public ConfigStore (AppConfig config, bool load_failed = false,
                bool read_only = false) {
            this.config = config;
            this.path = config.path;
            this.load_failed = load_failed;
            this.read_only = read_only;
            this.backup_pending = load_failed;
        }

        public void mark_dirty () {
            dirty = true;
        }

        public bool save () {
            if (read_only)
                return false;
            if (load_failed && !dirty)
                return false;

            string data;
            try {
                data = config.to_json ();
            } catch (GLib.Error e) {
                save_failed (e.message);
                return false;
            }

            dirty = true;
            generation++;
            pending_data = data;
            if (!writing)
                start_write ();
            return true;
        }

        // Explicit synchronous exception: only used during shutdown, when no
        // interactive main loop remains.
        public bool flush_sync () {
            if (read_only)
                return false;
            if (load_failed && !dirty)
                return false;

            // Shutdown-only: let any in-flight async write finish first so the
            // backup/save order stays deterministic.
            if (writing) {
                var loop = new GLib.MainLoop ();
                int64 deadline = GLib.get_monotonic_time () +
                    2 * GLib.TimeSpan.SECOND;
                GLib.Timeout.add (10, () => {
                    if (!writing || GLib.get_monotonic_time () >= deadline) {
                        loop.quit ();
                        return false;
                    }
                    return true;
                });
                loop.run ();
            }

            if (backup_pending) {
                backup_pending = false;
                string backup = path + ".corrupt";
                try {
                    GLib.FileUtils.remove (backup);
                    if (GLib.FileUtils.test (path, GLib.FileTest.EXISTS))
                        GLib.FileUtils.rename (path, backup);
                } catch (GLib.Error e) {
                }
            }

            try {
                config.save ();
                dirty = false;
                return true;
            } catch (GLib.Error e) {
                save_failed (e.message);
                return false;
            }
        }

        private void start_write () {
            if (writing || pending_data == null)
                return;

            var data = pending_data;
            pending_data = null;
            var gen = generation;
            writing = true;
            write_async.begin (data, gen);
        }

        private async void write_async (string data, uint gen) {
            try {
                if (backup_pending) {
                    backup_pending = false;
                    string backup = path + ".corrupt";
                    try {
                        yield FileIO.remove_async (backup);
                    } catch (GLib.Error e) {
                    }
                    try {
                        yield FileIO.rename_async (path, backup);
                    } catch (GLib.Error e) {
                        if (e.code != IOError.NOT_FOUND)
                            throw e;
                    }
                }

                yield FileIO.save_text_atomic_async (path, data);
                if (gen == generation) {
                    dirty = false;
                    saved ();
                }
            } catch (GLib.Error e) {
                if (gen == generation) {
                    dirty = false;
                    save_failed (e.message);
                }
            }

            writing = false;
            if (pending_data != null)
                start_write ();
        }
    }
}