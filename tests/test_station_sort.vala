// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

RadioStation make_station (string name, string country, int bitrate, int clicks = 0, int votes = 0) {
    var station = new RadioStation ();
    station.id = name + "-" + country;
    station.name = name;
    station.country = country;
    station.bitrate = bitrate;
    station.clickcount = clicks;
    station.votes = votes;
    station.url = "https://example.test/" + station.id;
    return station;
}

GLib.GenericArray<RadioStation> make_stations () {
    var stations = new GLib.GenericArray<RadioStation> ();
    stations.add (make_station ("Beta", "Ukraine", 128, 10, 2));
    stations.add (make_station ("alpha", "Germany", 64, 30, 1));
    stations.add (make_station ("Gamma", "Austria", 256, 20, 5));
    return stations;
}

void test_search_relevance_keeps_api_order () {
    var sorted = StationSort.sort_search (make_stations (), SearchSortMode.RELEVANCE);
    assert (sorted.get (0).name == "Beta");
    assert (sorted.get (2).name == "Gamma");
}

void test_search_clicks_sort_is_descending () {
    var sorted = StationSort.sort_search (make_stations (), SearchSortMode.CLICKS);
    assert (sorted.get (0).name == "alpha");
    assert (sorted.get (1).name == "Gamma");
    assert (sorted.get (2).name == "Beta");
}

void test_search_votes_sort_is_descending () {
    var sorted = StationSort.sort_search (make_stations (), SearchSortMode.VOTES);
    assert (sorted.get (0).name == "Gamma");
    assert (sorted.get (1).name == "Beta");
    assert (sorted.get (2).name == "alpha");
}

void test_search_bitrate_sort_is_descending () {
    var sorted = StationSort.sort_search (make_stations (), SearchSortMode.BITRATE);
    assert (sorted.get (0).name == "Gamma");
    assert (sorted.get (1).name == "Beta");
    assert (sorted.get (2).name == "alpha");
}

void test_mode_conversion_round_trips () {
    assert (StationSort.search_from_string (StationSort.search_to_string (SearchSortMode.VOTES)) ==
        SearchSortMode.VOTES);
    assert (StationSort.search_from_string ("bogus") == SearchSortMode.RELEVANCE);
}

RadioStation station_with (string id, string name, string country,
        string state, string language, int bitrate) {
    var station = new RadioStation ();
    station.id = id;
    station.name = name;
    station.country = country;
    station.state = state;
    station.language = language;
    station.bitrate = bitrate;
    return station;
}

void test_library_sort_custom_preserves_order () {
    var stations = new GLib.GenericArray<RadioStation> ();
    stations.add (station_with ("b", "Beta", "DE", "", "german", 128));
    stations.add (station_with ("a", "Alpha", "AT", "", "german", 64));

    var sorted = StationSort.sort_library (stations, LibrarySortMode.CUSTOM, false);
    assert (sorted.get (0).id == "b");
    assert (sorted.get (1).id == "a");
}

void test_library_sort_name_ascending_and_descending () {
    var stations = new GLib.GenericArray<RadioStation> ();
    stations.add (station_with ("b", "beta", "DE", "", "german", 128));
    stations.add (station_with ("a", "Alpha", "AT", "", "german", 64));

    var asc = StationSort.sort_library (stations, LibrarySortMode.NAME, false);
    assert (asc.get (0).id == "a");
    assert (asc.get (1).id == "b");

    var desc = StationSort.sort_library (stations, LibrarySortMode.NAME, true);
    assert (desc.get (0).id == "b");
    assert (desc.get (1).id == "a");
}

void test_library_sort_country_state_language_bitrate () {
    var stations = new GLib.GenericArray<RadioStation> ();
    stations.add (station_with ("b", "Beta", "DE", "Bavaria", "german", 128));
    stations.add (station_with ("a", "Alpha", "AT", "Vienna", "english", 64));

    assert (StationSort.sort_library (stations, LibrarySortMode.COUNTRY, false).get (0).id == "a");
    assert (StationSort.sort_library (stations, LibrarySortMode.STATE, false).get (0).id == "b");
    assert (StationSort.sort_library (stations, LibrarySortMode.LANGUAGE, false).get (0).id == "a");
    assert (StationSort.sort_library (stations, LibrarySortMode.BITRATE, false).get (0).id == "a");
    assert (StationSort.sort_library (stations, LibrarySortMode.BITRATE, true).get (0).id == "b");
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/station-sort/search_relevance", test_search_relevance_keeps_api_order);
    Test.add_func ("/station-sort/search_clicks", test_search_clicks_sort_is_descending);
    Test.add_func ("/station-sort/search_votes", test_search_votes_sort_is_descending);
    Test.add_func ("/station-sort/search_bitrate", test_search_bitrate_sort_is_descending);
    Test.add_func ("/station-sort/mode_conversion", test_mode_conversion_round_trips);
    Test.add_func ("/station-sort/library_custom", test_library_sort_custom_preserves_order);
    Test.add_func ("/station-sort/library_name", test_library_sort_name_ascending_and_descending);
    Test.add_func ("/station-sort/library_fields", test_library_sort_country_state_language_bitrate);
    return Test.run ();
}
