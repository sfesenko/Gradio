// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {
    public delegate bool TaskWork ();
    public delegate void TaskDone (bool ok);

    // Runs CPU-bound work on a worker and returns to the main context. The
    // worker must not touch the model or widgets; it reports through dispatch.
    public class BackgroundTask : GLib.Object {
        public static void run (owned TaskWork work, owned TaskDone done) {
            new Thread<bool> ("gradio-task", () => {
                bool ok = work ();
                GLib.Idle.add (() => {
                    done (ok);
                    return false;
                });
                return true;
            });
        }
    }
}