// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {
    public class CastService : GLib.Object {
        private const string CONNECTION_NAMESPACE = "urn:x-cast:com.google.cast.tp.connection";
        private const string RECEIVER_NAMESPACE = "urn:x-cast:com.google.cast.receiver";
        private const string MEDIA_NAMESPACE = "urn:x-cast:com.google.cast.media";
        private const string HEARTBEAT_NAMESPACE = "urn:x-cast:com.google.cast.heartbeat";
        private const string MEDIA_RECEIVER_APP = "CC1AD845";

        private static CastConnection? connection = null;
        private static string session_id = "";
        private static int media_session_id = 0;
        private static uint next_request_id = 1;
        private static uint timeout_id = 0;
        private static bool load_sent = false;
        private static bool finished = false;

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
                finished = true;
                close_current ();
                reset_state ();
                finished = false;
                current_url = url;
                current_content_type = content_type_for (url);
                var device_connection = new CastConnection ();
                connection = device_connection;

                device_connection.message_received.connect ((json) => {
                    if (connection == device_connection)
                        handle_message (dispatch, device_id, json);
                });
                device_connection.closed.connect (() => {
                    if (connection != device_connection || finished)
                        return;
                    finished = true;
                    clear_timeout ();
                    dispatch (new CastFailedMessage (_("Device disconnected")));
                });

                device_connection.connect.begin (host, port, (obj, res) => {
                    try {
                        if (!device_connection.connect.end (res)) {
                            fail (dispatch, device_id, _("Could not connect"));
                            return;
                        }
                        var request_id = next_request_id++;
                        device_connection.send_json (CONNECTION_NAMESPACE, "receiver-0",
                            "{\"type\":\"CONNECT\",\"origin\":{},\"userAgent\":\"Gradio/1.0\"}");
                        device_connection.send_json (RECEIVER_NAMESPACE, "receiver-0",
                            launch_json (request_id));
                        timeout_id = GLib.Timeout.add_seconds (25, () => {
                            if (!finished) {
                                finished = true;
                                clear_timeout ();
                                close_current ();
                                dispatch (new CastFailedMessage (_("Cast timed out")));
                            }
                            return false;
                        });
                    } catch (GLib.Error e) {
                        fail (dispatch, device_id, e.message);
                    }
                });
            });
        }

        public static Elmish.Cmd<Gradio.Message>? stop_cmd (string device_id, string host,
                int port) {
            return new Elmish.Cmd<Gradio.Message> ((dispatch) => {
                try {
                    if (connection != null) {
                        if (session_id != "") {
                            if (media_session_id > 0)
                                connection.send_json (MEDIA_NAMESPACE, session_id,
                                    media_stop_json (next_request_id++, session_id,
                                        media_session_id));
                            else
                                connection.send_json (RECEIVER_NAMESPACE, "receiver-0",
                                    receiver_stop_json (next_request_id++, session_id));
                        }
                    }
                } catch (GLib.Error e) {
                }
                finished = true;
                close_current ();
                reset_state ();
                dispatch (new CastStoppedMessage ());
            });
        }

        private static void handle_message (Elmish.Dispatch<Gradio.Message> dispatch,
                string device_id, string json) {
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
                    if (connection != null)
                        connection.send_json (HEARTBEAT_NAMESPACE, "receiver-0",
                            "{\"type\":\"PONG\"}");
                } catch (GLib.Error e) {
                }
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
                        connection.send_json (CONNECTION_NAMESPACE, app_session,
                            connect_json ());
                        connection.send_json (MEDIA_NAMESPACE, app_session,
                            load_json (next_request_id++, app_session, current_url,
                                current_content_type));
                    } catch (GLib.Error e) {
                        fail (dispatch, device_id, e.message);
                    }
                }
                return;
            }
            if (type == "MEDIA_STATUS") {
                var state = media_state_from_json (json);
                var media_session = media_session_from_json (json);
                if (media_session > 0)
                    media_session_id = media_session;
                if (state == "PLAYING" || state == "BUFFERING") {
                    finished = true;
                    clear_timeout ();
                    dispatch (new CastStartedMessage (device_id));
                }
                return;
            }
            if (type == "LOAD_FAILED" || type == "ERROR") {
                fail (dispatch, device_id, _("The cast device rejected the stream"));
            }
        }

        private static void fail (Elmish.Dispatch<Gradio.Message> dispatch,
                string device_id, string message) {
            if (finished)
                return;
            finished = true;
            clear_timeout ();
            close_current ();
            dispatch (new CastFailedMessage (message));
        }

        private static void clear_timeout () {
            if (timeout_id != 0) {
                GLib.Source.remove (timeout_id);
                timeout_id = 0;
            }
        }

        private static void close_current () {
            if (connection != null) {
                connection.close ();
                connection = null;
            }
        }

        private static void reset_state () {
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
            return text.replace ("\\", "\\\\").replace ("\"", "\\\"");
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