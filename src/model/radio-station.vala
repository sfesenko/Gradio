// SPDX-License-Identifier: GPL-3.0-or-later

using Json;

namespace Gradio {

    public class RadioStation {
        public string id = "";
        public string name = "";
        public string url = "";
        public string original_url = "";
        public string favicon = "";
        public string country = "";
        public string countrycode = "";
        public string state = "";
        public string language = "";
        public string tags = "";
        public string codec = "";
        public int bitrate = 0;
        public string homepage = "";
        public bool broken = false;
        public bool orphaned = false;
        public bool is_local = false;
        public int votes = 0;
        public int clickcount = 0;

        public static RadioStation? from_json_object (Json.Object obj) {
            string id = string_member (obj, "stationuuid");
            string name = string_member (obj, "name");
            if (id == "" && name == "")
                return null;

            var station = new RadioStation ();
            station.id = id;
            station.name = name;
            station.original_url = string_member (obj, "url");
            station.url = string_member (obj, "url_resolved");
            if (station.url == "")
                station.url = station.original_url;
            if (station.original_url == "")
                station.original_url = station.url;
            station.favicon = string_member (obj, "favicon");
            station.country = string_member (obj, "country");
            station.countrycode = string_member (obj, "countrycode");
            station.state = string_member (obj, "state");
            station.is_local = obj.get_boolean_member_with_default ("local", false);
            station.orphaned = obj.get_boolean_member_with_default ("orphaned", false);
            station.language = string_member (obj, "language");
            station.tags = string_member (obj, "tags");
            station.codec = string_member (obj, "codec");
            station.bitrate = int_member (obj, "bitrate");
            station.homepage = string_member (obj, "homepage");
            station.votes = int_member (obj, "votes");
            station.clickcount = int_member (obj, "clickcount");
            station.broken = obj.has_member ("lastcheckok") && int_member (obj, "lastcheckok") == 0;
            return station;
        }

        public Json.Node to_json_node () {
            var obj = new Json.Object ();
            obj.set_string_member ("stationuuid", id);
            obj.set_string_member ("name", name);
            obj.set_string_member ("url", original_url != "" ? original_url : url);
            obj.set_string_member ("url_resolved", url);
            obj.set_string_member ("favicon", favicon);
            obj.set_string_member ("country", country);
            obj.set_string_member ("countrycode", countrycode);
            obj.set_string_member ("state", state);
            obj.set_boolean_member ("local", is_local);
            obj.set_boolean_member ("orphaned", orphaned);
            obj.set_string_member ("language", language);
            obj.set_string_member ("tags", tags);
            obj.set_string_member ("codec", codec);
            obj.set_int_member ("bitrate", bitrate);
            obj.set_string_member ("homepage", homepage);
            obj.set_int_member ("votes", votes);
            obj.set_int_member ("clickcount", clickcount);
            obj.set_int_member ("lastcheckok", broken ? 0 : 1);

            var node = new Json.Node (Json.NodeType.OBJECT);
            node.set_object (obj);
            return node;
        }

        public static string new_local_id () {
            return "local-" + GLib.Uuid.string_random ();
        }

        public RadioStation copy () {
            var result = new RadioStation ();
            result.id = id;
            result.name = name;
            result.url = url;
            result.original_url = original_url;
            result.favicon = favicon;
            result.country = country;
            result.countrycode = countrycode;
            result.state = state;
            result.language = language;
            result.tags = tags;
            result.codec = codec;
            result.bitrate = bitrate;
            result.homepage = homepage;
            result.broken = broken;
            result.orphaned = orphaned;
            result.is_local = is_local;
            result.votes = votes;
            result.clickcount = clickcount;
            return result;
        }

        public string[] stream_urls () {
            if (url == "") {
                string[] only = {};
                if (original_url != "")
                    only += original_url;
                return only;
            }
            if (original_url == "" || original_url == url)
                return { url };
            return { original_url, url };
        }

        public string stream_signature () {
            string[] urls = stream_urls ();
            return string.joinv ("\x1f", urls) + "\x1e" + tech_info ();
        }

        public string tech_info () {
            if (codec != "" && bitrate > 0)
                return "%s %d kbit/s".printf (codec, bitrate);
            if (codec != "")
                return codec;
            if (bitrate > 0)
                return "%d kbit/s".printf (bitrate);
            return "";
        }

        public string secondary_text (bool show_technical_info) {
            if (!show_technical_info)
                return country;

            string tech = tech_info ();
            if (country == "")
                return tech;
            if (tech == "")
                return country;
            return "%s • %s".printf (country, tech);
        }

        private static string string_member (Json.Object obj, string name) {
            if (!obj.has_member (name))
                return "";
            var node = obj.get_member (name);
            if (node == null)
                return "";
            if (node.get_value_type () == typeof (string))
                return node.get_string () ?? "";
            return "";
        }

        private static int int_member (Json.Object obj, string name) {
            if (!obj.has_member (name))
                return 0;
            var node = obj.get_member (name);
            if (node == null)
                return 0;

            GLib.Type type = node.get_value_type ();
            if (type == typeof (int64))
                return (int) node.get_int ();
            if (type == typeof (double))
                return (int) node.get_double ();
            if (type == typeof (string)) {
                int value;
                if (int.try_parse (node.get_string () ?? "", out value))
                    return value;
            }
            return 0;
        }
    }
}
