// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class StationValidation {
        public static string? validate (string name, string url, string homepage,
                AppConfig config, string? ignore_id = null) {
            if (name.strip () == "")
                return _("Station name is required");
            if (!Http.is_valid_url (url))
                return _("Stream URL must be a valid http or https URL");
            if (homepage.strip () != "" && !Http.is_valid_url (homepage))
                return _("Homepage must be a valid http or https URL");

            string normalized = url.strip ();
            for (uint i = 0; i < config.stations.length; i++) {
                var station = config.stations.get (i);
                if (ignore_id != null && station.id == ignore_id)
                    continue;
                if (station.url == normalized || station.original_url == normalized)
                    return _("That stream is already in the library");
            }
            return null;
        }
    }
}
