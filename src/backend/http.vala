// SPDX-License-Identifier: GPL-3.0-or-later

using Soup;

namespace Gradio {

    public errordomain HttpError {
        REQUEST_FAILED
    }

    public class Http {
        public static string normalize_url (string url) {
            return url.strip ();
        }

        public static bool is_valid_url (string url) {
            string normalized = normalize_url (url);
            if (normalized == "")
                return false;

            try {
                var uri = GLib.Uri.parse (normalized, GLib.UriFlags.NONE);
                string? scheme = uri.get_scheme ();
                string? host = uri.get_host ();

                if (scheme == null || (scheme != "http" && scheme != "https"))
                    return false;
                if (host == null || host == "")
                    return false;
                if (host.contains (" ") || host.contains ("\t") || host.contains ("\n"))
                    return false;

                return true;
            } catch (GLib.Error e) {
                return false;
            }
        }

        public static string url_with_query (string url, GLib.HashTable<string,string>? query) {
            if (query == null || query.size () == 0)
                return url;

            string encoded = Soup.Form.encode_hash (query);
            if (encoded == "")
                return url;

            string separator = "?";
            if (url.contains ("?"))
                separator = (url.has_suffix ("?") || url.has_suffix ("&")) ? "" : "&";

            return url + separator + encoded;
        }

        public static string bytes_to_string (GLib.Bytes bytes) {
            unowned uint8[]? data = bytes.get_data ();
            if (data == null || bytes.get_size () == 0)
                return "";

            var builder = new GLib.StringBuilder ();
            builder.append_len ((string) data, (ssize_t) bytes.get_size ());
            return builder.str;
        }

        public static async GLib.Bytes get_bytes_async (Soup.Session session, string url,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            string normalized = normalize_url (url);
            if (!is_valid_url (normalized))
                throw new HttpError.REQUEST_FAILED ("Invalid URL: %s", url);

            var message = new Soup.Message ("GET", normalized);
            var bytes = yield session.send_and_read_async (message, GLib.Priority.DEFAULT, cancellable);

            int status = (int) message.get_status ();
            if (status < 200 || status >= 300)
                throw new HttpError.REQUEST_FAILED ("HTTP %d for %s", status,
                    message.get_uri ().to_string ());

            return bytes;
        }

        public static async string get_string_async (Soup.Session session, string url,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            var bytes = yield get_bytes_async (session, url, cancellable);
            return bytes_to_string (bytes);
        }

        public static async string post_string_async (Soup.Session session, string url,
                string body, string content_type = "application/json",
                GLib.Cancellable? cancellable = null) throws GLib.Error {
            string normalized = normalize_url (url);
            if (!is_valid_url (normalized))
                throw new HttpError.REQUEST_FAILED ("Invalid URL: %s", url);

            var message = new Soup.Message ("POST", normalized);
            message.set_request_body_from_bytes (content_type, new GLib.Bytes (body.data));
            var bytes = yield session.send_and_read_async (message, GLib.Priority.DEFAULT,
                cancellable);

            int status = (int) message.get_status ();
            if (status < 200 || status >= 300)
                throw new HttpError.REQUEST_FAILED ("HTTP %d for %s", status,
                    message.get_uri ().to_string ());

            return bytes_to_string (bytes);
        }
    }
}
