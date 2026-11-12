// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {
    // Async file helpers. Every operation here returns to the main loop
    // instead of blocking it. The sync wrappers in AppConfig are reserved for
    // startup/shutdown and tests.
    public class FileIO : GLib.Object {
        public static async string load_text_async (string path) throws GLib.Error {
            var file = GLib.File.new_for_path (path);
            uint8[] contents;
            string? etag;
            yield file.load_contents_async (null, out contents, out etag);
            if (contents.length == 0)
                return "";
            return (string) contents;
        }

        public static async void save_text_atomic_async (string path, string text) throws GLib.Error {
            string dir = GLib.Path.get_dirname (path);
            if (dir != "" && dir != ".")
                yield ensure_directory_async (dir);

            var file = GLib.File.new_for_path (path);
            string? etag;
            yield file.replace_contents_async (text.data, null, false,
                GLib.FileCreateFlags.REPLACE_DESTINATION, null, out etag);
        }

        // Off-main convenience for worker tasks. Do not call from the GTK
        // main loop; use save_text_atomic_async there.
        public static void save_text_atomic_sync (string path, string text) throws GLib.Error {
            string dir = GLib.Path.get_dirname (path);
            if (dir != "" && dir != ".")
                GLib.DirUtils.create_with_parents (dir, 0755);
            var file = GLib.File.new_for_path (path);
            string? etag;
            file.replace_contents (text.data, null, false,
                GLib.FileCreateFlags.REPLACE_DESTINATION, out etag, null);
        }

        public static async bool remove_async (string path) throws GLib.Error {
            var file = GLib.File.new_for_path (path);
            try {
                yield file.delete_async ();
            } catch (GLib.Error e) {
                if (e.code == IOError.NOT_FOUND)
                    return false;
                throw e;
            }
            return true;
        }

        public static async bool rename_async (string from, string to) throws GLib.Error {
            string dir = GLib.Path.get_dirname (to);
            if (dir != "" && dir != ".")
                yield ensure_directory_async (dir);

            var source = GLib.File.new_for_path (from);
            var destination = GLib.File.new_for_path (to);
            yield source.move_async (destination, GLib.FileCopyFlags.NONE,
                GLib.Priority.DEFAULT, null, null);
            return true;
        }

        public static async void ensure_directory_async (string path) throws GLib.Error {
            if (path == "" || path == "." || path == "/")
                return;

            string[] parts = path.split ("/");
            string current = path.has_prefix ("/") ? "/" : ".";
            for (int i = 0; i < parts.length; i++) {
                if (parts[i] == "")
                    continue;
                current = current == "/" ? "/" + parts[i] : current + "/" + parts[i];
                var dir = GLib.File.new_for_path (current);
                try {
                    yield dir.make_directory_async ();
                } catch (GLib.Error e) {
                    if (e.code != IOError.EXISTS)
                        throw e;
                }
            }
        }
    }
}