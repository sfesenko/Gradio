// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

void test_content_type_default () {
    assert (CastService.content_type_for ("https://example.test/stream") == "audio/mpeg");
}

void test_content_type_m3u8 () {
    assert (CastService.content_type_for ("https://example.test/stream.m3u8") ==
        "application/vnd.apple.mpegurl");
}

void test_content_type_aac () {
    assert (CastService.content_type_for ("https://example.test/stream.aac") == "audio/aac");
}

void test_parse_devices_valid () {
    var json = "{\"devices\":[{\"id\":\"id-1\",\"name\":\"Kitchen\",\"host\":\"127.0.0.1\",\"port\":8009,\"model\":\"Google Home\"}]}";
    var devices = CastService.parse_devices (json);
    assert (devices != null);
    assert (devices.length == 1);
    assert (devices[0].id == "id-1");
    assert (devices[0].name == "Kitchen");
    assert (devices[0].port == 8009);
}

void test_parse_devices_invalid () {
    assert (CastService.parse_devices ("not json") == null);
}

void test_parse_devices_empty () {
    var devices = CastService.parse_devices ("{\"devices\":[]}");
    assert (devices != null);
    assert (devices.length == 0);
}

void test_load_json_escapes_control_characters () {
    var parser = new Json.Parser ();
    parser.load_from_data (CastService.load_json (10, "session-1",
        "https://example.test/a\nb", "audio/mpeg"));
    var obj = parser.get_root ().get_object ();
    var media = obj.get_object_member ("media");
    assert (media.get_string_member ("contentId") == "https://example.test/a\nb");
}

void test_stop_cast_dispatches_stopped () {
    Gradio.Message? last = null;
    var cmd = CastService.stop_cmd ("id-1", "127.0.0.1", 8009);
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => { last = msg; }, cmd);
    assert (last is CastStoppedMessage);
    var stopped = last as CastStoppedMessage;
    assert (stopped != null);
    assert (stopped.device_id == "id-1");
}

void test_heartbeat_tick () {
    int64 now = 100000000;
    int64 step = 1000000;
    bool lost;
    // A recent frame is liveness: no miss, no loss, even with missed ticks.
    assert (CastService.heartbeat_tick (now, now, 5, out lost) == 0);
    assert (!lost);
    assert (CastService.heartbeat_tick (now, now, 0, out lost) == 0);
    assert (!lost);
    // First quiet tick raises the count but does not lose the sender.
    int64 quiet = now - CastService.HEARTBEAT_TIMEOUT_SECONDS * step;
    assert (CastService.heartbeat_tick (quiet, now, 0, out lost) == 1);
    assert (!lost);
    // The second quiet tick passes the threshold.
    assert (CastService.heartbeat_tick (quiet, now, 1, out lost) == 2);
    assert (lost);
}

void test_close_after_drain_emits_closed_once () {
    var connection = new CastConnection ();
    int closed_count = 0;
    string closed_reason = "";
    connection.closed.connect ((reason) => {
        closed_count++;
        closed_reason = reason;
    });
    connection.close_after_drain ();
    connection.close_after_drain ();
    var context = GLib.MainContext.@default ();
    var deadline = GLib.get_monotonic_time () + 2 * 1000000;
    while (closed_count == 0 && GLib.get_monotonic_time () < deadline)
        context.iteration (true);
    assert (closed_count == 1);
    assert (closed_reason == "drain");
    // A later close must not emit again.
    connection.close_async.begin ("late");
    for (int i = 0; i < 20 && context.pending (); i++)
        context.iteration (false);
    assert (closed_count == 1);
    assert (closed_reason == "drain");
}


void test_media_status_json () {
    var parser = new Json.Parser ();
    parser.load_from_data (CastService.media_status_json (12, 3));
    var obj = parser.get_root ().get_object ();
    assert (obj.get_string_member ("type") == "GET_STATUS");
    assert (obj.get_int_member ("requestId") == 12);
    assert (obj.get_int_member ("mediaSessionId") == 3);
}

void test_media_status_json_without_session () {
    var parser = new Json.Parser ();
    parser.load_from_data (CastService.media_status_json (1, 0));
    var obj = parser.get_root ().get_object ();
    assert (!obj.has_member ("mediaSessionId"));
}

void test_player_transition_buffering_does_not_start () {
    assert (CastService.player_transition ("BUFFERING", "") ==
        CastPlayerTransition.BUFFERING);
    assert (CastService.player_transition ("BUFFERING", "PLAYING") ==
        CastPlayerTransition.BUFFERING);
}

void test_player_transition_resumes_from_buffering () {
    assert (CastService.player_transition ("PLAYING", "BUFFERING") ==
        CastPlayerTransition.STARTED);
}

void test_should_report_lost () {
    assert (CastService.should_report_lost (true, true, 4, 4));
    assert (!CastService.should_report_lost (false, true, 4, 4));
    assert (!CastService.should_report_lost (true, false, 4, 4));
    assert (!CastService.should_report_lost (true, true, 3, 4));
}

void test_close_action_active_session_is_sender_loss () {
    // A live media session survives its sender socket: re-attach.
    assert (CastService.close_action (true, false) ==
        CastCloseAction.SENDER_LOST);
}

void test_close_action_adopted_session_is_sender_loss () {
    // An adopted session is already resolved (attempt_ended), but the receiver
    // may still be playing: a CLOSE is still a dropped sender.
    assert (CastService.close_action (true, true) ==
        CastCloseAction.SENDER_LOST);
}

void test_close_action_before_start_fails_attempt () {
    // Initial cast and adoption: no media session is known yet, so the attempt
    // produced nothing to re-attach to.
    assert (CastService.close_action (false, false) ==
        CastCloseAction.ATTEMPT_FAILED);
}

void test_close_action_ignores_finished_attempt () {
    // The socket may deliver CLOSE after the attempt already reported a
    // failure: it must not be reported twice.
    assert (CastService.close_action (false, true) ==
        CastCloseAction.IGNORE);
}

void test_player_transition_playing_starts () {
    assert (CastService.player_transition ("PLAYING", "") ==
        CastPlayerTransition.STARTED);
}

void test_player_transition_idle_is_lost () {
    assert (CastService.player_transition ("IDLE", "PLAYING") ==
        CastPlayerTransition.LOST);
}

void test_player_transition_empty_status_is_lost () {
    // Stopped from a phone: the media app stays alive with status: [].
    assert (CastService.player_transition ("", "PLAYING") ==
        CastPlayerTransition.LOST);
    // Nothing was playing yet: an empty status is not a loss.
    assert (CastService.player_transition ("", "") ==
        CastPlayerTransition.NONE);
}

void test_player_transition_paused () {
    assert (CastService.player_transition ("PAUSED", "PLAYING") ==
        CastPlayerTransition.PAUSED);
}

void test_player_transition_resumes () {
    assert (CastService.player_transition ("PLAYING", "PAUSED") ==
        CastPlayerTransition.STARTED);
}

void test_player_transition_same_state_is_none () {
    assert (CastService.player_transition ("PLAYING", "PLAYING") ==
        CastPlayerTransition.NONE);
}

void test_liveness_expired_boundary () {
    assert (!CastService.liveness_expired (0, 29 * 1000000L,
        CastService.LIVENESS_TIMEOUT_US));
    assert (CastService.liveness_expired (0, 30 * 1000000L,
        CastService.LIVENESS_TIMEOUT_US));
    assert (CastService.liveness_expired (0, 31 * 1000000L,
        CastService.LIVENESS_TIMEOUT_US));
}

string media_json (string state) {
    return ("{\"type\":\"MEDIA_STATUS\",\"status\":[{\"playerState\":\"%s\"}]}").printf (
        state);
}

void test_media_status_message_initial_playing () {
    string last = "";
    bool started_now;
    var msg = CastService.media_status_message (media_json ("PLAYING"), "id-1",
        false, ref last, out started_now);
    assert (started_now);
    assert (msg is CastStartedMessage);
    assert (last == "PLAYING");
}

void test_media_status_message_initial_buffering () {
    string last = "";
    bool started_now;
    var msg = CastService.media_status_message (media_json ("BUFFERING"), "id-1",
        false, ref last, out started_now);
    assert (started_now);
    assert (msg is CastBufferingMessage);
    assert (last == "BUFFERING");
}

void test_media_status_message_idle_is_lost () {
    string last = "PLAYING";
    bool started_now;
    var msg = CastService.media_status_message (media_json ("IDLE"), "id-1",
        true, ref last, out started_now);
    assert (!started_now);
    assert (msg is CastLostMessage);
}

void test_media_status_message_initial_paused () {
    string last = "";
    bool started_now;
    var msg = CastService.media_status_message (media_json ("PAUSED"), "id-1",
        false, ref last, out started_now);
    assert (started_now);
    assert (msg is CastPausedMessage);
    assert (last == "PAUSED");
}

void test_heartbeat_namespace () {
    assert (CastService.HEARTBEAT_NAMESPACE ==
        "urn:x-cast:com.google.cast.tp.heartbeat");
}

void test_media_status_message_paused () {
    string last = "PLAYING";
    bool started_now;
    var msg = CastService.media_status_message (media_json ("PAUSED"), "id-1",
        true, ref last, out started_now);
    assert (!started_now);
    assert (msg is CastPausedMessage);
    assert (last == "PAUSED");
}

void test_media_status_message_resumes () {
    string last = "PAUSED";
    bool started_now;
    var msg = CastService.media_status_message (media_json ("PLAYING"), "id-1",
        true, ref last, out started_now);
    assert (!started_now);
    assert (msg is CastStartedMessage);
    assert (last == "PLAYING");
}

void test_media_status_message_unchanged () {
    string last = "PLAYING";
    bool started_now;
    var msg = CastService.media_status_message (media_json ("PLAYING"), "id-1",
        true, ref last, out started_now);
    assert (!started_now);
    assert (msg == null);
    assert (last == "PLAYING");
}

void test_media_app_from_json () {
    var json = ("{\"type\":\"RECEIVER_STATUS\",\"status\":{\"applications\":["
        + "{\"appId\":\"E8C28D3C\",\"sessionId\":\"backdrop\",\"displayName\":\"Backdrop\","
        + "\"namespaces\":[]},"
        + "{\"appId\":\"CC1AD845\",\"sessionId\":\"app-1\","
        + "\"displayName\":\"Default Media Receiver\","
        + "\"namespaces\":[\"urn:x-cast:com.google.cast.media\"]}]}}");
    var app = CastService.media_app_from_json (json);
    assert (app != null);
    assert (app.session_id == "app-1");
    assert (app.name == "Default Media Receiver");
}

void test_media_app_from_json_object_namespaces () {
    // Real receivers send namespaces as objects, not plain strings.
    var json = ("{\"type\":\"RECEIVER_STATUS\",\"status\":{\"applications\":["
        + "{\"appId\":\"CC1AD845\",\"sessionId\":\"app-1\","
        + "\"displayName\":\"Default Media Receiver\","
        + "\"namespaces\":[{\"name\":\"urn:x-cast:com.google.cast.media\"}]}]}}");
    var app = CastService.media_app_from_json (json);
    assert (app != null);
    assert (app.session_id == "app-1");
    assert (app.name == "Default Media Receiver");
}

void test_media_app_from_json_without_media_namespace () {
    var json = ("{\"status\":{\"applications\":["
        + "{\"appId\":\"233637DE\",\"sessionId\":\"yt\",\"displayName\":\"YouTube\","
        + "\"namespaces\":[\"urn:x-cast:com.google.cast.youtube\"]}]}}");
    assert (CastService.media_app_from_json (json) == null);
}

void test_media_app_from_json_empty () {
    assert (CastService.media_app_from_json ("{\"status\":{\"applications\":[]}}") == null);
    assert (CastService.media_app_from_json ("not json") == null);
}

void test_media_content_id () {
    var json = ("{\"type\":\"MEDIA_STATUS\",\"status\":[{"
        + "\"mediaSessionId\":7,\"playerState\":\"PLAYING\","
        + "\"media\":{\"contentId\":\"https://example.test/stream\","
        + "\"metadata\":{\"title\":\"Station\"}}}]}");
    assert (CastService.media_content_id_from_json (json) ==
        "https://example.test/stream");
    assert (CastService.media_title_from_json (json) == "Station");
    // Liveness polls may omit metadata entirely: no title, not a cleared one.
    var without_metadata = ("{\"type\":\"MEDIA_STATUS\",\"status\":[{"
        + "\"mediaSessionId\":7,\"playerState\":\"PLAYING\","
        + "\"media\":{\"contentId\":\"https://example.test/stream\"}}]}");
    assert (CastService.media_title_from_json (without_metadata) == "");
    assert (CastService.media_content_id_from_json ("{\"status\":[]}") == "");
    assert (CastService.media_title_from_json ("{\"status\":[]}") == "");
}

void test_is_http_url () {
    assert (CastService.is_http_url ("http://example.test/a"));
    assert (CastService.is_http_url ("https://example.test/a"));
    assert (!CastService.is_http_url ("rtsp://example.test/a"));
    assert (!CastService.is_http_url (""));
    assert (!CastService.is_http_url ("youtube:video:abc"));
}

void test_media_command_json () {
    var parser = new Json.Parser ();
    parser.load_from_data (CastService.media_command_json (9, "PAUSE", 4));
    var obj = parser.get_root ().get_object ();
    assert (obj.get_string_member ("type") == "PAUSE");
    assert (obj.get_int_member ("requestId") == 9);
    assert (obj.get_int_member ("mediaSessionId") == 4);
}

void test_set_volume_json () {
    var parser = new Json.Parser ();
    parser.load_from_data (CastService.set_volume_json (11, 0.45));
    var obj = parser.get_root ().get_object ();
    assert (obj.get_string_member ("type") == "SET_VOLUME");
    assert (obj.get_int_member ("requestId") == 11);
    var volume = obj.get_object_member ("volume");
    assert (volume.get_double_member ("level") > 0.44);
    assert (volume.get_double_member ("level") < 0.46);
}

void test_receiver_volume_from_json () {
    assert (CastService.receiver_volume_from_json (
        "{\"type\":\"RECEIVER_STATUS\",\"status\":{\"volume\":{\"level\":0.42,\"muted\":false}}}") > 0.419);
    assert (Math.fabs (CastService.receiver_volume_from_json (
        "{\"type\":\"RECEIVER_STATUS\",\"status\":{\"volume\":{\"level\":0.42}}}") - 0.42) < 0.001);
    assert (CastService.receiver_volume_from_json ("{\"status\":{}}") == -1.0);
    assert (CastService.receiver_volume_from_json ("{}") == -1.0);
    assert (CastService.receiver_volume_from_json ("not json") == -1.0);
    assert (CastService.receiver_volume_from_json (
        "{\"status\":{\"volume\":{\"level\":2.0}}}") == -1.0);
    assert (CastService.receiver_volume_from_json (
        "{\"status\":{\"volume\":{\"muted\":true}}}") == -1.0);
    // A non-numeric level must be rejected, not read as 0.0 ("muted").
    assert (CastService.receiver_volume_from_json (
        "{\"status\":{\"volume\":{\"level\":\"0.5\"}}}") == -1.0);
    // An integer level is valid JSON for a receiver that sends 0 or 1.
    assert (CastService.receiver_volume_from_json (
        "{\"status\":{\"volume\":{\"level\":1}}}") == 1.0);
}

void test_heartbeat_lost_requires_repeated_miss () {
    int64 now = 100000000;
    int64 step = 1000000;
    // Nothing is lost while a PONG is arriving, or inside one quiet window.
    assert (!CastService.heartbeat_lost (now, now, 0));
    assert (!CastService.heartbeat_lost (now - 5 * step, now, 0));
    assert (!CastService.heartbeat_lost (
        now - (CastService.HEARTBEAT_TIMEOUT_SECONDS + 1) * step, now, 1));
    // Repeated misses do not help while the window is still open.
    assert (!CastService.heartbeat_lost (now, now,
        CastService.HEARTBEAT_MISSES));
    assert (!CastService.heartbeat_lost (now - 5 * step, now,
        CastService.HEARTBEAT_MISSES));
    // The boundary itself counts as quiet.
    assert (!CastService.heartbeat_lost (
        now - CastService.HEARTBEAT_TIMEOUT_SECONDS * step, now, 1));
    assert (CastService.heartbeat_lost (
        now - CastService.HEARTBEAT_TIMEOUT_SECONDS * step, now,
        CastService.HEARTBEAT_MISSES));
    // The live timer only reaches HEARTBEAT_MISSES after a second quiet tick,
    // i.e. one interval past the timeout. That is the pair that must be lost.
    int64 detected = (CastService.HEARTBEAT_TIMEOUT_SECONDS +
        CastService.HEARTBEAT_INTERVAL_SECONDS) * step;
    assert (CastService.heartbeat_lost (
        now - detected, now, CastService.HEARTBEAT_MISSES));
    assert (!CastService.heartbeat_lost (
        now - detected, now, CastService.HEARTBEAT_MISSES - 1));
}

void test_probe_reports_no_session_on_connection_error () {
    Gradio.Message? result = null;
    var cmd = CastService.probe_cmd ("id-1", "127.0.0.1", 1);
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => { result = msg; }, cmd);
    var context = GLib.MainContext.@default ();
    var deadline = GLib.get_monotonic_time () + 3 * 1000000;
    while (result == null && GLib.get_monotonic_time () < deadline)
        context.iteration (true);
    assert (result is CastSessionDetectedMessage);
    var detected = result as CastSessionDetectedMessage;
    assert (detected != null);
    assert (detected.content_id == "");
    assert (detected.player_state == "");
}

void test_adopt_reports_failure_on_connection_error () {
    Gradio.Message? result = null;
    var cmd = CastService.adopt_cmd ("id-1", "127.0.0.1", 1,
        "https://example.test/stream");
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => { result = msg; }, cmd);
    var context = GLib.MainContext.@default ();
    var deadline = GLib.get_monotonic_time () + 3 * 1000000;
    while (result == null && GLib.get_monotonic_time () < deadline)
        context.iteration (true);
    assert (result is CastAdoptFailedMessage);
}

void test_connection_source_ids_are_unique () {
    var first = new CastConnection ();
    var second = new CastConnection ();
    assert (first.source_id != "");
    assert (second.source_id != "");
    assert (first.source_id != second.source_id);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/cast/content_type_default", test_content_type_default);
    Test.add_func ("/cast/connection_source_ids_are_unique", test_connection_source_ids_are_unique);
    Test.add_func ("/cast/stop_dispatches_stopped", test_stop_cast_dispatches_stopped);
    Test.add_func ("/cast/close_after_drain_once", test_close_after_drain_emits_closed_once);
    Test.add_func ("/cast/content_type_m3u8", test_content_type_m3u8);
    Test.add_func ("/cast/content_type_aac", test_content_type_aac);
    Test.add_func ("/cast/parse_devices_valid", test_parse_devices_valid);
    Test.add_func ("/cast/parse_devices_invalid", test_parse_devices_invalid);
    Test.add_func ("/cast/parse_devices_empty", test_parse_devices_empty);
    Test.add_func ("/cast/launch_json", test_launch_json);
    Test.add_func ("/cast/load_json", test_load_json);
    Test.add_func ("/cast/receiver_session", test_receiver_session_id);
    Test.add_func ("/cast/media_state", test_media_player_state);
    Test.add_func ("/cast/media_stop_json", test_media_stop_json);
    Test.add_func ("/cast/load_json_escapes_control_characters", test_load_json_escapes_control_characters);
    Test.add_func ("/cast/media_status_json", test_media_status_json);
    Test.add_func ("/cast/media_status_json_without_session", test_media_status_json_without_session);
    Test.add_func ("/cast/player_transition_buffering", test_player_transition_buffering_does_not_start);
    Test.add_func ("/cast/player_transition_resumes_from_buffering", test_player_transition_resumes_from_buffering);
    Test.add_func ("/cast/should_report_lost", test_should_report_lost);
    Test.add_func ("/cast/close_action_active_session", test_close_action_active_session_is_sender_loss);
    Test.add_func ("/cast/close_action_adopted_session", test_close_action_adopted_session_is_sender_loss);
    Test.add_func ("/cast/close_action_before_start", test_close_action_before_start_fails_attempt);
    Test.add_func ("/cast/close_action_finished_attempt", test_close_action_ignores_finished_attempt);
    Test.add_func ("/cast/player_transition_playing", test_player_transition_playing_starts);
    Test.add_func ("/cast/player_transition_idle", test_player_transition_idle_is_lost);
    Test.add_func ("/cast/player_transition_empty_is_lost", test_player_transition_empty_status_is_lost);
    Test.add_func ("/cast/player_transition_paused", test_player_transition_paused);
    Test.add_func ("/cast/player_transition_resumes", test_player_transition_resumes);
    Test.add_func ("/cast/player_transition_same_state", test_player_transition_same_state_is_none);
    Test.add_func ("/cast/liveness_expired", test_liveness_expired_boundary);
    Test.add_func ("/cast/media_message_initial_playing", test_media_status_message_initial_playing);
    Test.add_func ("/cast/media_message_initial_buffering", test_media_status_message_initial_buffering);
    Test.add_func ("/cast/media_message_idle", test_media_status_message_idle_is_lost);
    Test.add_func ("/cast/media_message_initial_paused", test_media_status_message_initial_paused);
    Test.add_func ("/cast/heartbeat_namespace", test_heartbeat_namespace);
    Test.add_func ("/cast/media_message_paused", test_media_status_message_paused);
    Test.add_func ("/cast/media_message_resumes", test_media_status_message_resumes);
    Test.add_func ("/cast/media_message_unchanged", test_media_status_message_unchanged);
    Test.add_func ("/cast/media_app_from_json", test_media_app_from_json);
    Test.add_func ("/cast/media_app_from_json_object_namespaces", test_media_app_from_json_object_namespaces);
    Test.add_func ("/cast/media_app_without_media_namespace", test_media_app_from_json_without_media_namespace);
    Test.add_func ("/cast/media_app_empty", test_media_app_from_json_empty);
    Test.add_func ("/cast/media_content_id", test_media_content_id);
    Test.add_func ("/cast/is_http_url", test_is_http_url);
    Test.add_func ("/cast/media_command_json", test_media_command_json);
    Test.add_func ("/cast/set_volume_json", test_set_volume_json);
    Test.add_func ("/cast/receiver_volume_from_json", test_receiver_volume_from_json);
    Test.add_func ("/cast/heartbeat_lost_requires_repeated_miss", test_heartbeat_lost_requires_repeated_miss);
    Test.add_func ("/cast/heartbeat_tick", test_heartbeat_tick);
    Test.add_func ("/cast/probe_no_session_on_connection_error", test_probe_reports_no_session_on_connection_error);
    Test.add_func ("/cast/adopt_failure_on_connection_error", test_adopt_reports_failure_on_connection_error);
    return Test.run ();
}

void test_launch_json () {
    var parser = new Json.Parser ();
    parser.load_from_data (CastService.launch_json (7));
    var obj = parser.get_root ().get_object ();
    assert (obj.get_string_member ("type") == "LAUNCH");
    assert (obj.get_string_member ("appId") == "CC1AD845");
    assert (obj.get_int_member ("requestId") == 7);
}

void test_load_json () {
    var parser = new Json.Parser ();
    parser.load_from_data (CastService.load_json (9, "session-1",
        "https://example.test/stream", "audio/mpeg"));
    var obj = parser.get_root ().get_object ();
    assert (obj.get_string_member ("type") == "LOAD");
    assert (obj.get_string_member ("sessionId") == "session-1");
    assert (obj.get_boolean_member ("autoplay"));
    var media = obj.get_object_member ("media");
    assert (media.get_string_member ("contentId") == "https://example.test/stream");
    assert (media.get_string_member ("contentType") == "audio/mpeg");
    assert (media.get_string_member ("streamType") == "LIVE");
}

void test_receiver_session_id () {
    var json = "{\"responseType\":\"RECEIVER_STATUS\",\"status\":{\"applications\":[" +
        "{\"appId\":\"233637DE\",\"sessionId\":\"other\"}," +
        "{\"appId\":\"CC1AD845\",\"sessionId\":\"receiver-session\"}]}}";
    assert (CastService.receiver_session_id (json) == "receiver-session");
}

void test_media_player_state () {
    var json = "{\"type\":\"MEDIA_STATUS\",\"status\":[{\"mediaSessionId\":3," +
        "\"playerState\":\"PLAYING\"}]}";
    assert (CastService.media_player_state (json) == "PLAYING");
}

void test_media_stop_json () {
    var parser = new Json.Parser ();
    parser.load_from_data (CastService.media_stop_json (4, "session-1", 3));
    var obj = parser.get_root ().get_object ();
    assert (obj.get_string_member ("type") == "STOP");
    assert (obj.get_string_member ("sessionId") == "session-1");
    assert (obj.get_int_member ("mediaSessionId") == 3);
}
