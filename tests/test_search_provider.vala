// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

RadioStation make_station (string id, string name, string country) {
    var station = new RadioStation ();
    station.id = id;
    station.name = name;
    station.country = country;
    station.url = "https://example.test/" + id;
    return station;
}

AppConfig make_config () {
    var config = new AppConfig ("/tmp/gradio-search-provider-test.json");
    config.add_station (make_station ("u1", "Jazz FM", "Germany"));
    config.add_station (make_station ("u2", "Rock Radio", "France"));
    config.add_station (make_station ("u3", "Smooth Jazz Lounge", "Germany"));
    return config;
}

void test_match_by_name () {
    var ids = SearchProvider.match_ids (make_config (), { "jazz" });
    assert (ids.length == 2);
    assert (ids[0] == "u1");
    assert (ids[1] == "u3");
}

void test_match_is_case_insensitive () {
    var ids = SearchProvider.match_ids (make_config (), { "ROCK" });
    assert (ids.length == 1);
    assert (ids[0] == "u2");
}

void test_match_requires_all_terms () {
    var ids = SearchProvider.match_ids (make_config (), { "jazz", "lounge" });
    assert (ids.length == 1);
    assert (ids[0] == "u3");
}

void test_match_no_terms () {
    var ids = SearchProvider.match_ids (make_config (), {});
    assert (ids.length == 0);
}

void test_match_ignores_country () {
    var ids = SearchProvider.match_ids (make_config (), { "Germany" });
    assert (ids.length == 0);
}

void test_result_meta () {
    var meta = SearchProvider.result_meta (make_station ("u1", "Jazz FM", "Germany"));
    assert (meta.lookup ("id").get_string () == "u1");
    assert (meta.lookup ("name").get_string () == "Jazz FM");
    assert (meta.lookup ("description").get_string () == "Germany");
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/search-provider/match_name", test_match_by_name);
    Test.add_func ("/search-provider/match_case", test_match_is_case_insensitive);
    Test.add_func ("/search-provider/match_terms", test_match_requires_all_terms);
    Test.add_func ("/search-provider/match_empty", test_match_no_terms);
    Test.add_func ("/search-provider/match_country", test_match_ignores_country);
    Test.add_func ("/search-provider/result_meta", test_result_meta);

    return Test.run ();
}
