// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

void test_playback_status () {
    assert (MprisServer.playback_status_for (true, true, false) == "Playing");
    assert (MprisServer.playback_status_for (false, true, false) == "Paused");
    assert (MprisServer.playback_status_for (false, true, true) == "Stopped");
    assert (MprisServer.playback_status_for (false, false, false) == "Stopped");
}

void test_track_id_is_valid_object_path () {
    string id = MprisServer.track_id_for ("a5b3-f2e1/ü");
    assert (id.has_prefix (MprisServer.TRACK_PREFIX));
    string suffix = id.substring (MprisServer.TRACK_PREFIX.length);
    for (int i = 0; i < suffix.length; i++) {
        char c = suffix[i];
        assert ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9') || c == '_');
    }
}

void test_track_id_handles_empty_id () {
    string id = MprisServer.track_id_for ("");
    assert (id == MprisServer.TRACK_PREFIX + "unknown");
}

void test_metadata_for_station () {
    var station = new RadioStation ();
    station.id = "u1";
    station.name = "Jazz FM";
    station.country = "Germany";
    station.url = "https://example.test/jazz";

    var metadata = MprisServer.metadata_for (station, "");
    var title = metadata.lookup_value ("xesam:title", new GLib.VariantType ("s"));
    assert (title != null && title.get_string () == "Jazz FM");
    var track = metadata.lookup_value ("mpris:trackid", new GLib.VariantType ("o"));
    assert (track != null);
    assert (track.get_string () == MprisServer.TRACK_PREFIX + "u1");
}

void test_metadata_uses_stream_title () {
    var station = new RadioStation ();
    station.id = "u1";
    station.name = "Jazz FM";
    station.url = "https://example.test/jazz";

    var metadata = MprisServer.metadata_for (station, "Live at Montreux");
    var title = metadata.lookup_value ("xesam:title", new GLib.VariantType ("s"));
    assert (title.get_string () == "Live at Montreux");
}

void test_empty_metadata () {
    var metadata = MprisServer.metadata_for (null, "");
    assert (metadata.lookup_value ("xesam:title", new GLib.VariantType ("s")) == null);
    assert (metadata.lookup_value ("mpris:trackid", new GLib.VariantType ("o")) == null);
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/mpris/playback_status", test_playback_status);
    Test.add_func ("/mpris/track_id", test_track_id_is_valid_object_path);
    Test.add_func ("/mpris/track_id_empty", test_track_id_handles_empty_id);
    Test.add_func ("/mpris/metadata_station", test_metadata_for_station);
    Test.add_func ("/mpris/metadata_stream_title", test_metadata_uses_stream_title);
    Test.add_func ("/mpris/metadata_empty", test_empty_metadata);

    return Test.run ();
}
