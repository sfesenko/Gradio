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

void test_manual_keeps_order () {
    var sorted = StationSort.sort_library (make_stations (), LibrarySortMode.MANUAL);
    assert (sorted.get (0).name == "Beta");
    assert (sorted.get (1).name == "alpha");
    assert (sorted.get (2).name == "Gamma");
}

void test_library_name_sort_is_case_insensitive () {
    var sorted = StationSort.sort_library (make_stations (), LibrarySortMode.NAME);
    assert (sorted.get (0).name == "alpha");
    assert (sorted.get (1).name == "Beta");
    assert (sorted.get (2).name == "Gamma");
}

void test_library_country_sort_ties_by_name () {
    var stations = new GLib.GenericArray<RadioStation> ();
    stations.add (make_station ("Zulu", "Ukraine", 128));
    stations.add (make_station ("Alpha", "Ukraine", 64));
    stations.add (make_station ("Mike", "Austria", 96));

    var sorted = StationSort.sort_library (stations, LibrarySortMode.COUNTRY);
    assert (sorted.get (0).name == "Mike");
    assert (sorted.get (1).name == "Alpha");
    assert (sorted.get (2).name == "Zulu");
}

void test_library_bitrate_sort_is_descending () {
    var sorted = StationSort.sort_library (make_stations (), LibrarySortMode.BITRATE);
    assert (sorted.get (0).name == "Gamma");
    assert (sorted.get (1).name == "Beta");
    assert (sorted.get (2).name == "alpha");
}

void test_library_sort_does_not_change_source () {
    var source = make_stations ();
    StationSort.sort_library (source, LibrarySortMode.NAME);
    assert (source.get (0).name == "Beta");
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
    assert (StationSort.library_from_string (StationSort.library_to_string (LibrarySortMode.NAME)) ==
        LibrarySortMode.NAME);
    assert (StationSort.library_from_string ("bogus") == LibrarySortMode.MANUAL);
    assert (StationSort.search_from_string (StationSort.search_to_string (SearchSortMode.VOTES)) ==
        SearchSortMode.VOTES);
    assert (StationSort.search_from_string ("bogus") == SearchSortMode.RELEVANCE);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/station-sort/manual", test_manual_keeps_order);
    Test.add_func ("/station-sort/name", test_library_name_sort_is_case_insensitive);
    Test.add_func ("/station-sort/country", test_library_country_sort_ties_by_name);
    Test.add_func ("/station-sort/bitrate", test_library_bitrate_sort_is_descending);
    Test.add_func ("/station-sort/source_unchanged", test_library_sort_does_not_change_source);
    Test.add_func ("/station-sort/search_relevance", test_search_relevance_keeps_api_order);
    Test.add_func ("/station-sort/search_clicks", test_search_clicks_sort_is_descending);
    Test.add_func ("/station-sort/search_votes", test_search_votes_sort_is_descending);
    Test.add_func ("/station-sort/search_bitrate", test_search_bitrate_sort_is_descending);
    Test.add_func ("/station-sort/mode_conversion", test_mode_conversion_round_trips);
    return Test.run ();
}
