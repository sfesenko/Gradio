// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class Locale {
        public static string parse_region (string locale) {
            if (locale == null)
                return "";
            string value = locale.strip ();
            int at = value.index_of ("@");
            if (at >= 0)
                value = value.substring (0, at);
            int dot = value.index_of (".");
            if (dot >= 0)
                value = value.substring (0, dot);

            int sep = value.index_of ("_");
            if (sep < 0)
                sep = value.index_of ("-");
            if (sep < 0 || sep + 3 != value.length)
                return "";

            string region = value.substring (sep + 1).up ();
            if (region.length != 2)
                return "";
            for (int i = 0; i < region.length; i++) {
                char c = region.get (i);
                if (c < 'A' || c > 'Z')
                    return "";
            }
            return region;
        }

        public static string region_code () {
            string? raw = GLib.Environment.get_variable ("LC_ALL");
            if (raw == null || raw == "")
                raw = GLib.Environment.get_variable ("LC_MESSAGES");
            if (raw == null || raw == "")
                raw = GLib.Environment.get_variable ("LANG");
            if (raw == null)
                return "US";
            string region = parse_region (raw);
            return region != "" ? region : "US";
        }
    }
}
