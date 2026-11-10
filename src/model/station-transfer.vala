// SPDX-License-Identifier: GPL-3.0-or-later

using Json;

namespace Gradio {

    public class ImportSummary : GLib.Object {
        public int imported = 0;
        public int skipped = 0;
    }

    // Station list import/export. Accepts either a plain station array (what
    // this app exports) or a full config object with a "stations" array.
    public class StationTransfer {
        public static GLib.GenericArray<RadioStation> parse (string json) throws GLib.Error {
            var parser = new Json.Parser ();
            parser.load_from_data (json);
            var root = parser.get_root ();
            if (root == null)
                throw new GLib.FileError.FAILED ("invalid station file");

            Json.Array? array = null;
            if (root.get_value_type () == typeof (Json.Array)) {
                array = root.get_array ();
            } else if (root.get_value_type () == typeof (Json.Object)) {
                var object = root.get_object ();
                if (object.has_member ("stations")) {
                    var node = object.get_member ("stations");
                    if (node != null && node.get_value_type () == typeof (Json.Array))
                        array = node.get_array ();
                }
            }
            if (array == null)
                throw new GLib.FileError.FAILED ("no stations found");

            var stations = new GLib.GenericArray<RadioStation> ();
            for (uint i = 0; i < array.get_length (); i++) {
                var element = array.get_element (i);
                if (element == null || element.get_value_type () != typeof (Json.Object))
                    continue;
                var station = RadioStation.from_json_object (element.get_object ());
                if (station == null || station.id == "" || station.name == "" || station.url == "")
                    continue;
                // Imported lists are user-owned unless the file explicitly says
                // the entry came from radio-browser (`"local": false`). Otherwise
                // a third-party URL would later be refreshed and flagged
                // unavailable for an id radio-browser does not know.
                if (!element.get_object ().has_member ("local"))
                    station.is_local = true;
                stations.add (station);
            }
            return stations;
        }

        // Standard M3U playlist: one #EXTINF line per station followed by its
        // stream URL. Station names are collapsed to a single line so they
        // cannot break the playlist format.
        public static string export_m3u (GLib.GenericArray<RadioStation> stations) {
            var builder = new GLib.StringBuilder ("#EXTM3U\n");
            for (uint i = 0; i < stations.length; i++) {
                var station = stations.get (i);
                if (station.url == "")
                    continue;
                builder.append_printf ("#EXTINF:-1,%s\n%s\n", m3u_text (station.name), station.url);
            }
            return builder.str;
        }

        public static string m3u_text (string text) {
            return text.replace ("\r", " ").replace ("\n", " ").strip ();
        }

        public static string export_json (GLib.GenericArray<RadioStation> stations) {
            var array = new Json.Array ();
            for (uint i = 0; i < stations.length; i++)
                array.add_element (stations.get (i).to_json_node ());

            var node = new Json.Node (Json.NodeType.ARRAY);
            node.set_array (array);

            var generator = new Json.Generator ();
            generator.set_root (node);
            generator.set_pretty (true);
            size_t length;
            return generator.to_data (out length);
        }
    }
}
