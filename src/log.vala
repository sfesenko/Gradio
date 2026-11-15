// SPDX-License-Identifier: GPL-3.0-or-later

// Duplicates GLib log output to a file. Console output is unchanged.
//
// GRADIO_LOG_FILE=/path is the only Gradio-specific logging variable:
//   GRADIO_LOG_FILE=/path ./gradio        warnings and errors, console + file
//   G_MESSAGES_DEBUG=gradio ...           app debug and Cast frames too
// The standard GLib controls still apply: G_MESSAGES_DEBUG picks the level,
// G_DEBUG=fatal-warnings makes warnings fatal. lib_core is built with
// G_LOG_DOMAIN="gradio" so the app can be selected without library noise.
namespace Gradio.Log {
    private static GLib.FileStream? file = null;
    private static GLib.Mutex mutex;
    private static bool installed = false;

    // Reads GRADIO_LOG_FILE. Called once from main() before anything logs.
    public static void init () {
        set_file (GLib.Environment.get_variable ("GRADIO_LOG_FILE"));
    }

    // Opens the file in append mode and installs the writer once. A null or
    // empty path disables duplication.
    public static void set_file (string? path) {
        mutex.lock ();
        if (file != null)
            file.flush ();
        file = null;
        if (path != null && path != "") {
            var dir = GLib.Path.get_dirname (path);
            if (dir != "" && !GLib.FileUtils.test (dir, GLib.FileTest.EXISTS))
                GLib.DirUtils.create_with_parents (dir, 0755);
            file = GLib.FileStream.open (path, "a");
            if (file == null)
                GLib.stderr.printf ("gradio: cannot open log file %s\n", path);
        }
        mutex.unlock ();

        if (file != null && !installed) {
            installed = true;
            install_writer ();
        }
    }

    [CCode (cname = "gradio_log_install_writer",
        cheader_filename = "log-writer.h")]
    private static extern void install_writer ();

    // Called by log-writer.c for each message the default writer would print.
    // The C side checks g_log_writer_default_would_drop() first.
    public static void write_file (int flags, string? domain, string message) {
        var now = new GLib.DateTime.now_local ();
        string prefix = domain != null && domain != "" ? domain + ": " : "";
        // Keep one record per line even when a payload contains newlines.
        string one_line = message.replace ("\n", "\\n").replace ("\r", "\\r");
        mutex.lock ();
        if (file != null) {
            file.printf ("%s.%03d [%s] %s%s\n", now.format ("%H:%M:%S"),
                (int) (now.get_microsecond () / 1000), level_name (flags),
                prefix, one_line);
            file.flush ();
        }
        mutex.unlock ();
    }

    private static string level_name (int flags) {
        if ((flags & ((int) GLib.LogLevelFlags.LEVEL_ERROR |
                (int) GLib.LogLevelFlags.LEVEL_CRITICAL)) != 0)
            return "ERROR";
        if ((flags & (int) GLib.LogLevelFlags.LEVEL_WARNING) != 0)
            return "WARN";
        if ((flags & ((int) GLib.LogLevelFlags.LEVEL_MESSAGE |
                (int) GLib.LogLevelFlags.LEVEL_INFO)) != 0)
            return "INFO";
        return "DEBUG";
    }
}
