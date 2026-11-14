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
        public const string HEARTBEAT_NAMESPACE =
            "urn:x-cast:com.google.cast.tp.heartbeat";
        private const string MEDIA_RECEIVER_APP = "CC1AD845";
        private const int LIVENESS_INTERVAL_SECONDS = 10;
        public const int LIVENESS_TIMEOUT_SECONDS = 30;
        public const int64 LIVENESS_TIMEOUT_US =
            LIVENESS_TIMEOUT_SECONDS * 1000000L;

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
        private static string last_media_title = "";

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

                // Bound the whole handshake, including a stalled TLS connect.
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
                    } catch (GLib.Error e) {
                        fail (dispatch, device_id, e.message, device_connection,
                            generation);
                    }
                });
            });
        }

        public static Elmish.Cmd<Gradio.Message>? probe_cmd (string device_id,
                string host, int port) {
            return new Elmish.Cmd<Gradio.Message> ((dispatch) => {
                // A live cast owns the connection; do not open a second one
                // with the same source id while it is running.
                if (connection != null && started) {
                    dispatch (new CastSessionDetectedMessage (device_id, "", "",
                        "", ""));
                    return;
                }
                var probe = new CastProbe (device_id);
                probe.generation = session_generation;
                probe.connection = new CastConnection ();
                probe.connection.message_received.connect ((json) => {
                    handle_probe_message (dispatch, probe, json);
                });
                probe.connection.closed.connect (() => {
                    finish_probe (dispatch, probe);
                });
                // Bound the whole probe, including the TCP connect. The
                // connection itself also has a short SocketClient timeout.
                probe.timeout_id = GLib.Timeout.add_seconds (8, () => {
                    probe.timeout_id = 0;
                    finish_probe (dispatch, probe);
                    return false;
                });
                var probe_connection = probe.connection;
                probe_connection.connect.begin (host, port, null, (obj, res) => {
                    // The probe may have been finished by the close signal
                    // before this callback ran; probe.connection is null then.
                    if (probe.reported)
                        return;
                    try {
                        if (!probe_connection.connect.end (res)) {
                            finish_probe (dispatch, probe);
                            return;
                        }
                        probe_connection.send_json (CONNECTION_NAMESPACE,
                            "receiver-0", connect_json ());
                        probe_connection.send_json (RECEIVER_NAMESPACE,
                            "receiver-0",
                            "{\"type\":\"GET_STATUS\",\"requestId\":%u}".printf (
                                next_request_id++));
                    } catch (GLib.Error e) {
                        finish_probe (dispatch, probe);
                    }
                });
            });
        }

        public static Elmish.Cmd<Gradio.Message>? adopt_cmd (string device_id,
                string host, int port, string url) {
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
                var state = new CastAdopt (device_id);
                device_connection.message_received.connect ((json) => {
                    if (connection == device_connection &&
                            generation == session_generation)
                        handle_adopt_message (dispatch, state, json,
                            device_connection, generation);
                });
                device_connection.closed.connect (() => {
                    if (connection != device_connection ||
                            generation != session_generation)
                        return;
                    if (!state.reported) {
                        fail_adopt (dispatch, state, device_connection,
                            generation);
                        return;
                    }
                    if (started)
                        cast_lost (dispatch, device_id, _("Device disconnected"),
                            device_connection, generation);
                });
                // Bound the whole handshake, including a stalled TLS connect.
                timeout_id = GLib.Timeout.add_seconds (10, () => {
                    if (!state.reported && connection == device_connection &&
                            generation == session_generation)
                        fail_adopt (dispatch, state, device_connection,
                            generation);
                    return false;
                });
                device_connection.connect.begin (host, port, null, (obj, res) => {
                    if (connection != device_connection ||
                            generation != session_generation)
                        return;
                    try {
                        if (!device_connection.connect.end (res)) {
                            fail_adopt (dispatch, state, device_connection,
                                generation);
                            return;
                        }
                        device_connection.send_json (CONNECTION_NAMESPACE,
                            "receiver-0", connect_json ());
                        device_connection.send_json (RECEIVER_NAMESPACE,
                            "receiver-0",
                            "{\"type\":\"GET_STATUS\",\"requestId\":%u}".printf (
                                next_request_id++));
                    } catch (GLib.Error e) {
                        fail_adopt (dispatch, state, device_connection,
                            generation);
                    }
                });
            });
        }

        public static Elmish.Cmd<Gradio.Message>? media_command_cmd (
                string device_id, string command) {
            return new Elmish.Cmd<Gradio.Message> ((dispatch) => {
                if (connection == null || !started || session_id == "" ||
                        media_session_id <= 0) {
                    dispatch (new CastFailedMessage (
                        _("Cast media session is not ready")));
                    return;
                }
                try {
                    connection.send_json (MEDIA_NAMESPACE, session_id,
                        media_command_json (next_request_id++, command,
                            media_session_id));
                } catch (GLib.Error e) {
                    cast_lost (dispatch, device_id, _("Cast connection lost"),
                        connection, session_generation);
                }
            });
        }

        public static Elmish.Cmd<Gradio.Message>? set_volume_cmd (double level) {
            return new Elmish.Cmd<Gradio.Message> ((dispatch) => {
                if (connection == null)
                    return;
                try {
                    connection.send_json (RECEIVER_NAMESPACE, "receiver-0",
                        set_volume_json (next_request_id++, level));
                } catch (GLib.Error e) {
                }
            });
        }

        public static string set_volume_json (uint request_id, double level) {
            // Format as integer thousandths so the JSON decimal separator does
            // not depend on the process locale.
            int milli = (int) (level.clamp (0.0, 1.0) * 1000.0 + 0.5);
            return ("{\"type\":\"SET_VOLUME\",\"requestId\":%u,"
                + "\"volume\":{\"level\":%d.%03d}}").printf (request_id,
                    milli / 1000, milli % 1000);
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

        // Called from AppRuntime.shutdown. Non-blocking: queues a best-effort
        // STOP and drain. The main loop stops right after shutdown, so delivery
        // is not guaranteed; a graceful-quit follow-up is needed for that.
        public static void shutdown (bool keep_playing) {
            clear_timeout ();
            clear_liveness ();
            session_generation++;
            var current = connection;
            connection = null;
            try {
                if (!keep_playing && current != null && session_id != "") {
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
            var obj = JsonUtil.object_from (json);
            if (obj == null)
                return;
            var type = JsonUtil.string_member (obj, "type");
            if (type == "")
                type = JsonUtil.string_member (obj, "responseType");

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
                report_media_title (dispatch, device_id, json);
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
            if (type == "LOAD_FAILED" || type == "ERROR" ||
                    type == "LAUNCH_ERROR") {
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
                var status = JsonUtil.object_member (obj, "status");
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

        private static void handle_probe_message (
                Elmish.Dispatch<Gradio.Message> dispatch, CastProbe probe,
                string json) {
            if (probe.reported || probe.connection == null)
                return;
            // A cast started or stopped after this probe began: its result is
            // stale and must not replace the session the user just chose.
            if (probe.generation != session_generation) {
                finish_probe (dispatch, probe);
                return;
            }
            var obj = JsonUtil.object_from (json);
            if (obj == null)
                return;
            var type = JsonUtil.string_member (obj, "type");
            if (type == "")
                type = JsonUtil.string_member (obj, "responseType");
            if (type == "PING") {
                try {
                    probe.connection.send_json (HEARTBEAT_NAMESPACE, "receiver-0",
                        "{\"type\":\"PONG\"}");
                } catch (GLib.Error e) {
                }
                return;
            }
            if (type == "RECEIVER_STATUS") {
                var app = media_app_from_json (json);
                if (app == null) {
                    finish_probe (dispatch, probe);
                    return;
                }
                probe.app_name = app.name;
                try {
                    probe.connection.send_json (CONNECTION_NAMESPACE,
                        app.session_id, connect_json ());
                    probe.connection.send_json (MEDIA_NAMESPACE, app.session_id,
                        media_status_json (next_request_id++, 0));
                } catch (GLib.Error e) {
                    finish_probe (dispatch, probe);
                }
                return;
            }
            if (type == "MEDIA_STATUS") {
                var state = media_state_from_json (json);
                if (state == "" || state == "IDLE") {
                    finish_probe (dispatch, probe);
                    return;
                }
                var content_id = media_content_id_from_json (json);
                var title = media_title_from_json (json);
                probe.reported = true;
                clear_probe_timeout (probe);
                var device_id = probe.device_id;
                var app_name = probe.app_name;
                var generation = probe.generation;
                var probe_connection = probe.connection;
                probe.connection = null;
                // Close before the adopter opens its own connection: a second
                // socket with the same source id can make the receiver drop
                // the new one, and the fallback would restart the stream.
                probe_connection.close_async.begin ((obj, res) => {
                    try {
                        probe_connection.close_async.end (res);
                    } catch (GLib.Error e) {
                    }
                    // A cast started or stopped while the socket was closing.
                    if (generation != session_generation)
                        return;
                    dispatch (new CastSessionDetectedMessage (device_id,
                        content_id, state, title, app_name));
                });
                return;
            }
            if (type == "ERROR" || type == "LOAD_FAILED")
                finish_probe (dispatch, probe);
        }

        private static void finish_probe (
                Elmish.Dispatch<Gradio.Message> dispatch, CastProbe probe) {
            if (probe.reported)
                return;
            probe.reported = true;
            clear_probe_timeout (probe);
            var generation = probe.generation;
            var connection = probe.connection;
            probe.connection = null;
            if (connection == null) {
                if (generation == session_generation)
                    dispatch (new CastSessionDetectedMessage (probe.device_id,
                        "", "", "", ""));
                return;
            }
            // Close before dispatching: a new cast opened from the response
            // must not race a second socket with the same source id.
            connection.close_async.begin ((obj, res) => {
                try {
                    connection.close_async.end (res);
                } catch (GLib.Error e) {
                }
                if (generation == session_generation)
                    dispatch (new CastSessionDetectedMessage (probe.device_id,
                        "", "", "", ""));
            });
        }

        private static void clear_probe_timeout (CastProbe probe) {
            if (probe.timeout_id != 0) {
                GLib.Source.remove (probe.timeout_id);
                probe.timeout_id = 0;
            }
        }

        private static void handle_adopt_message (
                Elmish.Dispatch<Gradio.Message> dispatch, CastAdopt state,
                string json, CastConnection session, uint generation) {
            if (connection != session || generation != session_generation)
                return;
            var obj = JsonUtil.object_from (json);
            if (obj == null)
                return;
            var type = JsonUtil.string_member (obj, "type");
            if (type == "")
                type = JsonUtil.string_member (obj, "responseType");
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
                report_media_title (dispatch, state.device_id, json);
                var media_session = media_session_from_json (json);
                if (media_session > 0)
                    media_session_id = media_session;
                if (!started) {
                    var content_id = media_content_id_from_json (json);
                    var player_state = media_state_from_json (json);
                    if (content_id != current_url || player_state == "" ||
                            player_state == "IDLE") {
                        fail_adopt (dispatch, state, session, generation);
                        return;
                    }
                    started = true;
                    load_sent = true;
                    finished = true;
                    clear_timeout ();
                    last_player_state = player_state;
                    state.reported = true;
                    dispatch (new CastAdoptedMessage (state.device_id,
                        player_state));
                    start_liveness_monitor (dispatch, state.device_id, session,
                        generation);
                    return;
                }
                bool started_now;
                var status_message = media_status_message (json, state.device_id,
                    true, ref last_player_state, out started_now);
                if (status_message is CastLostMessage) {
                    var lost = status_message as CastLostMessage;
                    cast_lost (dispatch, state.device_id, lost.error, session,
                        generation);
                    return;
                }
                if (status_message != null)
                    dispatch (status_message);
                arm_liveness_watchdog (dispatch, state.device_id, session,
                    generation);
                return;
            }
            if (type == "LOAD_FAILED" || type == "ERROR" ||
                    type == "LAUNCH_ERROR") {
                if (state.reported && started)
                    cast_lost (dispatch, state.device_id,
                        _("The cast device reported an error"), session,
                        generation);
                else
                    fail_adopt (dispatch, state, session, generation);
                return;
            }
            if (!started && type == "RECEIVER_STATUS") {
                var app = media_app_from_json (json);
                if (app == null) {
                    fail_adopt (dispatch, state, session, generation);
                    return;
                }
                session_id = app.session_id;
                try {
                    session.send_json (CONNECTION_NAMESPACE, app.session_id,
                        connect_json ());
                    session.send_json (MEDIA_NAMESPACE, app.session_id,
                        media_status_json (next_request_id++, 0));
                } catch (GLib.Error e) {
                    fail_adopt (dispatch, state, session, generation);
                }
            }
        }

        private static void fail_adopt (
                Elmish.Dispatch<Gradio.Message> dispatch, CastAdopt state,
                CastConnection session, uint generation) {
            if (state.reported || connection != session ||
                    generation != session_generation)
                return;
            state.reported = true;
            started = false;
            finished = true;
            clear_timeout ();
            clear_liveness ();
            close_current_async ();
            dispatch (new CastAdoptFailedMessage (state.device_id));
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
                            generation != session_generation) {
                        liveness_timeout_id = 0;
                        return false;
                    }
                    try {
                        if (session_id == "")
                            throw new IOError.FAILED ("no media session");
                        session.send_json (MEDIA_NAMESPACE, session_id,
                            media_status_json (next_request_id++,
                                media_session_id));
                    } catch (GLib.Error e) {
                        liveness_timeout_id = 0;
                        cast_lost (dispatch, device_id,
                            _("Cast connection lost"), session, generation);
                        return false;
                    }
                    return true;
                });
        }

        private static void arm_liveness_watchdog (
                Elmish.Dispatch<Gradio.Message> dispatch, string device_id,
                CastConnection session, uint generation) {
            if (liveness_watchdog_id != 0) {
                GLib.Source.remove (liveness_watchdog_id);
                liveness_watchdog_id = 0;
            }
            liveness_watchdog_id = GLib.Timeout.add_seconds (
                LIVENESS_TIMEOUT_SECONDS, () => {
                    liveness_watchdog_id = 0;
                    if (!started || connection != session ||
                            generation != session_generation)
                        return false;
                    // Every MEDIA_STATUS re-arms this timer, so reaching the
                    // callback means no status arrived within the timeout.
                    if (liveness_expired (last_status_us,
                            GLib.get_monotonic_time (), LIVENESS_TIMEOUT_US)) {
                        cast_lost (dispatch, device_id,
                            _("Cast connection lost"), session, generation);
                    }
                    return false;
                });
        }

        // The device is the only source of track metadata while casting; every
        // MEDIA_STATUS (including the liveness polls) may carry a new title.
        // A status without metadata is not a title update: never let it erase
        // the title that is already shown.
        private static void report_media_title (
                Elmish.Dispatch<Gradio.Message> dispatch, string device_id,
                string json) {
            var title = media_title_from_json (json);
            if (title == "" || title == last_media_title)
                return;
            last_media_title = title;
            dispatch (new CastMetadataMessage (device_id, title));
        }

        public static Gradio.Message? media_status_message (string json,
                string device_id, bool started, ref string last_player_state,
                out bool started_now) {
            var state = media_state_from_json (json);
            var transition = player_transition (state, last_player_state);
            // A paused first status still proves the media session exists;
            // otherwise the LOAD timeout would kill a legitimately paused cast.
            started_now = !started &&
                (transition == CastPlayerTransition.STARTED ||
                 transition == CastPlayerTransition.BUFFERING ||
                 transition == CastPlayerTransition.PAUSED);
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
            // An empty status array after a known state means the media session
            // ended on the device (e.g. stopped from a phone) while the
            // receiver app stayed alive.
            if (state == "" && previous_state != "")
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
            last_media_title = "";
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
                if (JsonUtil.string_member (app, "appId") != MEDIA_RECEIVER_APP)
                    continue;
                var id = JsonUtil.string_member (app, "sessionId");
                if (id != "")
                    return id;
            }
            return "";
        }

        public static string receiver_session_id (string json) {
            var obj = JsonUtil.object_from (json);
            if (obj == null)
                return "";
            var status = JsonUtil.object_member (obj, "status");
            if (status == null)
                return "";
            return receiver_session_from_status (status);
        }

        public static string media_player_state (string json) {
            return media_state_from_json (json);
        }

        private static string media_state_from_json (string json) {
            var first = first_media_status_object (json);
            return first != null ? JsonUtil.string_member (first, "playerState") : "";
        }

        private static int media_session_from_json (string json) {
            var first = first_media_status_object (json);
            if (first == null)
                return 0;
            return (int) first.get_int_member_with_default ("mediaSessionId", 0);
        }

        private static Json.Object? first_media_status_object (string json) {
            var obj = JsonUtil.object_from (json);
            if (obj == null)
                return null;
            var status = obj.get_array_member ("status");
            if (status == null || status.get_length () == 0)
                return null;
            var first = status.get_element (0);
            if (first == null || first.get_node_type () != Json.NodeType.OBJECT)
                return null;
            return first.get_object ();
        }

        public static CastReceiverApp? media_app_from_json (string json) {
            var obj = JsonUtil.object_from (json);
            if (obj == null)
                return null;
            var status = JsonUtil.object_member (obj, "status");
            if (status == null)
                return null;
            var apps = status.get_array_member ("applications");
            if (apps == null)
                return null;
            foreach (var node in apps.get_elements ()) {
                var app = node.get_object ();
                if (app == null)
                    continue;
                if (!has_media_namespace (app))
                    continue;
                var session = JsonUtil.string_member (app, "sessionId");
                if (session == "")
                    continue;
                return new CastReceiverApp (session,
                    JsonUtil.string_member (app, "displayName"));
            }
            return null;
        }

        private static bool has_media_namespace (Json.Object app) {
            var namespaces = app.get_array_member ("namespaces");
            if (namespaces == null)
                return false;
            foreach (var node in namespaces.get_elements ()) {
                if (node.get_value_type () == typeof (string)) {
                    if (node.get_string () == MEDIA_NAMESPACE)
                        return true;
                    continue;
                }
                if (node.get_value_type () != typeof (Json.Object))
                    continue;
                var entry = node.get_object ();
                if (entry != null &&
                        JsonUtil.string_member (entry, "name") == MEDIA_NAMESPACE)
                    return true;
            }
            return false;
        }

        public static string media_content_id_from_json (string json) {
            var media = first_media_object (json);
            return media != null ? JsonUtil.string_member (media, "contentId") : "";
        }

        public static string media_title_from_json (string json) {
            var media = first_media_object (json);
            if (media == null)
                return "";
            var metadata = JsonUtil.object_member (media, "metadata");
            if (metadata == null)
                return "";
            return JsonUtil.string_member (metadata, "title");
        }

        private static Json.Object? first_media_object (string json) {
            var first = first_media_status_object (json);
            if (first == null)
                return null;
            return JsonUtil.object_member (first, "media");
        }

        public static bool is_http_url (string url) {
            return url.has_prefix ("http://") || url.has_prefix ("https://");
        }

        public static string media_command_json (uint request_id, string command,
                int media_session_id) {
            return ("{\"type\":\"%s\",\"requestId\":%u,\"mediaSessionId\":%d}").printf (
                command, request_id, media_session_id);
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
            var obj = JsonUtil.object_from (json_text);
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
                    JsonUtil.string_member (dev, "id"),
                    JsonUtil.string_member (dev, "name"),
                    JsonUtil.string_member (dev, "host"),
                    (int) dev.get_int_member_with_default ("port", 0),
                    JsonUtil.string_member (dev, "model"));
            }
            return devices;
        }
    }

    private class DiscoveryResult : GLib.Object {
        public CastDevice[] devices = {};
        public string error = "";
    }

    public class CastReceiverApp {
        public string session_id;
        public string name;

        public CastReceiverApp (string session_id, string name) {
            this.session_id = session_id;
            this.name = name;
        }
    }

    private class CastProbe : GLib.Object {
        public string device_id;
        public CastConnection connection;
        public string app_name = "";
        public bool reported = false;
        public uint timeout_id = 0;
        public uint generation = 0;

        public CastProbe (string device_id) {
            this.device_id = device_id;
        }
    }

    private class CastAdopt : GLib.Object {
        public string device_id;
        public bool reported = false;

        public CastAdopt (string device_id) {
            this.device_id = device_id;
        }
    }
}