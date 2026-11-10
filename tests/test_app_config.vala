// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

// AppConfig JSON persistence.

string make_tmp_dir () {
    return GLib.DirUtils.make_tmp ("gradio-config-test-XXXXXX");
}

string write_file (string dir, string name, string contents) {
    string path = GLib.Path.build_filename (dir, name);
    try {
        GLib.FileUtils.set_contents (path, contents);
    } catch (GLib.Error e) {
        assert_not_reached ();
    }
    return path;
}

void cleanup (string dir) {
    GLib.FileUtils.remove (GLib.Path.build_filename (dir, "config.json"));
    GLib.FileUtils.remove (GLib.Path.build_filename (dir, "config.json.tmp"));
    GLib.DirUtils.remove (dir);
}

Gradio.AppConfig load_config (string path) {
    try {
        return Gradio.AppConfig.load (path);
    } catch (GLib.Error e) {
        assert_not_reached ();
    }
    return new Gradio.AppConfig (path);
}

void save_config (Gradio.AppConfig config) {
    try {
        config.save ();
    } catch (GLib.Error e) {
        assert_not_reached ();
    }
}

Gradio.RadioStation make_station (string id, string name, string url) {
    var station = new Gradio.RadioStation ();
    station.id = id;
    station.name = name;
    station.url = url;
    return station;
}

void test_missing_file_returns_empty () {
    string dir = make_tmp_dir ();
    var config = load_config (GLib.Path.build_filename (dir, "config.json"));
    assert (config.stations.length == 0);
    assert (config.volume == 0.8);
    cleanup (dir);
}

void test_round_trip () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");

    var config = new Gradio.AppConfig (path);
    config.volume = 0.42;
    config.show_technical_info = true;
    assert (config.add_station (make_station ("u1", "Jazz FM", "https://example.test/jazz")));
    save_config (config);

    var loaded = load_config (path);
    assert (loaded.volume == 0.42);
    assert (loaded.show_technical_info == true);
    assert (loaded.stations.length == 1);
    assert (loaded.find_station ("u1").name == "Jazz FM");
    cleanup (dir);
}

void test_empty_file () {
    string dir = make_tmp_dir ();
    string path = write_file (dir, "config.json", "");

    var config = load_config (path);
    assert (config.stations.length == 0);
    assert (config.volume == 0.8);
    cleanup (dir);
}

void test_invalid_json () {
    string dir = make_tmp_dir ();
    string path = write_file (dir, "config.json", "{not json");

    bool threw = false;
    try {
        Gradio.AppConfig.load (path);
    } catch (GLib.Error e) {
        threw = true;
    }
    assert (threw);
    cleanup (dir);
}

void test_duplicate_station () {
    string dir = make_tmp_dir ();
    var config = new Gradio.AppConfig (GLib.Path.build_filename (dir, "config.json"));

    assert (config.add_station (make_station ("u1", "Jazz FM", "https://example.test/jazz")));
    assert (!config.add_station (make_station ("u1", "Other", "https://example.test/other")));
    assert (config.stations.length == 1);
    cleanup (dir);
}

void test_remove_station () {
    string dir = make_tmp_dir ();
    var config = new Gradio.AppConfig (GLib.Path.build_filename (dir, "config.json"));

    assert (config.add_station (make_station ("u1", "Jazz FM", "https://example.test/jazz")));
    assert (config.remove_station ("u1"));
    assert (!config.remove_station ("u1"));
    assert (config.stations.length == 0);
    cleanup (dir);
}

void test_skips_invalid_station_entries () {
    string dir = make_tmp_dir ();
    string path = write_file (dir, "config.json",
        "{\"version\":1,\"stations\":[{\"stationuuid\":\"u1\",\"name\":\"Jazz FM\",\"url_resolved\":\"https://example.test/jazz\"},{}]}");

    var config = load_config (path);
    assert (config.stations.length == 1);
    assert (config.find_station ("u1").name == "Jazz FM");
    cleanup (dir);
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/app-config/missing_file_returns_empty", test_missing_file_returns_empty);
    Test.add_func ("/app-config/round_trip", test_round_trip);
    Test.add_func ("/app-config/empty_file", test_empty_file);
    Test.add_func ("/app-config/invalid_json", test_invalid_json);
    Test.add_func ("/app-config/duplicate_station", test_duplicate_station);
    Test.add_func ("/app-config/remove_station", test_remove_station);
    Test.add_func ("/app-config/skips_invalid_station_entries", test_skips_invalid_station_entries);

    return Test.run ();
}
