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
    var cmd = CastService.stop_cmd ("id", "127.0.0.1", 8009);
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => { last = msg; }, cmd);
    assert (last is CastStoppedMessage);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/cast/content_type_default", test_content_type_default);
    Test.add_func ("/cast/stop_dispatches_stopped", test_stop_cast_dispatches_stopped);
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
