// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    // Disk cache for station icons. The cache itself is GTK-free: it only
    // decodes and re-encodes images with gdk-pixbuf.
    public class FaviconCache : GLib.Object {
        public const size_t MAX_BYTES = 2 * 1024 * 1024;
        public const int MAX_SIZE = 128;

        public string directory { get; private set; }

        public FaviconCache (string? directory = null) {
            if (directory != null && directory != "") {
                this.directory = directory;
            } else {
                this.directory = GLib.Path.build_filename (
                    GLib.Environment.get_user_cache_dir (), "gradio", "favicons");
            }
        }

        public static string hash_url (string url) {
            var checksum = new GLib.Checksum (GLib.ChecksumType.SHA256);
            checksum.update (url.data, url.length);
            return checksum.get_string ();
        }

        public string path_for (string url) {
            return GLib.Path.build_filename (directory, hash_url (url) + ".png");
        }

        public string? lookup (string url) {
            string path = path_for (url);
            if (GLib.FileUtils.test (path, GLib.FileTest.EXISTS))
                return path;
            return null;
        }

        public string? store (string url, uint8[] data) {
            if (data.length == 0 || data.length > MAX_BYTES)
                return null;

            Gdk.Pixbuf pixbuf;
            try {
                var stream = new GLib.MemoryInputStream.from_data (data.copy ());
                pixbuf = new Gdk.Pixbuf.from_stream (stream, null);
            } catch (GLib.Error e) {
                return null;
            }

            int width = pixbuf.get_width ();
            int height = pixbuf.get_height ();
            if (width <= 0 || height <= 0)
                return null;

            Gdk.Pixbuf scaled = pixbuf;
            if (width > MAX_SIZE || height > MAX_SIZE) {
                double ratio = double.min ((double) MAX_SIZE / width, (double) MAX_SIZE / height);
                int scaled_width = int.max (1, (int) (width * ratio));
                int scaled_height = int.max (1, (int) (height * ratio));
                scaled = pixbuf.scale_simple (scaled_width, scaled_height,
                    Gdk.InterpType.BILINEAR);
                if (scaled == null)
                    return null;
            }

            try {
                GLib.DirUtils.create_with_parents (directory, 0700);
            } catch (GLib.Error e) {
            }

            string path = path_for (url);
            string temp = path + ".tmp";
            try {
                scaled.save (temp, "png");
                GLib.FileUtils.rename (temp, path);
            } catch (GLib.Error e) {
                GLib.FileUtils.remove (temp);
                return null;
            }

            return path;
        }

        public void clear () {
            try {
                var dir = GLib.Dir.open (directory, 0);
                string? name;
                while ((name = dir.read_name ()) != null) {
                    GLib.FileUtils.remove (GLib.Path.build_filename (directory, name));
                }
            } catch (GLib.Error e) {
            }
        }
    }

    // Negative cache for icon sources that failed recently. Keys are prefixed
    // with `u:` for icon URLs and `h:` for homepages.
    public class FaviconCooldown : GLib.Object {
        public const int64 TTL_USEC = 3600000000;

        private GLib.HashTable<string, int64?> failures =
            new GLib.HashTable<string, int64?> (str_hash, str_equal);

        public bool is_blocked (string key, int64 now) {
            unowned int64? failed_at = failures.lookup (key);
            if (failed_at == null)
                return false;
            if (now - failed_at >= TTL_USEC) {
                failures.remove (key);
                return false;
            }
            return true;
        }

        public void record_failure (string key, int64 now) {
            failures.set (key, now);
        }

        public void clear () {
            failures.remove_all ();
        }
    }

    // Extracts a usable icon URL from a station homepage.
    public class FaviconResolver {
        public static string? origin_icon_url (string page_url) {
            if (!Http.is_valid_url (page_url))
                return null;

            try {
                var uri = GLib.Uri.parse (page_url, GLib.UriFlags.NONE);
                string? scheme = uri.get_scheme ();
                string? host = uri.get_host ();
                if (scheme == null || host == null || host == "")
                    return null;

                string origin = "%s://%s".printf (scheme, host);
                int port = uri.get_port ();
                bool default_port = (scheme == "http" && port == 80) ||
                    (scheme == "https" && port == 443);
                if (port > 0 && !default_port)
                    origin += ":%d".printf (port);

                return origin + "/favicon.ico";
            } catch (GLib.Error e) {
                return null;
            }
        }

        public static string? icon_url_from_html (string html, string page_url) {
            try {
                var tag_regex = new GLib.Regex ("(?is)<link\\b[^>]*>");
                GLib.MatchInfo match;
                int start = 0;
                while (tag_regex.match_full (html, -1, start, 0, out match)) {
                    string tag = match.fetch (0);
                    int tag_start, tag_end;
                    match.fetch_pos (0, out tag_start, out tag_end);
                    start = tag_end;
                    string? rel = attribute (tag, "rel");
                    string? href = attribute (tag, "href");
                    if (rel == null || href == null || !rel.down ().contains ("icon"))
                        continue;

                    string? resolved = resolve_url (page_url, href);
                    if (resolved != null)
                        return resolved;
                }
            } catch (GLib.Error e) {
            }

            return null;
        }

        private static string? attribute (string tag, string name) {
            try {
                var regex = new GLib.Regex (
                    "(?is)\\b%s\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))".printf (name));
                GLib.MatchInfo match;
                if (!regex.match (tag, 0, out match))
                    return null;

                for (int i = 1; i <= 3; i++) {
                    string value = match.fetch (i);
                    if (value != null && value != "")
                        return value;
                }
            } catch (GLib.Error e) {
            }

            return null;
        }

        private static string? resolve_url (string page_url, string href) {
            try {
                string resolved = GLib.Uri.resolve_relative (page_url, href.strip (), GLib.UriFlags.NONE);
                if (Http.is_valid_url (resolved))
                    return resolved;
            } catch (GLib.Error e) {
            }
            return null;
        }
    }
}
