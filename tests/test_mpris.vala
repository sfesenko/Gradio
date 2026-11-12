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
    var artist = metadata.lookup_value ("xesam:artist", new GLib.VariantType ("as"));
    assert (artist != null && artist.get_strv ()[0] == "Jazz FM");
}

void test_metadata_without_stream_title_has_no_artist () {
    var station = new RadioStation ();
    station.id = "u1";
    station.name = "Jazz FM";
    station.country = "Germany";
    station.url = "https://example.test/jazz";

    var metadata = MprisServer.metadata_for (station, "");
    assert (metadata.lookup_value ("xesam:artist", new GLib.VariantType ("as")) == null);
}

void test_empty_metadata () {
    var metadata = MprisServer.metadata_for (null, "");
    assert (metadata.lookup_value ("xesam:title", new GLib.VariantType ("s")) == null);
    assert (metadata.lookup_value ("mpris:trackid", new GLib.VariantType ("o")) == null);
}

void test_update_tracks_stop_state () {
    var app = new GLib.Application ("io.github.sfesenko.gradio.test",
        GLib.ApplicationFlags.NON_UNIQUE);
    var server = new MprisServer ((msg) => {}, app);
    var config = new Gradio.AppConfig ("/tmp/gradio-mpris-test.json");
    var model = new Gradio.AppModel (config);
    var station = new RadioStation ();
    station.id = "u1";
    station.name = "Jazz FM";
    model.current_station = station;

    model.playing = true;
    model.playback_stopped = false;
    server.update (model);
    assert (server.playback_status == "Playing");

    model.playing = false;
    model.playback_stopped = true;
    server.update (model);
    assert (server.playback_status == "Stopped");

    model.playback_stopped = false;
    server.update (model);
    assert (server.playback_status == "Paused");
}

void test_volume_rejects_nan () {
    var app = new GLib.Application ("io.github.sfesenko.gradio.test",
        GLib.ApplicationFlags.NON_UNIQUE);
    bool dispatched = false;
    var server = new MprisServer ((msg) => { dispatched = true; }, app);
    server.volume = double.NAN;
    assert (!dispatched);
    assert (server.volume == 0.8);
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/mpris/playback_status", test_playback_status);
    Test.add_func ("/mpris/track_id", test_track_id_is_valid_object_path);
    Test.add_func ("/mpris/track_id_empty", test_track_id_handles_empty_id);
    Test.add_func ("/mpris/metadata_station", test_metadata_for_station);
    Test.add_func ("/mpris/metadata_stream_title", test_metadata_uses_stream_title);
    Test.add_func ("/mpris/metadata_no_stream_title", test_metadata_without_stream_title_has_no_artist);
    Test.add_func ("/mpris/metadata_empty", test_empty_metadata);
    Test.add_func ("/mpris/update_stop_state", test_update_tracks_stop_state);
    Test.add_func ("/mpris/volume_rejects_nan", test_volume_rejects_nan);

    return Test.run ();
}
