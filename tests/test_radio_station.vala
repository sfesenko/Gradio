// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

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

void test_secondary_text () {
    var station = new Gradio.RadioStation ();
    station.country = "Germany";
    station.codec = "MP3";
    station.bitrate = 128;

    assert (station.secondary_text (false) == "Germany");
    assert (station.secondary_text (true) == "Germany • MP3 128 kbit/s");
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/radio-station/from_json_full", test_from_json_full);
    Test.add_func ("/radio-station/from_json_minimal", test_from_json_minimal);
    Test.add_func ("/radio-station/round_trip", test_round_trip);
    Test.add_func ("/radio-station/secondary_text", test_secondary_text);

    return Test.run ();
}
