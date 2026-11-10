// SPDX-License-Identifier: GPL-3.0-or-later

using Soup;

class HttpFixture : GLib.Object {
    private Soup.Server server;
    private Soup.Session session;
    private GLib.MainLoop loop;
    private string base_url;

    public HttpFixture () throws GLib.Error {
        server = (Soup.Server) GLib.Object.new (typeof (Soup.Server));
        session = new Soup.Session ();
        loop = new GLib.MainLoop ();

        server.add_handler ("/ok", (srv, msg, path, query) => {
            msg.set_status (200, null);
            msg.set_response ("text/plain", Soup.MemoryUse.COPY, "hello".data);
        });
        server.add_handler ("/missing", (srv, msg, path, query) => {
            msg.set_status (404, "Not Found");
            msg.set_response ("text/plain", Soup.MemoryUse.COPY, "no".data);
        });
        server.add_handler ("/hang", (srv, msg, path, query) => {
            srv.pause_message (msg);
        });
        server.add_handler ("/echo", (srv, msg, path, query) => {
            var body = msg.get_request_body ();
            var bytes = body != null ? body.flatten () : new GLib.Bytes (new uint8[0]);
            msg.set_status (200, null);
            msg.set_response ("application/json", Soup.MemoryUse.COPY, bytes.get_data ());
        });

        server.listen_local (0, 0);
        var uri = server.get_uris ().nth_data (0);
        base_url = "http://%s:%d".printf (uri.get_host (), uri.get_port ());
    }

    private async string fetch (string path) throws GLib.Error {
        return yield Gradio.Http.get_string_async (session, base_url + path, null);
    }

    private async string fetch_url (string url) throws GLib.Error {
        return yield Gradio.Http.get_string_async (session, url, null);
    }

    public void test_get_ok () {
        string? result = null;
        GLib.Error? error = null;

        fetch.begin ("/ok", (obj, res) => {
            try {
                result = fetch.end (res);
            } catch (GLib.Error e) {
                error = e;
            }
            loop.quit ();
        });
        loop.run ();

        assert (error == null);
        assert_cmpstr (result, CompareOperator.EQ, "hello");
    }

    public void test_get_missing () {
        GLib.Error? error = null;

        fetch.begin ("/missing", (obj, res) => {
            try {
                fetch.end (res);
            } catch (GLib.Error e) {
                error = e;
            }
            loop.quit ();
        });
        loop.run ();

        assert (error != null);
        assert (error.message.contains ("404"));
    }

    public void test_url_with_query () {
        var query = new GLib.HashTable<string,string> (str_hash, str_equal);
        query.insert ("q", "rock");

        assert_cmpstr (Gradio.Http.url_with_query ("https://example.test/search", query),
            CompareOperator.EQ, "https://example.test/search?q=rock");
        assert_cmpstr (Gradio.Http.url_with_query ("https://example.test/search?x=1", query),
            CompareOperator.EQ, "https://example.test/search?x=1&q=rock");
    }

    public void test_url_validation () {
        assert (!Gradio.Http.is_valid_url (""));
        assert (!Gradio.Http.is_valid_url ("not a url"));
        assert (!Gradio.Http.is_valid_url ("http://"));
        assert (!Gradio.Http.is_valid_url ("http:///path"));
        assert (!Gradio.Http.is_valid_url ("http://:80/"));
        assert (!Gradio.Http.is_valid_url ("http://exa mple.com/"));
        assert (!Gradio.Http.is_valid_url ("file:///etc/passwd"));
        assert (Gradio.Http.is_valid_url ("https://example.test/x"));
        assert (Gradio.Http.is_valid_url ("  https://example.test/x  "));
    }

    public void test_invalid_url_fetch () {
        string[] urls = { "", "not a url", "http://", "http:///path",
            "http://:80/", "http://exa mple.com/", "file:///etc/passwd" };

        foreach (var url in urls) {
            GLib.Error? error = null;

            fetch_url.begin (url, (obj, res) => {
                try {
                    fetch_url.end (res);
                } catch (GLib.Error e) {
                    error = e;
                }
                loop.quit ();
            });
            loop.run ();

            assert (error != null);
        }
    }

    public void test_url_whitespace () {
        string? result = null;
        GLib.Error? error = null;

        fetch_url.begin ("  " + base_url + "/ok  ", (obj, res) => {
            try {
                result = fetch_url.end (res);
            } catch (GLib.Error e) {
                error = e;
            }
            loop.quit ();
        });
        loop.run ();

        assert (error == null);
        assert_cmpstr (result, CompareOperator.EQ, "hello");
    }

    public void test_request_timeout () {
        var timeout_session = new Soup.Session ();
        timeout_session.timeout = 1;
        GLib.Error? error = null;

        Gradio.Http.get_string_async.begin (timeout_session, base_url + "/hang", null, (obj, res) => {
            try {
                Gradio.Http.get_string_async.end (res);
            } catch (GLib.Error e) {
                error = e;
            }
            loop.quit ();
        });
        loop.run ();

        assert (error != null);
    }

    public void test_post_echo () {
        string? result = null;
        GLib.Error? error = null;

        Gradio.Http.post_string_async.begin (session, base_url + "/echo",
            "{\"uuids\":[\"a\"]}", "application/json", null, (obj, res) => {
                try {
                    result = Gradio.Http.post_string_async.end (res);
                } catch (GLib.Error e) {
                    error = e;
                }
                loop.quit ();
            });
        loop.run ();

        assert (error == null);
        assert_cmpstr (result, CompareOperator.EQ, "{\"uuids\":[\"a\"]}");
    }

    public void test_bytes_to_string () {
        uint8[] data = { 'a', 'b', 'c' };
        var bytes = new GLib.Bytes (data);
        assert_cmpstr (Gradio.Http.bytes_to_string (bytes), CompareOperator.EQ, "abc");
    }
}

delegate void Runner (HttpFixture fixture);

void run_fixture (owned Runner runner) {
    try {
        var fixture = new HttpFixture ();
        runner (fixture);
    } catch (GLib.Error e) {
        GLib.Test.message ("setup failed: %s", e.message);
        assert_not_reached ();
    }
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/http/get_ok", () => run_fixture ((fixture) => fixture.test_get_ok ()));
    Test.add_func ("/http/get_missing", () => run_fixture ((fixture) => fixture.test_get_missing ()));
    Test.add_func ("/http/url_with_query", () => run_fixture ((fixture) => fixture.test_url_with_query ()));
    Test.add_func ("/http/url_validation", () => run_fixture ((fixture) => fixture.test_url_validation ()));
    Test.add_func ("/http/invalid_url_fetch", () => run_fixture ((fixture) => fixture.test_invalid_url_fetch ()));
    Test.add_func ("/http/url_whitespace", () => run_fixture ((fixture) => fixture.test_url_whitespace ()));
    Test.add_func ("/http/bytes_to_string", () => run_fixture ((fixture) => fixture.test_bytes_to_string ()));
    Test.add_func ("/http/request_timeout", () => run_fixture ((fixture) => fixture.test_request_timeout ()));
    Test.add_func ("/http/post_echo", () => run_fixture ((fixture) => fixture.test_post_echo ()));

    return Test.run ();
}
