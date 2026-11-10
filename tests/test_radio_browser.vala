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

void test_search_url_with_filters () {
    var filters = new Gradio.SearchFilters ();
    filters.country = "Germany";
    filters.state = "Bavaria";
    filters.language = "german";
    filters.tag = "jazz";

    string url = Gradio.RadioBrowser.search_url ("radio", 10, filters);
    var query = Soup.Form.decode (url.substring (url.index_of ("?") + 1));

    assert (query.lookup ("country") == "Germany");
    assert (query.lookup ("state") == "Bavaria");
    assert (query.lookup ("language") == "german");
    assert (query.lookup ("tagList") == "jazz");
}

void test_search_url_empty_query_with_filter () {
    var filters = new Gradio.SearchFilters ();
    filters.country = "Ukraine";

    string url = Gradio.RadioBrowser.search_url ("", 10, filters);
    var query = Soup.Form.decode (url.substring (url.index_of ("?") + 1));

    assert (query.lookup ("name") == "");
    assert (query.lookup ("country") == "Ukraine");
}

void test_search_url_omits_empty_filters () {    var filters = new Gradio.SearchFilters ();
    filters.country = "Germany";
    filters.state = "Novorossiya";

    string url = Gradio.RadioBrowser.search_url ("radio", 10, filters);
    var query = Soup.Form.decode (url.substring (url.index_of ("?") + 1));

    assert (query.lookup ("country") == "Germany");
    assert (query.lookup ("state") == "Novorossiya");
    assert (query.lookup ("language") == null);
    assert (query.lookup ("tagList") == null);
}

void test_search_filters_trim_values () {
    var filters = new Gradio.SearchFilters ();
    filters.country = "  Germany  ";
    assert (filters.country == "Germany");
    filters.tag = "  jazz, soul ";
    assert (filters.tag == "jazz, soul");
}

void test_filter_list_url () {
    string url = Gradio.RadioBrowser.filter_list_url (Gradio.RadioBrowser.countries_endpoint);
    assert (url.has_prefix (Gradio.RadioBrowser.countries_endpoint + "?"));
    var query = Soup.Form.decode (url.substring (url.index_of ("?") + 1));
    assert (query.lookup ("hidebroken") == "true");
    assert (query.lookup ("order") == "stationcount");
    assert (query.lookup ("reverse") == "true");
}

void test_parse_filter_names () {
    try {
        var names = Gradio.RadioBrowser.parse_names (
            "[{\"name\":\"Germany\",\"stationcount\":10},{\"name\":\" France \"},{\"name\":\"\"}]");
        assert (names.length == 2);
        assert (names[0] == "Germany");
        assert (names[1] == "France");
    } catch (GLib.Error e) {
        assert_not_reached ();
    }
}

void test_parse_filter_names_rejects_non_array () {
    bool threw = false;
    try {
        Gradio.RadioBrowser.parse_names ("{\"name\":\"Germany\"}");
    } catch (GLib.Error e) {
        threw = true;
    }
    assert (threw);
}

void test_station_by_uuid_url () {
    string url = Gradio.RadioBrowser.station_by_uuid_url ("abc-123");
    assert (url == Gradio.RadioBrowser.radio_browser + "/stations/byuuid/abc-123");
}

void test_stations_by_uuid_body () {
    string body = Gradio.RadioBrowser.stations_by_uuid_body ({ "a", "b\"c" });
    assert (body == "{\"uuids\":[\"a\",\"b\\\"c\"]}");
}

void test_vote_url () {    string url = Gradio.RadioBrowser.vote_url ("abc-123");
    assert (url == Gradio.RadioBrowser.radio_browser + "/vote/abc-123");
}

void test_parse_vote_ok () {
    var result = Gradio.RadioBrowser.parse_vote_response (
        "{\"ok\":true,\"message\":\"voted for station successfully\"}");
    assert (result.ok);
    assert (result.station == null);
}

void test_parse_vote_returns_changed_station () {
    var result = Gradio.RadioBrowser.parse_vote_response (
        "{\"stationuuid\":\"u1\",\"name\":\"Jazz FM\",\"url_resolved\":\"https://example.test/jazz\",\"votes\":7}");
    assert (result.ok);
    assert (result.station != null);
    assert (result.station.votes == 7);
}

void test_parse_vote_rejected () {
    var result = Gradio.RadioBrowser.parse_vote_response (
        "{\"ok\":false,\"message\":\"you can only vote once every 10 minutes\"}");
    assert (!result.ok);
}

void test_parse_vote_invalid_json () {
    bool threw = false;
    try {
        Gradio.RadioBrowser.parse_vote_response ("not json");
    } catch (GLib.Error e) {
        threw = true;
    }
    assert (threw);
}

void test_api_url () {
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
    assert (Gradio.RadioBrowser.api_url ("/stations/search") ==
        Gradio.RadioBrowser.radio_browser + "/stations/search");
    Gradio.RadioBrowser.api_base = "https://radio.test/json/";
    assert (Gradio.RadioBrowser.api_url ("/countries") ==
        "https://radio.test/json/countries");

    assert (Gradio.RadioBrowser.api_url ("https://evil.test/json") ==
        "https://evil.test/json");
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
}

void test_search_url_uses_api_base () {
    Gradio.RadioBrowser.api_base = "https://radio.test/json";
    string url = Gradio.RadioBrowser.search_url ("jazz", 5);
    assert (url.has_prefix ("https://radio.test/json/stations/search?"));
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
}

void test_filter_list_url_uses_api_base () {
    Gradio.RadioBrowser.api_base = "https://radio.test/json";
    string url = Gradio.RadioBrowser.filter_list_url (
        Gradio.RadioBrowser.api_url (Gradio.RadioBrowser.countries_path));
    assert (url.has_prefix ("https://radio.test/json/countries?"));
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
}

void test_vote_and_uuid_urls_use_api_base () {
    Gradio.RadioBrowser.api_base = "https://radio.test/json";
    assert (Gradio.RadioBrowser.vote_url ("abc-123") ==
        "https://radio.test/json/vote/abc-123");
    assert (Gradio.RadioBrowser.station_by_uuid_url ("abc-123") ==
        "https://radio.test/json/stations/byuuid/abc-123");
    assert (Gradio.RadioBrowser.click_url ("abc-123") ==
        "https://radio.test/json/url/abc-123");
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
}

void test_server_base_for_host () {
    assert (Gradio.RadioBrowser.server_base_for_host ("de1.api.radio-browser.info") ==
        "https://de1.api.radio-browser.info/json");
    bool threw = false;
    try {
        Gradio.RadioBrowser.server_base_for_host ("  ");
    } catch (GLib.Error e) {
        threw = true;
    }
    assert (threw);
}

void test_ordered_candidates () {
    var result = Gradio.RadioBrowser.ordered_candidates (
        { "b.api", "", "a.api", "b.api", "a.api" });
    assert (result.length == 2);
    assert (result[0] == "b.api");
    assert (result[1] == "a.api");
}

void test_next_candidate () {
    string[] candidates = { "https://a/json", "https://b/json", "https://c/json" };
    assert (Gradio.RadioBrowser.next_candidate ("https://b/json", candidates) ==
        "https://c/json");
    assert (Gradio.RadioBrowser.next_candidate ("https://missing/json", candidates) ==
        "https://a/json");
    assert (Gradio.RadioBrowser.next_candidate ("https://c/json", candidates) == null);
    assert (Gradio.RadioBrowser.next_candidate ("https://a/json", {}) == null);
}

void test_failover_sets_next_base () {
    Gradio.RadioBrowser.api_base = "https://a/json";
    Gradio.RadioBrowser.server_candidates = { "https://a/json", "https://b/json" };
    assert (Gradio.RadioBrowser.failover ());
    assert (Gradio.RadioBrowser.api_base == "https://b/json");
    assert (!Gradio.RadioBrowser.failover ());
    Gradio.RadioBrowser.server_candidates = {};
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
}

void test_locale_parse_region () {
    assert (Gradio.Locale.parse_region ("de_DE.UTF-8") == "DE");
    assert (Gradio.Locale.parse_region ("en_US") == "US");
    assert (Gradio.Locale.parse_region ("pt_BR.UTF-8@latin") == "BR");
    assert (Gradio.Locale.parse_region ("sr-RS") == "RS");
    assert (Gradio.Locale.parse_region ("C") == "");
    assert (Gradio.Locale.parse_region ("uk") == "");
    assert (Gradio.Locale.parse_region ("") == "");
}

void test_locale_region_code_env () {
    string? old_all = GLib.Environment.get_variable ("LC_ALL");
    string? old_lang = GLib.Environment.get_variable ("LANG");
    GLib.Environment.unset_variable ("LC_ALL");
    GLib.Environment.set_variable ("LANG", "de_DE.UTF-8", true);
    assert (Gradio.Locale.region_code () == "DE");
    GLib.Environment.set_variable ("LANG", "C", true);
    assert (Gradio.Locale.region_code () == "US");
    if (old_all != null)
        GLib.Environment.set_variable ("LC_ALL", old_all, true);
    else
        GLib.Environment.unset_variable ("LC_ALL");
    if (old_lang != null)
        GLib.Environment.set_variable ("LANG", old_lang, true);
    else
        GLib.Environment.unset_variable ("LANG");
}

void test_discover_url_popular () {
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
    string url = Gradio.RadioBrowser.discover_url (
        Gradio.DiscoverMode.POPULAR, "DE", Gradio.RadioBrowser.DISCOVER_POPULAR_LIMIT);
    assert (url.has_prefix (Gradio.RadioBrowser.api_url (Gradio.RadioBrowser.search_path) + "?"));
    var query = Soup.Form.decode (url.substring (url.index_of ("?") + 1));
    assert (query.lookup ("order") == "votes");
    assert (query.lookup ("reverse") == "true");
    assert (query.lookup ("countrycode") == "DE");
    assert (query.lookup ("hidebroken") == "true");
    assert (query.lookup ("limit") == "100");
}

void test_discover_url_new () {
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
    string url = Gradio.RadioBrowser.discover_url (
        Gradio.DiscoverMode.NEW, "DE", Gradio.RadioBrowser.DISCOVER_NEW_LIMIT);
    var query = Soup.Form.decode (url.substring (url.index_of ("?") + 1));
    assert (query.lookup ("order") == "random");
    assert (query.lookup ("countrycode") == "DE");
    assert (query.lookup ("limit") == "18");
    assert (query.lookup ("reverse") == null);
}

void test_discover_url_escapes_region () {
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
    string url = Gradio.RadioBrowser.discover_url (
        Gradio.DiscoverMode.POPULAR, "A B", 100);
    string raw = url.substring (url.index_of ("?") + 1);
    assert (!raw.contains ("A B"));
    var query = Soup.Form.decode (raw);
    assert (query.lookup ("countrycode") == "A B");
}

void test_click_url_escapes () {
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
    assert (Gradio.RadioBrowser.click_url ("abc 123") ==
        Gradio.RadioBrowser.radio_browser + "/url/abc%20123");
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
}

void test_should_failover () {
    assert (!Gradio.Http.should_failover (
        new Gradio.HttpError.REQUEST_FAILED ("HTTP 404")));
    assert (Gradio.Http.should_failover (
        new Gradio.HttpError.SERVER_UNAVAILABLE ("HTTP 503")));
    assert (!Gradio.Http.should_failover (new GLib.IOError.CANCELLED ("cancelled")));
    assert (Gradio.Http.should_failover (new GLib.IOError.HOST_NOT_FOUND ("offline")));
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/radio-browser/search_url", test_search_url);
    Test.add_func ("/radio-browser/parse_stations", test_parse_stations);
    Test.add_func ("/radio-browser/parse_empty", test_parse_empty);
    Test.add_func ("/radio-browser/parse_skips_invalid", test_parse_skips_invalid);
    Test.add_func ("/radio-browser/search_url_unicode", test_search_url_unicode);
    Test.add_func ("/radio-browser/search_url_with_filters", test_search_url_with_filters);
    Test.add_func ("/radio-browser/search_url_empty_query_with_filter", test_search_url_empty_query_with_filter);
    Test.add_func ("/radio-browser/search_url_omits_empty_filters", test_search_url_omits_empty_filters);
    Test.add_func ("/radio-browser/search_filters_trim", test_search_filters_trim_values);
    Test.add_func ("/radio-browser/station_by_uuid_url", test_station_by_uuid_url);
    Test.add_func ("/radio-browser/stations_by_uuid_body", test_stations_by_uuid_body);
    Test.add_func ("/radio-browser/filter_list_url", test_filter_list_url);
    Test.add_func ("/radio-browser/parse_filter_names", test_parse_filter_names);
    Test.add_func ("/radio-browser/parse_filter_names_invalid",
        test_parse_filter_names_rejects_non_array);
    Test.add_func ("/radio-browser/vote_url", test_vote_url);
    Test.add_func ("/radio-browser/parse_vote_ok", test_parse_vote_ok);
    Test.add_func ("/radio-browser/parse_vote_station", test_parse_vote_returns_changed_station);
    Test.add_func ("/radio-browser/parse_vote_rejected", test_parse_vote_rejected);
    Test.add_func ("/radio-browser/parse_vote_invalid", test_parse_vote_invalid_json);
    Test.add_func ("/radio-browser/api_url", test_api_url);
    Test.add_func ("/radio-browser/search_url_uses_api_base", test_search_url_uses_api_base);
    Test.add_func ("/radio-browser/filter_list_url_uses_api_base", test_filter_list_url_uses_api_base);
    Test.add_func ("/radio-browser/vote_uuid_urls_use_api_base", test_vote_and_uuid_urls_use_api_base);
    Test.add_func ("/radio-browser/server_base_for_host", test_server_base_for_host);
    Test.add_func ("/radio-browser/ordered_candidates", test_ordered_candidates);
    Test.add_func ("/radio-browser/next_candidate", test_next_candidate);
    Test.add_func ("/radio-browser/failover", test_failover_sets_next_base);
    Test.add_func ("/radio-browser/locale_parse_region", test_locale_parse_region);
    Test.add_func ("/radio-browser/locale_region_code", test_locale_region_code_env);
    Test.add_func ("/radio-browser/discover_url_popular", test_discover_url_popular);
    Test.add_func ("/radio-browser/discover_url_new", test_discover_url_new);
    Test.add_func ("/radio-browser/discover_url_escapes_region", test_discover_url_escapes_region);
    Test.add_func ("/radio-browser/click_url_escapes", test_click_url_escapes);
    Test.add_func ("/radio-browser/should_failover", test_should_failover);

    return Test.run ();
}
