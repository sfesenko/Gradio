// SPDX-License-Identifier: GPL-3.0-or-later

// RadioStation JSON conversion and display helpers.

void test_from_json_full () {
    var obj = new Json.Object ();
    obj.set_string_member ("stationuuid", "u1");
    obj.set_string_member ("name", "Jazz FM");
    obj.set_string_member ("url_resolved", "https://example.test/jazz");
    obj.set_string_member ("favicon", "https://example.test/icon.png");
    obj.set_string_member ("country", "Germany");
    obj.set_string_member ("countrycode", "DE");
    obj.set_string_member ("language", "german");
    obj.set_string_member ("tags", "jazz,smooth");
    obj.set_string_member ("codec", "MP3");
    obj.set_int_member ("bitrate", 128);
    obj.set_string_member ("homepage", "https://example.test");
    obj.set_int_member ("votes", 10);
    obj.set_int_member ("clickcount", 20);
    obj.set_int_member ("lastcheckok", 1);

    var station = Gradio.RadioStation.from_json_object (obj);
    assert (station != null);
    assert (station.id == "u1");
    assert (station.name == "Jazz FM");
    assert (station.url == "https://example.test/jazz");
    assert (station.bitrate == 128);
    assert (station.broken == false);
}

void test_from_json_minimal () {
    var obj = new Json.Object ();
    obj.set_string_member ("stationuuid", "u2");
    obj.set_string_member ("name", "Minimal");
    obj.set_string_member ("url_resolved", "https://example.test/minimal");

    var station = Gradio.RadioStation.from_json_object (obj);
    assert (station != null);
    assert (station.country == "");
    assert (station.bitrate == 0);
    assert (station.broken == false);
}

void test_round_trip () {
    var station = new Gradio.RadioStation ();
    station.id = "u3";
    station.name = "Round Trip";
    station.url = "https://example.test/rt";
    station.bitrate = 192;

    var parsed = Gradio.RadioStation.from_json_object (station.to_json_node ().get_object ());
    assert (parsed != null);
    assert (parsed.id == station.id);
    assert (parsed.name == station.name);
    assert (parsed.url == station.url);
    assert (parsed.bitrate == station.bitrate);
}

void test_stream_urls () {
    var station = new Gradio.RadioStation ();
    station.url = "https://example.test/resolved";
    station.original_url = "https://example.test/original";

    string[] urls = station.stream_urls ();
    assert (urls.length == 2);
    assert (urls[0] == station.original_url);
    assert (urls[1] == station.url);

    station.original_url = station.url;
    urls = station.stream_urls ();
    assert (urls.length == 1);
    assert (urls[0] == station.url);
}

void test_original_url_round_trip () {
    var station = new Gradio.RadioStation ();
    station.id = "u4";
    station.name = "Two Streams";
    station.original_url = "https://example.test/original";
    station.url = "https://example.test/resolved";

    var parsed = Gradio.RadioStation.from_json_object (station.to_json_node ().get_object ());
    assert (parsed != null);
    assert (parsed.original_url == station.original_url);
    assert (parsed.url == station.url);
}

void test_secondary_text () {
    var station = new Gradio.RadioStation ();
    station.country = "Germany";
    station.codec = "MP3";
    station.bitrate = 128;

    assert (station.secondary_text (false) == "Germany");
    assert (station.secondary_text (true) == "Germany • MP3 128 kbit/s");
}

void test_local_fields_round_trip () {
    var station = new Gradio.RadioStation ();
    station.id = "local-abc";
    station.name = "Local Jazz";
    station.url = "https://example.test/jazz";
    station.state = "Bavaria";
    station.is_local = true;
    station.orphaned = true;

    var parsed = Gradio.RadioStation.from_json_object (station.to_json_node ().get_object ());
    assert (parsed != null);
    assert (parsed.state == "Bavaria");
    assert (parsed.is_local == true);
    assert (parsed.orphaned == true);
}

void test_local_id_prefix () {
    string id = Gradio.RadioStation.new_local_id ();
    assert (id.has_prefix ("local-"));
    assert (id.length > "local-".length);
    assert (Gradio.RadioStation.new_local_id () != id);
}

void test_copy_preserves_fields () {
    var station = new Gradio.RadioStation ();
    station.id = "local-abc";
    station.name = "Local Jazz";
    station.url = "https://example.test/jazz";
    station.state = "Bavaria";
    station.is_local = true;

    var copy = station.copy ();
    assert (copy.id == station.id);
    assert (copy.name == station.name);
    assert (copy.state == station.state);
    assert (copy.is_local == true);
    copy.name = "Changed";
    assert (station.name == "Local Jazz");
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/radio-station/from_json_full", test_from_json_full);
    Test.add_func ("/radio-station/from_json_minimal", test_from_json_minimal);
    Test.add_func ("/radio-station/round_trip", test_round_trip);
    Test.add_func ("/radio-station/stream_urls", test_stream_urls);
    Test.add_func ("/radio-station/original_url_round_trip", test_original_url_round_trip);
    Test.add_func ("/radio-station/secondary_text", test_secondary_text);
    Test.add_func ("/radio-station/local_fields_round_trip", test_local_fields_round_trip);
    Test.add_func ("/radio-station/local_id_prefix", test_local_id_prefix);
    Test.add_func ("/radio-station/copy_preserves_fields", test_copy_preserves_fields);

    return Test.run ();
}
