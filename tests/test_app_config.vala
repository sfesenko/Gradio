// SPDX-License-Identifier: GPL-3.0-or-later

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
    assert (config.window_width == 900);
    assert (config.window_height == 600);
    assert (config.maximized == false);
    assert (config.icon_size == 48);
    cleanup (dir);
}

void test_window_and_icon_round_trip () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");

    var config = new Gradio.AppConfig (path);
    config.window_width = 1200;
    config.window_height = 800;
    config.maximized = true;
    config.icon_size = 64;
    config.search_sort = Gradio.SearchSortMode.VOTES;
    save_config (config);

    var loaded = load_config (path);
    assert (loaded.window_width == 1200);
    assert (loaded.window_height == 800);
    assert (loaded.maximized == true);
    assert (loaded.icon_size == 64);
    assert (loaded.search_sort == Gradio.SearchSortMode.VOTES);
    cleanup (dir);
}

void test_invalid_sort_modes_fall_back () {
    string dir = make_tmp_dir ();
    string path = write_file (dir, "config.json",
        "{\"version\":1,\"settings\":{\"sort_mode\":\"bogus\",\"search_sort\":\"bogus\"}}");

    var config = load_config (path);
    assert (config.search_sort == Gradio.SearchSortMode.RELEVANCE);
    cleanup (dir);
}

void test_invalid_window_and_icon_values_fall_back () {
    string dir = make_tmp_dir ();
    string path = write_file (dir, "config.json",
        "{\"version\":1,\"settings\":{\"window_width\":-5,\"window_height\":0,\"icon_size\":77}}");

    var config = load_config (path);
    assert (config.window_width == 900);
    assert (config.window_height == 600);
    assert (config.icon_size == 48);
    cleanup (dir);
}

void test_unknown_icon_size_normalizes_to_default () {
    assert (Gradio.AppConfig.normalize_icon_size (32) == 32);
    assert (Gradio.AppConfig.normalize_icon_size (48) == 48);
    assert (Gradio.AppConfig.normalize_icon_size (64) == 64);
    assert (Gradio.AppConfig.normalize_icon_size (96) == 96);
    assert (Gradio.AppConfig.normalize_icon_size (77) == 48);
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

Gradio.AppConfig make_three_station_config () {
    var config = new Gradio.AppConfig ("/tmp/gradio-test-config.json");
    config.add_station (make_station ("a", "Alpha", "https://example.test/a"));
    config.add_station (make_station ("b", "Beta", "https://example.test/b"));
    config.add_station (make_station ("c", "Gamma", "https://example.test/c"));
    return config;
}

void test_move_station_after_target () {
    var config = make_three_station_config ();
    assert (config.move_station ("a", "b", true));
    assert (config.stations.get (0).id == "b");
    assert (config.stations.get (1).id == "a");
    assert (config.stations.get (2).id == "c");
}

void test_move_station_before_target () {
    var config = make_three_station_config ();
    assert (config.move_station ("c", "a", false));
    assert (config.stations.get (0).id == "c");
    assert (config.stations.get (1).id == "a");
    assert (config.stations.get (2).id == "b");
}

void test_move_station_after_last_target () {
    var config = make_three_station_config ();
    assert (config.move_station ("a", "c", true));
    assert (config.stations.get (0).id == "b");
    assert (config.stations.get (1).id == "c");
    assert (config.stations.get (2).id == "a");
}

void test_move_station_to_same_position_is_noop () {
    var config = make_three_station_config ();
    assert (!config.move_station ("b", "a", true));
    assert (!config.move_station ("a", "a", true));
    assert (!config.move_station ("missing", "a", true));
    assert (!config.move_station ("a", "missing", true));
    assert (config.stations.get (0).id == "a");
    assert (config.stations.get (1).id == "b");
    assert (config.stations.get (2).id == "c");
}

void test_move_station_round_trip () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");
    var config = new Gradio.AppConfig (path);
    config.add_station (make_station ("a", "Alpha", "https://example.test/a"));
    config.add_station (make_station ("b", "Beta", "https://example.test/b"));
    config.add_station (make_station ("c", "Gamma", "https://example.test/c"));
    assert (config.move_station ("c", "a", false));
    save_config (config);

    var loaded = load_config (path);
    assert (loaded.stations.get (0).id == "c");
    assert (loaded.stations.get (1).id == "a");
    assert (loaded.stations.get (2).id == "b");
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

void test_volume_clamped () {
    string dir = make_tmp_dir ();
    string path = write_file (dir, "config.json",
        "{\"version\":1,\"settings\":{\"volume\":5.0}}");
    assert (load_config (path).volume == 1.0);
    GLib.FileUtils.set_contents (path, "{\"version\":1,\"settings\":{\"volume\":-1.0}}");
    assert (load_config (path).volume == 0.0);
    GLib.FileUtils.set_contents (path, "{\"version\":1,\"settings\":{\"volume\":\"NaN\"}}");
    assert (load_config (path).volume == 0.8);
    cleanup (dir);
}

void test_skips_station_without_id () {
    string dir = make_tmp_dir ();
    string path = write_file (dir, "config.json",
        "{\"version\":1,\"stations\":[{\"name\":\"No Id\",\"url_resolved\":\"https://example.test/no-id\"}]}");

    var config = load_config (path);
    assert (config.stations.length == 0);
    cleanup (dir);
}

void test_search_filters_round_trip () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");

    var config = new Gradio.AppConfig (path);
    config.search_filters.country = "Germany";
    config.search_filters.state = "Bavaria";
    config.search_filters.language = "german";
    config.search_filters.tag = "jazz";
    save_config (config);

    var loaded = load_config (path);
    assert (loaded.search_filters.country == "Germany");
    assert (loaded.search_filters.state == "Bavaria");
    assert (loaded.search_filters.language == "german");
    assert (loaded.search_filters.tag == "jazz");
    cleanup (dir);
}

void test_resume_playback_round_trip () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");

    var config = new Gradio.AppConfig (path);
    config.resume_playback = true;
    config.last_station_id = "u1";
    save_config (config);

    var loaded = load_config (path);
    assert (loaded.resume_playback == true);
    assert (loaded.last_station_id == "u1");
    cleanup (dir);
}

void test_resume_playback_defaults_off () {
    string dir = make_tmp_dir ();
    var config = load_config (GLib.Path.build_filename (dir, "config.json"));
    assert (config.resume_playback == false);
    assert (config.last_station_id == "");
    cleanup (dir);
}

void test_library_sort_round_trip () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");

    var config = new Gradio.AppConfig (path);
    config.library_sort = Gradio.LibrarySortMode.COUNTRY;
    config.library_sort_descending = true;
    save_config (config);

    var loaded = load_config (path);
    assert (loaded.library_sort == Gradio.LibrarySortMode.COUNTRY);
    assert (loaded.library_sort_descending == true);
    cleanup (dir);
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/app-config/missing_file_returns_empty", test_missing_file_returns_empty);
    Test.add_func ("/app-config/window_and_icon_round_trip", test_window_and_icon_round_trip);
    Test.add_func ("/app-config/invalid_window_and_icon", test_invalid_window_and_icon_values_fall_back);
    Test.add_func ("/app-config/normalize_icon_size", test_unknown_icon_size_normalizes_to_default);
    Test.add_func ("/app-config/invalid_sort_modes", test_invalid_sort_modes_fall_back);
    Test.add_func ("/app-config/search_filters_round_trip", test_search_filters_round_trip);
    Test.add_func ("/app-config/resume_playback_round_trip", test_resume_playback_round_trip);
    Test.add_func ("/app-config/resume_playback_defaults", test_resume_playback_defaults_off);
    Test.add_func ("/app-config/round_trip", test_round_trip);
    Test.add_func ("/app-config/empty_file", test_empty_file);
    Test.add_func ("/app-config/invalid_json", test_invalid_json);
    Test.add_func ("/app-config/duplicate_station", test_duplicate_station);
    Test.add_func ("/app-config/remove_station", test_remove_station);
    Test.add_func ("/app-config/move_station_after", test_move_station_after_target);
    Test.add_func ("/app-config/move_station_before", test_move_station_before_target);
    Test.add_func ("/app-config/move_station_after_last", test_move_station_after_last_target);
    Test.add_func ("/app-config/move_station_noop", test_move_station_to_same_position_is_noop);
    Test.add_func ("/app-config/move_station_round_trip", test_move_station_round_trip);
    Test.add_func ("/app-config/skips_invalid_station_entries", test_skips_invalid_station_entries);
    Test.add_func ("/app-config/volume_clamped", test_volume_clamped);
    Test.add_func ("/app-config/skips_station_without_id", test_skips_station_without_id);
    Test.add_func ("/app-config/library_sort_round_trip", test_library_sort_round_trip);

    return Test.run ();
}
