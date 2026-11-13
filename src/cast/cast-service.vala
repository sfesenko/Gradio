// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {
    public enum CastPlayerTransition {
        NONE,
        STARTED,
        BUFFERING,
        PAUSED,
        LOST
    }

    public class CastService : GLib.Object {
        private const string CONNECTION_NAMESPACE = "urn:x-cast:com.google.cast.tp.connection";
        private const string RECEIVER_NAMESPACE = "urn:x-cast:com.google.cast.receiver";
        private const string MEDIA_NAMESPACE = "urn:x-cast:com.google.cast.media";
        private const string HEARTBEAT_NAMESPACE = "urn:x-cast:com.google.cast.heartbeat";
        private const string MEDIA_RECEIVER_APP = "CC1AD845";
        private const int LIVENESS_INTERVAL_SECONDS = 10;
        public const int LIVENESS_TIMEOUT_SECONDS = 30;
        public const int64 LIVENESS_TIMEOUT_US = 30000000L;

        private static CastConnection? connection = null;
        private static string session_id = "";
        private static int media_session_id = 0;
        private static uint next_request_id = 1;
        private static uint timeout_id = 0;
        private static uint liveness_timeout_id = 0;
        private static uint liveness_watchdog_id = 0;
        private static int64 last_status_us = 0;
        private static uint session_generation = 0;
        private static bool load_sent = false;
        private static bool finished = false;
        private static bool started = false;
        private static string last_player_state = "";

        public static Elmish.Cmd<Gradio.Message>? discover_cmd () {
            return new Elmish.Cmd<Gradio.Message> ((dispatch) => {
                new Thread<bool> ("cast-discover", () => {
                    var result = new DiscoveryResult ();
                    try {
                        var found = Mdns.browse (5);
                        for (uint i = 0; i < found.length; i++)
                            result.devices += found.get (i);
                    } catch (GLib.Error e) {
                        result.error = e.message;
                    }
                    GLib.Idle.add (() => {
                        if (result.error != "")
                            dispatch (new CastDiscoveryFailedMessage (result.error));
                        else
                            dispatch (new CastDevicesDiscoveredMessage (result.devices));
                        return false;
                    });
                    return true;
                });
            });
        }

        public static Elmish.Cmd<Gradio.Message>? cast_cmd (string device_id, string host,
                int port, string url) {
            return new Elmish.Cmd<Gradio.Message> ((dispatch) => {
                clear_timeout ();
                clear_liveness ();
                session_generation++;
                var generation = session_generation;
                finished = true;
                close_current_async ();
                reset_state ();
                finished = false;
                current_url = url;
                current_content_type = content_type_for (url);
                var device_connection = new CastConnection ();
                connection = device_connection;

                device_connection.message_received.connect ((json) => {
                    if (connection == device_connection && generation == session_generation)
                        handle_message (dispatch, device_id, json, device_connection,
                            generation);
                });
                device_connection.closed.connect (() => {
                    if (connection != device_connection || generation != session_generation)
                        return;
                    if (started) {
                        cast_lost (dispatch, device_id, _("Device disconnected"),
                            device_connection, generation);
                        return;
                    }
                    if (finished)
                        return;
                    finished = true;
                    clear_timeout ();
                    dispatch (new CastFailedMessage (_("Device disconnected")));
                });

                device_connection.connect.begin (host, port, null, (obj, res) => {
                    if (connection != device_connection || generation != session_generation)
                        return;
                    try {
                        if (!device_connection.connect.end (res)) {
                            fail (dispatch, device_id, _("Could not connect"),
                                device_connection, generation);
                            return;
                        }
                        var request_id = next_request_id++;
                        device_connection.send_json (CONNECTION_NAMESPACE, "receiver-0",
                            "{\"type\":\"CONNECT\",\"origin\":{},\"userAgent\":\"Gradio/1.0\"}");
                        device_connection.send_json (RECEIVER_NAMESPACE, "receiver-0",
                            launch_json (request_id));
                        timeout_id = GLib.Timeout.add_seconds (25, () => {
                            if (generation == session_generation &&
                                    connection == device_connection && !finished) {
                                finished = true;
                                clear_timeout ();
                                close_current_async ();
                                dispatch (new CastFailedMessage (_("Cast timed out")));
                            }
                            return false;
                        });
                    } catch (GLib.Error e) {
                        fail (dispatch, device_id, e.message, device_connection,
                            generation);
                    }
                });
            });
        }

        public static Elmish.Cmd<Gradio.Message>? stop_cmd (string device_id, string host,
                int port) {
            return new Elmish.Cmd<Gradio.Message> ((dispatch) => {
                clear_timeout ();
                clear_liveness ();
                session_generation++;
                var current = connection;
                connection = null;
                try {
                    if (current != null) {
                        if (session_id != "") {
                            if (media_session_id > 0)
                                current.send_json (MEDIA_NAMESPACE, session_id,
                                    media_stop_json (next_request_id++, session_id,
                                        media_session_id));
                            else
                                current.send_json (RECEIVER_NAMESPACE, "receiver-0",
                                    receiver_stop_json (next_request_id++, session_id));
                        }
                        current.close_after_drain ();
                    }
                } catch (GLib.Error e) {
                    if (current != null)
                        current.close_async.begin ();
                }
                finished = true;
                reset_state ();
                dispatch (new CastStoppedMessage ());
            });
        }

        // Called from AppRuntime.shutdown. Non-blocking: queues STOP and lets
        // the connection drain before the process exits.
        public static void shutdown () {
            clear_timeout ();
            clear_liveness ();
            session_generation++;
            var current = connection;
            connection = null;
            try {
                if (current != null && session_id != "") {
                    if (media_session_id > 0)
                        current.send_json (MEDIA_NAMESPACE, session_id,
                            media_stop_json (next_request_id++, session_id,
                                media_session_id));
                    else
                        current.send_json (RECEIVER_NAMESPACE, "receiver-0",
                            receiver_stop_json (next_request_id++, session_id));
                }
                if (current != null)
                    current.close_after_drain ();
            } catch (GLib.Error e) {
                if (current != null)
                    current.close_async.begin ();
            }
            finished = true;
            reset_state ();
        }

        private static void handle_message (Elmish.Dispatch<Gradio.Message> dispatch,
                string device_id, string json, CastConnection session,
                uint generation) {
            if (connection != session || generation != session_generation)
                return;
            var parser = new Json.Parser ();
            try {
                parser.load_from_data (json, -1);
            } catch (GLib.Error e) {
                return;
            }
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT)
                return;
            var obj = root.get_object ();
            if (obj == null)
                return;
            var type = string_member (obj, "type");
            if (type == "")
                type = string_member (obj, "responseType");

            if (type == "PING") {
                try {
                    session.send_json (HEARTBEAT_NAMESPACE, "receiver-0",
                        "{\"type\":\"PONG\"}");
                } catch (GLib.Error e) {
                }
                return;
            }
            if (type == "MEDIA_STATUS") {
                last_status_us = GLib.get_monotonic_time ();
                var media_session = media_session_from_json (json);
                if (media_session > 0)
                    media_session_id = media_session;
                bool started_now;
                var status_message = media_status_message (json, device_id,
                    started, ref last_player_state, out started_now);
                if (started_now) {
                    started = true;
                    finished = true;
                    clear_timeout ();
                    if (status_message != null)
                        dispatch (status_message);
                    start_liveness_monitor (dispatch, device_id, session,
                        generation);
                    return;
                }
                if (status_message is CastLostMessage) {
                    var lost = status_message as CastLostMessage;
                    cast_lost (dispatch, device_id, lost.error, session,
                        generation);
                    return;
                }
                if (status_message != null)
                    dispatch (status_message);
                if (started)
                    arm_liveness_watchdog (dispatch, device_id, session,
                        generation);
                return;
            }
            if (type == "LOAD_FAILED" || type == "ERROR") {
                if (started)
                    cast_lost (dispatch, device_id,
                        _("The cast device rejected the stream"), session,
                        generation);
                else
                    fail (dispatch, device_id,
                        _("The cast device rejected the stream"), session,
                        generation);
                return;
            }
            if (finished)
                return;
            if (type == "RECEIVER_STATUS") {
                var status = obj.get_object_member ("status");
                if (status == null)
                    return;
                var app_session = receiver_session_from_status (status);
                if (app_session != "" && !load_sent) {
                    session_id = app_session;
                    load_sent = true;
                    try {
                        session.send_json (CONNECTION_NAMESPACE, app_session,
                            connect_json ());
                        session.send_json (MEDIA_NAMESPACE, app_session,
                            load_json (next_request_id++, app_session, current_url,
                                current_content_type));
                    } catch (GLib.Error e) {
                        fail (dispatch, device_id, e.message, session, generation);
                    }
                }
                return;
            }
        }

        private static void fail (Elmish.Dispatch<Gradio.Message> dispatch,
                string device_id, string message, CastConnection session,
                uint generation) {
            if (finished || connection != session || generation != session_generation)
                return;
            finished = true;
            clear_timeout ();
            close_current_async ();
            dispatch (new CastFailedMessage (message));
        }

        private static void cast_lost (Elmish.Dispatch<Gradio.Message> dispatch,
                string device_id, string message, CastConnection session,
                uint generation) {
            if (!should_report_lost (started, connection == session, generation,
                    session_generation))
                return;
            started = false;
            finished = true;
            clear_timeout ();
            clear_liveness ();
            close_current_async ();
            dispatch (new CastLostMessage (device_id, message));
        }

        private static void start_liveness_monitor (
                Elmish.Dispatch<Gradio.Message> dispatch, string device_id,
                CastConnection session, uint generation) {
            clear_liveness ();
            last_status_us = GLib.get_monotonic_time ();
            arm_liveness_watchdog (dispatch, device_id, session, generation);
            liveness_timeout_id = GLib.Timeout.add_seconds (
                LIVENESS_INTERVAL_SECONDS, () => {
                    if (!started || connection != session ||
                            generation != session_generation)
                        return false;
                    try {
                        if (session_id == "")
                            throw new IOError.FAILED ("no media session");
                        session.send_json (MEDIA_NAMESPACE, session_id,
                            media_status_json (next_request_id++,
                                media_session_id));
                    } catch (GLib.Error e) {
                        cast_lost (dispatch, device_id,
                            _("Cast connection lost"), session, generation);
                        return false;
                    }
                    return true;
                });
        }

        private static void arm_liveness_watchdog (
                Elmish.Dispatch<Gradio.Message> dispatch, string device_id,
                CastConnection session, uint generation,
                uint delay_seconds = LIVENESS_TIMEOUT_SECONDS) {
            if (liveness_watchdog_id != 0) {
                GLib.Source.remove (liveness_watchdog_id);
                liveness_watchdog_id = 0;
            }
            liveness_watchdog_id = GLib.Timeout.add_seconds (delay_seconds, () => {
                liveness_watchdog_id = 0;
                if (!started || connection != session ||
                        generation != session_generation)
                    return false;
                if (liveness_expired (last_status_us,
                        GLib.get_monotonic_time (), LIVENESS_TIMEOUT_US)) {
                    cast_lost (dispatch, device_id,
                        _("Cast connection lost"), session, generation);
                    return false;
                }
                arm_liveness_watchdog (dispatch, device_id, session,
                    generation, 1);
                return false;
            });
        }

        public static Gradio.Message? media_status_message (string json,
                string device_id, bool started, ref string last_player_state,
                out bool started_now) {
            var state = media_state_from_json (json);
            var transition = player_transition (state, last_player_state);
            started_now = !started &&
                (transition == CastPlayerTransition.STARTED ||
                 transition == CastPlayerTransition.BUFFERING);
            if (!started && !started_now)
                return null;
            if (transition == CastPlayerTransition.LOST)
                return new CastLostMessage (device_id,
                    _("Cast playback stopped"));
            if (transition == CastPlayerTransition.NONE)
                return null;
            last_player_state = state;
            if (transition == CastPlayerTransition.PAUSED)
                return new CastPausedMessage (device_id);
            if (transition == CastPlayerTransition.BUFFERING)
                return new CastBufferingMessage (device_id);
            return new CastStartedMessage (device_id);
        }

        public static CastPlayerTransition player_transition (string state,
                string previous_state) {
            if (state == "IDLE")
                return CastPlayerTransition.LOST;
            if (state == previous_state)
                return CastPlayerTransition.NONE;
            if (state == "PAUSED")
                return CastPlayerTransition.PAUSED;
            if (state == "BUFFERING")
                return CastPlayerTransition.BUFFERING;
            if (state == "PLAYING")
                return CastPlayerTransition.STARTED;
            return CastPlayerTransition.NONE;
        }

        public static bool should_report_lost (bool started, bool same_session,
                uint generation, uint current_generation) {
            return started && same_session && generation == current_generation;
        }

        public static bool liveness_expired (int64 last_us, int64 now_us,
                int64 timeout_us) {
            return now_us - last_us >= timeout_us;
        }

        private static void clear_liveness () {
            if (liveness_timeout_id != 0) {
                GLib.Source.remove (liveness_timeout_id);
                liveness_timeout_id = 0;
            }
            if (liveness_watchdog_id != 0) {
                GLib.Source.remove (liveness_watchdog_id);
                liveness_watchdog_id = 0;
            }
        }

        private static void clear_timeout () {
            if (timeout_id != 0) {
                GLib.Source.remove (timeout_id);
                timeout_id = 0;
            }
        }

        private static void close_current_async () {
            if (connection != null) {
                var old = connection;
                connection = null;
                old.close_async.begin ((obj, res) => {
                    old.close_async.end (res);
                });
            }
        }

        private static void reset_state () {
            clear_liveness ();
            started = false;
            last_player_state = "";
            last_status_us = 0;
            session_id = "";
            media_session_id = 0;
            load_sent = false;
            current_url = "";
            current_content_type = "";
        }

        private static string current_url = "";
        private static string current_content_type = "";

        private static string receiver_session_from_status (Json.Object status) {
            var apps = status.get_array_member ("applications");
            if (apps == null)
                return "";
            foreach (var node in apps.get_elements ()) {
                var app = node.get_object ();
                if (app == null)
                    continue;
                if (string_member (app, "appId") != MEDIA_RECEIVER_APP)
                    continue;
                var id = string_member (app, "sessionId");
                if (id != "")
                    return id;
            }
            return "";
        }

        public static string receiver_session_id (string json) {
            var parser = new Json.Parser ();
            try {
                parser.load_from_data (json, -1);
            } catch (GLib.Error e) {
                return "";
            }
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT)
                return "";
            var obj = root.get_object ();
            if (obj == null)
                return "";
            var status = obj.get_object_member ("status");
            if (status == null)
                return "";
            return receiver_session_from_status (status);
        }

        public static string media_player_state (string json) {
            return media_state_from_json (json);
        }

        private static string media_state_from_json (string json) {
            var parser = new Json.Parser ();
            try {
                parser.load_from_data (json, -1);
            } catch (GLib.Error e) {
                return "";
            }
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT)
                return "";
            var obj = root.get_object ();
            if (obj == null)
                return "";
            var status = obj.get_array_member ("status");
            if (status == null || status.get_length () == 0)
                return "";
            var first = status.get_element (0);
            if (first == null || first.get_node_type () != Json.NodeType.OBJECT)
                return "";
            return string_member (first.get_object (), "playerState");
        }

        private static int media_session_from_json (string json) {
            var parser = new Json.Parser ();
            try {
                parser.load_from_data (json, -1);
            } catch (GLib.Error e) {
                return 0;
            }
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT)
                return 0;
            var obj = root.get_object ();
            if (obj == null)
                return 0;
            var status = obj.get_array_member ("status");
            if (status == null || status.get_length () == 0)
                return 0;
            var first = status.get_element (0);
            if (first == null || first.get_node_type () != Json.NodeType.OBJECT)
                return 0;
            return (int) first.get_object ().get_int_member_with_default (
                "mediaSessionId", 0);
        }

        public static string connect_json () {
            return "{\"type\":\"CONNECT\",\"origin\":{},\"userAgent\":\"Gradio/1.0\"}";
        }

        public static string launch_json (uint request_id) {
            return "{\"type\":\"LAUNCH\",\"appId\":\"%s\",\"requestId\":%u}".printf (
                MEDIA_RECEIVER_APP, request_id);
        }

        public static string load_json (uint request_id, string session, string url,
                string content_type) {
            return ("{\"type\":\"LOAD\",\"requestId\":%u,\"sessionId\":\"%s\","
                + "\"media\":{\"contentId\":\"%s\",\"contentType\":\"%s\","
                + "\"streamType\":\"LIVE\"},\"autoplay\":true,\"currentTime\":0}").printf (
                    request_id, json_escape (session), json_escape (url),
                    json_escape (content_type));
        }

        public static string media_status_json (uint request_id,
                int media_session_id) {
            if (media_session_id > 0)
                return ("{\"type\":\"GET_STATUS\",\"requestId\":%u,"
                    + "\"mediaSessionId\":%d}").printf (request_id,
                        media_session_id);
            return "{\"type\":\"GET_STATUS\",\"requestId\":%u}".printf (
                request_id);
        }

        public static string media_stop_json (uint request_id, string session,
                int media_session) {
            return ("{\"type\":\"STOP\",\"requestId\":%u,\"sessionId\":\"%s\","
                + "\"mediaSessionId\":%d}").printf (request_id, json_escape (session),
                    media_session);
        }

        public static string receiver_stop_json (uint request_id, string session) {
            return "{\"type\":\"STOP\",\"requestId\":%u,\"sessionId\":\"%s\"}".printf (
                request_id, json_escape (session));
        }

        private static string json_escape (string text) {
            return text.replace ("\\", "\\\\").replace ("\"", "\\\"")
                .replace ("\n", "\\n").replace ("\r", "\\r").replace ("\t", "\\t");
        }

        public static string content_type_for (string url) {
            if (url.has_suffix (".m3u8") || url.has_suffix (".m3u"))
                return "application/vnd.apple.mpegurl";
            if (url.has_suffix (".aac"))
                return "audio/aac";
            return "audio/mpeg";
        }

        public static CastDevice[] parse_devices (string json_text) {
            if (json_text == "")
                return {};
            Json.Parser parser = new Json.Parser ();
            try {
                parser.load_from_data (json_text, -1);
            } catch (GLib.Error e) {
                return null;
            }
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT)
                return null;
            var obj = root.get_object ();
            if (obj == null)
                return null;
            var list = obj.get_array_member ("devices");
            if (list == null)
                return null;
            var devices = new CastDevice[] {};
            foreach (var node in list.get_elements ()) {
                var dev = node.get_object ();
                if (dev == null)
                    continue;
                devices += new CastDevice (
                    string_member (dev, "id"),
                    string_member (dev, "name"),
                    string_member (dev, "host"),
                    (int) dev.get_int_member_with_default ("port", 0),
                    string_member (dev, "model"));
            }
            return devices;
        }

        private static string string_member (Json.Object obj, string name) {
            return obj.has_member (name) ? obj.get_string_member (name) : "";
        }
    }

    private class DiscoveryResult : GLib.Object {
        public CastDevice[] devices = {};
        public string error = "";
    }
}