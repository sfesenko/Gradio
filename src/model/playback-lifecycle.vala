// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class PlaybackLifecycle {
        public const int TRACK_HISTORY_LIMIT = 10;

        public static bool should_background_on_close (bool enabled, bool playing) {
            return enabled && playing;
        }

        public static string[] push_track_title (string[] titles, string title, int max) {
            string value = title.strip ();
            if (value == "" || max <= 0)
                return titles;
            if (titles.length > 0 && titles[0] == value)
                return titles;

            int keep = titles.length < max - 1 ? titles.length : max - 1;
            string[] result = { value };
            for (int i = 0; i < keep; i++)
                result += titles[i];
            return result;
        }
    }
}
