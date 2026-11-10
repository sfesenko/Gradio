// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

Gradio.AppConfig make_config () {
    return new Gradio.AppConfig ("/tmp/gradio-validation-test.json");
}

void test_accepts_valid_station () {
    var config = make_config ();
    assert (StationValidation.validate ("Jazz", "https://example.test/jazz", "", config) == null);
}

void test_rejects_empty_name () {
    var config = make_config ();
    assert (StationValidation.validate ("  ", "https://example.test/jazz", "", config) != null);
}

void test_rejects_invalid_url () {
    var config = make_config ();
    assert (StationValidation.validate ("Jazz", "not a url", "", config) != null);
    assert (StationValidation.validate ("Jazz", "ftp://example.test/x", "", config) != null);
}

void test_rejects_invalid_homepage () {
    var config = make_config ();
    assert (StationValidation.validate ("Jazz", "https://example.test/jazz",
        "nope", config) != null);
}

void test_rejects_duplicate_url () {
    var config = make_config ();
    var existing = new RadioStation ();
    existing.id = "u1";
    existing.name = "Existing";
    existing.url = "https://example.test/jazz";
    config.add_station (existing);

    assert (StationValidation.validate ("Jazz", "https://example.test/jazz", "", config) != null);
    assert (StationValidation.validate ("Jazz", "https://example.test/jazz", "", config, "u1") == null);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/station-validation/valid", test_accepts_valid_station);
    Test.add_func ("/station-validation/name", test_rejects_empty_name);
    Test.add_func ("/station-validation/url", test_rejects_invalid_url);
    Test.add_func ("/station-validation/homepage", test_rejects_invalid_homepage);
    Test.add_func ("/station-validation/duplicate", test_rejects_duplicate_url);
    return Test.run ();
}
