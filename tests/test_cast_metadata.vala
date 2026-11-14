// SPDX-License-Identifier: GPL-3.0-or-later

using Soup;

uint8[] make_metadata (string title) {
    string raw = "StreamTitle='%s';".printf (title);
    int slots = (raw.length + 15) / 16;
    if (slots < 1)
        slots = 1;
    var payload = new uint8[slots * 16];
    for (int i = 0; i < raw.length; i++)
        payload[i] = (uint8) raw[i];
    return payload;
}

uint8[] make_latin1_metadata () {
    string prefix = "StreamTitle='Caf";
    string suffix = "';";
    var payload = new uint8[32];
    int pos = 0;
    for (int i = 0; i < prefix.length; i++)
        payload[pos++] = (uint8) prefix[i];
    payload[pos++] = 0xE9;
    for (int i = 0; i < suffix.length; i++)
        payload[pos++] = (uint8) suffix[i];
    return payload;
}

uint8[] make_stream_body (string title) {
    var metadata = make_metadata (title);
    var body = new uint8[16 + 1 + metadata.length];
    for (int i = 0; i < 16; i++)
        body[i] = 0x41;
    body[16] = (uint8) (metadata.length / 16);
    for (int i = 0; i < metadata.length; i++)
        body[17 + i] = metadata[i];
    return body;
}

void test_parse_title () {
    assert (Gradio.CastMetadataPoller.parse_stream_title (
        make_metadata ("Artist - Song")) == "Artist - Song");
}

void test_parse_title_with_apostrophe () {
    assert (Gradio.CastMetadataPoller.parse_stream_title (
        make_metadata ("Guns N' Roses - November Rain")) ==
        "Guns N' Roses - November Rain");
}

void test_parse_utf8_title () {
    assert (Gradio.CastMetadataPoller.parse_stream_title (
        make_metadata ("Кино - Звезда")) == "Кино - Звезда");
}

void test_parse_empty_title () {
    assert (Gradio.CastMetadataPoller.parse_stream_title (
        make_metadata ("")) == "");
}

void test_parse_missing_marker () {
    var payload = new uint8[16];
    assert (Gradio.CastMetadataPoller.parse_stream_title (payload) == "");
}

void test_parse_latin1_title () {
    assert (Gradio.CastMetadataPoller.parse_stream_title (
        make_latin1_metadata ()) == "Café");
}

class PollerFixture : GLib.Object {
    public Soup.Server server;
    public int requests = 0;
    public string base_url = "";

    public PollerFixture () throws GLib.Error {
        server = (Soup.Server) GLib.Object.new (typeof (Soup.Server));
        server.add_handler ("/stream", (srv, msg, path, query) => {
            requests++;
            var body = make_stream_body ("Title %d".printf (requests));
            msg.set_status (200, null);
            msg.get_response_headers ().append ("icy-metaint", "16");
            msg.set_response ("audio/mpeg", Soup.MemoryUse.COPY, body);
        });
        server.listen_local (0, 0);
        var uri = server.get_uris ().nth_data (0);
        base_url = "http://%s:%d".printf (uri.get_host (), uri.get_port ());
    }
}

void test_poller_emits_titles () {
    // Real socket + wall-clock test: opt in with GRADIO_INTEGRATION_TESTS=1.
    // The default suite only runs the deterministic parse tests above.
    if (GLib.Environment.get_variable ("GRADIO_INTEGRATION_TESTS") == null)
        return;
    PollerFixture? fixture = null;
    try {
        fixture = new PollerFixture ();
    } catch (GLib.Error e) {
        assert_not_reached ();
    }
    assert (fixture != null);

    var poller = new Gradio.CastMetadataPoller ();
    poller.interval_seconds = 1;
    var titles = new GLib.GenericArray<string> ();
    var loop = new GLib.MainLoop ();
    poller.title_changed.connect ((title) => {
        titles.add (title);
        if (titles.length >= 2)
            loop.quit ();
    });
    poller.start (fixture.base_url + "/stream");
    assert (poller.active);

    uint timeout_id = 0;
    timeout_id = GLib.Timeout.add_seconds (4, () => {
        timeout_id = 0;
        loop.quit ();
        return false;
    });
    loop.run ();
    poller.stop ();
    assert (!poller.active);
    if (timeout_id != 0)
        GLib.Source.remove (timeout_id);

    assert (titles.length >= 2);
    assert (fixture.requests >= 2);
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/cast-metadata/parse_title", test_parse_title);
    Test.add_func ("/cast-metadata/parse_title_apostrophe",
        test_parse_title_with_apostrophe);
    Test.add_func ("/cast-metadata/parse_utf8", test_parse_utf8_title);
    Test.add_func ("/cast-metadata/parse_empty", test_parse_empty_title);
    Test.add_func ("/cast-metadata/parse_missing_marker",
        test_parse_missing_marker);
    Test.add_func ("/cast-metadata/parse_latin1", test_parse_latin1_title);
    Test.add_func ("/cast-metadata/poller_emits_titles",
        test_poller_emits_titles);

    return Test.run ();
}
