// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

RadioStation make_station (string id, string name, string url) {
    var station = new RadioStation ();
    station.id = id;
    station.name = name;
    station.url = url;
    station.original_url = url;
    return station;
}

GLib.GenericArray<RadioStation> parse (string json) {
    try {
        return StationTransfer.parse (json);
    } catch (GLib.Error e) {
        assert_not_reached ();
    }
    return new GLib.GenericArray<RadioStation> ();
}

void test_parse_plain_array () {
    var stations = parse (
        "[{\"stationuuid\":\"u1\",\"name\":\"Jazz\",\"url_resolved\":\"https://example.test/jazz\"}]");
    assert (stations.length == 1);
    assert (stations.get (0).id == "u1");
}

void test_parse_config_object () {
    var stations = parse (
        "{\"version\":1,\"stations\":[{\"stationuuid\":\"u1\",\"name\":\"Jazz\",\"url_resolved\":\"https://example.test/jazz\"}]}");
    assert (stations.length == 1);
    assert (stations.get (0).name == "Jazz");
}

void test_parse_rejects_invalid_json () {
    bool threw = false;
    try {
        StationTransfer.parse ("not json");
    } catch (GLib.Error e) {
        threw = true;
    }
    assert (threw);
}

void test_parse_rejects_object_without_stations () {
    bool threw = false;
    try {
        StationTransfer.parse ("{\"version\":1}");
    } catch (GLib.Error e) {
        threw = true;
    }
    assert (threw);
}

void test_parse_skips_invalid_entries () {
    var stations = parse (
        "[{\"stationuuid\":\"u1\",\"name\":\"Valid\",\"url_resolved\":\"https://example.test/valid\"}," +
        "{\"stationuuid\":\"\",\"name\":\"No id\",\"url_resolved\":\"https://example.test/noid\"}," +
        "{\"stationuuid\":\"u3\",\"name\":\"\",\"url_resolved\":\"https://example.test/noname\"}," +
        "{\"stationuuid\":\"u4\",\"name\":\"No url\"}]");
    assert (stations.length == 1);
    assert (stations.get (0).id == "u1");
}

void test_parse_marks_third_party_stations_owned () {
    var stations = parse (
        "[{\"stationuuid\":\"u1\",\"name\":\"Jazz\",\"url_resolved\":\"https://example.test/jazz\"}]");
    assert (stations.length == 1);
    assert (stations.get (0).is_local == true);
}

void test_parse_keeps_explicit_remote_flag () {
    var stations = parse (
        "[{\"stationuuid\":\"u1\",\"name\":\"Jazz\",\"url_resolved\":\"https://example.test/jazz\",\"local\":false}]");
    assert (stations.length == 1);
    assert (stations.get (0).is_local == false);
}

void test_export_round_trip () {
    var stations = new GLib.GenericArray<RadioStation> ();
    stations.add (make_station ("u1", "Jazz", "https://example.test/jazz"));
    stations.add (make_station ("u2", "Rock", "https://example.test/rock"));

    string json = StationTransfer.export_json (stations);
    var parsed = parse (json);
    assert (parsed.length == 2);
    assert (parsed.get (0).id == "u1");
    assert (parsed.get (1).name == "Rock");
}

void test_export_playlist () {
    var stations = new GLib.GenericArray<RadioStation> ();
    stations.add (make_station ("u1", "Jazz \"Live\"", "https://example.test/jazz"));
    stations.add (make_station ("u2", "Rock", "https://example.test/rock"));

    string m3u = StationTransfer.export_m3u (stations);
    assert (m3u.has_prefix ("#EXTM3U\n"));
    assert (m3u.contains ("#EXTINF:-1,Jazz \"Live\"\nhttps://example.test/jazz\n"));
    assert (m3u.contains ("#EXTINF:-1,Rock\nhttps://example.test/rock\n"));
}

void test_export_playlist_flattens_names_and_skips_empty_urls () {
    var stations = new GLib.GenericArray<RadioStation> ();
    stations.add (make_station ("u1", "Jazz FM", ""));
    stations.add (make_station ("u2", "Smooth\r\nJazz", "https://example.test/smooth"));
    stations.add (make_station ("u3", "Line\nBreak", "https://example.test/line"));

    string m3u = StationTransfer.export_m3u (stations);
    assert (!m3u.contains ("Jazz FM"));
    assert (!m3u.contains ("\r"));
    assert (m3u.contains ("#EXTINF:-1,Smooth  Jazz\nhttps://example.test/smooth\n"));
    assert (m3u.contains ("#EXTINF:-1,Line Break\nhttps://example.test/line\n"));
    int entries = 0;
    int pos = 0;
    while ((pos = m3u.index_of ("#EXTINF", pos)) >= 0) {
        entries++;
        pos += 7;
    }
    assert (entries == 2);
}

void test_merge_adds_new_and_skips_duplicates () {
    var config = new AppConfig ("/tmp/gradio-transfer-test.json");
    config.add_station (make_station ("u1", "Jazz", "https://example.test/jazz"));

    var incoming = new GLib.GenericArray<RadioStation> ();
    incoming.add (make_station ("u1", "Jazz duplicate id", "https://other.test/jazz"));
    incoming.add (make_station ("u2", "Jazz duplicate url", "https://example.test/jazz"));
    incoming.add (make_station ("u3", "Rock", "https://example.test/rock"));

    var summary = config.import_stations (incoming);
    assert (summary.imported == 1);
    assert (summary.skipped == 2);
    assert (config.stations.length == 2);
    assert (config.stations.get (1).id == "u3");
}

void test_merge_skips_invalid_entries () {
    var config = new AppConfig ("/tmp/gradio-transfer-test.json");
    var incoming = new GLib.GenericArray<RadioStation> ();
    incoming.add (make_station ("", "No id", "https://example.test/a"));
    incoming.add (make_station ("u2", "", "https://example.test/b"));
    incoming.add (make_station ("u3", "No url", ""));

    var summary = config.import_stations (incoming);
    assert (summary.imported == 0);
    assert (summary.skipped == 3);
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/station-transfer/parse_array", test_parse_plain_array);
    Test.add_func ("/station-transfer/parse_config", test_parse_config_object);
    Test.add_func ("/station-transfer/parse_invalid", test_parse_rejects_invalid_json);
    Test.add_func ("/station-transfer/parse_no_stations", test_parse_rejects_object_without_stations);
    Test.add_func ("/station-transfer/parse_skips_invalid", test_parse_skips_invalid_entries);
    Test.add_func ("/station-transfer/parse_owned", test_parse_marks_third_party_stations_owned);
    Test.add_func ("/station-transfer/parse_remote_flag", test_parse_keeps_explicit_remote_flag);
    Test.add_func ("/station-transfer/export_round_trip", test_export_round_trip);
    Test.add_func ("/station-transfer/export_playlist", test_export_playlist);
    Test.add_func ("/station-transfer/export_playlist_flattens",
        test_export_playlist_flattens_names_and_skips_empty_urls);
    Test.add_func ("/station-transfer/merge", test_merge_adds_new_and_skips_duplicates);
    Test.add_func ("/station-transfer/merge_invalid", test_merge_skips_invalid_entries);

    return Test.run ();
}
