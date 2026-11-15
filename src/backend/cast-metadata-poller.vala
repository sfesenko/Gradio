// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public errordomain CastMetadataError {
        UNSUPPORTED
    }

    // Reads one ICY metadata block from the casted stream, periodically.
    // ICY interleaves metadata every `icy-metaint` bytes and cannot seek, so
    // each poll opens a short connection, reads to the next block and drops
    // it: cost is one block per interval, not the whole stream (docs/CAST.md).
    public class CastMetadataPoller : GLib.Object {
        public signal void title_changed (string title);

        public const uint DEFAULT_INTERVAL_SECONDS = 20;
        private const uint POLL_TIMEOUT_SECONDS = 30;
        private const int MAX_METAINT = 1024 * 1024;

        private Soup.Session session;
        private string current_url = "";
        private uint _interval_seconds = DEFAULT_INTERVAL_SECONDS;
        private uint next_poll_id = 0;
        private bool running = false;
        private bool in_flight = false;
        private uint generation = 0;
        private int failures = 0;
        private string last_title = "";

        public uint interval_seconds {
            get { return _interval_seconds; }
            set {
                if (value < 1)
                    value = 1;
                if (value > 3600)
                    value = 3600;
                _interval_seconds = value;
                // Apply a new interval immediately without reconnecting.
                if (running && next_poll_id != 0) {
                    GLib.Source.remove (next_poll_id);
                    next_poll_id = 0;
                    schedule_next (_interval_seconds);
                }
            }
        }

        public bool active {
            get { return running; }
        }

        public CastMetadataPoller () {
            session = new Soup.Session ();
            // The poller enforces its own wall-clock timeout with abort().
            session.timeout = 0;
            session.set_user_agent ("gradio-gtk4");
        }

        public void start (string url) {
            if (url == "")
                return;
            if (running && current_url == url)
                return;
            stop ();
            current_url = url;
            last_title = "";
            failures = 0;
            running = true;
            generation++;
            poll_now ();
        }

        public void stop () {
            running = false;
            generation++;
            if (next_poll_id != 0) {
                GLib.Source.remove (next_poll_id);
                next_poll_id = 0;
            }
            // Aborts an in-flight send/read and closes the connection. Do not
            // close the body stream instead: libsoup's close skips to EOF,
            // which never happens on a live stream.
            session.abort ();
            in_flight = false;
            current_url = "";
            last_title = "";
        }

        private void poll_now () {
            if (!running || in_flight || current_url == "")
                return;
            in_flight = true;
            poll_once.begin (generation);
        }

        private void schedule_next (uint delay) {
            if (!running || next_poll_id != 0)
                return;
            next_poll_id = GLib.Timeout.add_seconds (delay, () => {
                next_poll_id = 0;
                poll_now ();
                return false;
            });
        }

        private async void poll_once (uint poll_generation) {
            bool ok = false;
            bool permanent = false;
            uint timeout_id = 0;
            timeout_id = GLib.Timeout.add_seconds (POLL_TIMEOUT_SECONDS, () => {
                timeout_id = 0;
                // A stale timeout from a stopped/restarted poll must not abort
                // the poll that replaced it.
                if (poll_generation == generation)
                    session.abort ();
                return false;
            });

            try {
                var message = new Soup.Message ("GET", current_url);
                message.get_request_headers ().append ("Icy-MetaData", "1");
                var stream = yield session.send_async (message,
                    GLib.Priority.DEFAULT, null);

                if (poll_generation != generation || !running)
                    return;

                uint status = message.get_status ();
                if (status != Soup.Status.OK) {
                    // A missing/forbidden URL will not fix itself; server
                    // errors and rate limits are worth retrying.
                    permanent = status >= 400 && status < 500 &&
                        status != Soup.Status.REQUEST_TIMEOUT && status != 429;
                    return;
                }

                string? metaint_header = message.get_response_headers ().get_one (
                    "icy-metaint");
                if (metaint_header == null)
                    throw new CastMetadataError.UNSUPPORTED ("no icy-metaint");
                int metaint = 0;
                if (!int.try_parse (metaint_header.strip (), out metaint) ||
                        metaint <= 0 || metaint > MAX_METAINT)
                    throw new CastMetadataError.UNSUPPORTED ("invalid icy-metaint");

                if (!yield read_all (stream, new uint8[metaint]))
                    return;

                var length_byte = new uint8[1];
                if (!yield read_all (stream, length_byte))
                    return;

                int payload_length = length_byte[0] * 16;
                if (payload_length > 0) {
                    var payload = new uint8[payload_length];
                    if (!yield read_all (stream, payload))
                        return;
                    string title = parse_stream_title (payload);
                    if (title != "" && title != last_title) {
                        last_title = title;
                        if (poll_generation == generation && running) {
                            GLib.message ("cast metadata: title %s", title);
                            title_changed (title);
                        }
                    }
                }
                ok = true;
            } catch (CastMetadataError e) {
                if (e.code == CastMetadataError.UNSUPPORTED) {
                    permanent = true;
                    GLib.warning ("cast metadata: %s; ICY titles unavailable for %s",
                        e.message, current_url);
                }
            } catch (GLib.Error e) {
                if (poll_generation != generation || !running)
                    return;
                GLib.warning ("cast metadata poll failed: %s", e.message);
            } finally {
                if (timeout_id != 0)
                    GLib.Source.remove (timeout_id);
                // If this poll was superseded by stop()/start(), the new poll
                // owns the session and in_flight flag.
                if (poll_generation == generation) {
                    session.abort ();
                    in_flight = false;
                    if (running) {
                        if (permanent) {
                            stop ();
                        } else {
                            if (ok)
                                failures = 0;
                            else
                                failures++;
                            schedule_next (ok ? _interval_seconds
                                : backoff_delay ());
                        }
                    }
                }
            }
        }

        private async bool read_all (GLib.InputStream stream, uint8[] buffer)
                throws GLib.Error {
            size_t bytes_read = 0;
            bool complete = yield stream.read_all_async (buffer,
                GLib.Priority.DEFAULT, null, out bytes_read);
            return complete && bytes_read == buffer.length;
        }

        private uint backoff_delay () {
            uint delay = _interval_seconds;
            for (int i = 1; i < failures; i++) {
                if (delay >= 300)
                    break;
                delay *= 2;
            }
            return delay > 300 ? 300 : delay;
        }

        // The metadata block is a sequence of `Key='value';` entries padded
        // with NUL bytes. Only StreamTitle is used.
        public static string parse_stream_title (uint8[] payload) {
            if (payload.length == 0)
                return "";

            var text_builder = new GLib.StringBuilder ();
            for (int i = 0; i < payload.length && payload[i] != 0; i++)
                text_builder.append_c ((char) payload[i]);
            string text = text_builder.str;

            const string marker = "StreamTitle='";
            int marker_pos = text.index_of (marker);
            if (marker_pos < 0)
                return "";
            int start = marker_pos + marker.length;
            int end = text.index_of ("';", start);
            string raw = end >= start
                ? text.substring (start, end - start)
                : text.substring (start);

            if (!raw.validate ()) {
                try {
                    string? converted = GLib.convert (raw, -1, "UTF-8",
                        "ISO-8859-1");
                    if (converted != null)
                        raw = converted;
                } catch (GLib.Error e) {
                }
            }
            return raw.strip ();
        }
    }
}
