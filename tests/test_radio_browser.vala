// SPDX-License-Identifier: GPL-3.0-or-later

using Soup;

GLib.GenericArray<Gradio.RadioStation> parse (string json) {
    try {
        return Gradio.RadioBrowser.parse_stations (json);
    } catch (GLib.Error e) {
        assert_not_reached ();
    }
    return new GLib.GenericArray<Gradio.RadioStation> ();
}

void test_search_url () {
    string url = Gradio.RadioBrowser.search_url ("jazz fm", 25);
    var query = Soup.Form.decode (url.substring (url.index_of ("?") + 1));
    assert (query.lookup ("name") == "jazz fm");
    assert (query.lookup ("limit") == "25");
    assert (query.lookup ("hidebroken") == "true");
    assert (query.lookup ("order") == "clickcount");
    assert (query.lookup ("reverse") == "true");
}

void test_parse_stations () {
    string json = "[{\"stationuuid\":\"u1\",\"name\":\"Jazz FM\",\"url_resolved\":\"https://example.test/jazz\",\"country\":\"Germany\",\"codec\":\"MP3\",\"bitrate\":128}]";
    var stations = parse (json);
    assert (stations.length == 1);
    assert (stations.get (0).name == "Jazz FM");
    assert (stations.get (0).bitrate == 128);
}

void test_parse_empty () {
    assert (parse ("[]").length == 0);
}

void test_parse_skips_invalid () {
    string json = "[" +
        "{\"stationuuid\":\"u1\",\"name\":\"Valid\",\"url_resolved\":\"https://example.test/valid\"}," +
        "{}," +
        "{\"stationuuid\":\"u2\",\"url_resolved\":\"https://example.test/no-name\"}," +
        "{\"stationuuid\":\"u3\",\"name\":\"No URL\"}," +
        "{\"stationuuid\":\"u4\",\"name\":\"No Playable\",\"url\":\"\"}" +
        "]";
    var stations = parse (json);
    assert (stations.length == 1);
    assert (stations.get (0).name == "Valid");
}

void test_search_url_unicode () {
    string url = Gradio.RadioBrowser.search_url ("jazz ä", 10);
    string raw = url.substring (url.index_of ("?") + 1);
    assert (!raw.contains (" "));
    assert (!raw.contains ("ä"));
    assert (raw.contains ("jazz"));
    assert (raw.contains ("%C3%A4"));

    var query = Soup.Form.decode (raw);
    assert (query.lookup ("name") == "jazz ä");
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/radio-browser/search_url", test_search_url);
    Test.add_func ("/radio-browser/parse_stations", test_parse_stations);
    Test.add_func ("/radio-browser/parse_empty", test_parse_empty);
    Test.add_func ("/radio-browser/parse_skips_invalid", test_parse_skips_invalid);
    Test.add_func ("/radio-browser/search_url_unicode", test_search_url_unicode);

    return Test.run ();
}
