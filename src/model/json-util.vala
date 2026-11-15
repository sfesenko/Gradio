// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {
    // Best-effort helpers for untrusted input: object_from() returns null on
    // bad JSON or a non-object root and callers ignore that frame. Config and
    // station-transfer parsing keep their explicit errors instead.
    public class JsonUtil {
        public static Json.Object? object_from (string json) {
            var parser = new Json.Parser ();
            try {
                parser.load_from_data (json, -1);
            } catch (GLib.Error e) {
                return null;
            }
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT)
                return null;
            return root.get_object ();
        }

        public static string string_member (Json.Object obj, string name) {
            if (!obj.has_member (name))
                return "";
            var node = obj.get_member (name);
            if (node == null || node.get_value_type () != typeof (string))
                return "";
            return node.get_string () ?? "";
        }

        public static Json.Object? object_member (Json.Object obj, string name) {
            if (!obj.has_member (name))
                return null;
            var node = obj.get_member (name);
            if (node == null || node.get_node_type () != Json.NodeType.OBJECT)
                return null;
            return node.get_object ();
        }

        // Cast payloads often omit or mistype members; get_array_member() would
        // emit a GLib critical.
        public static Json.Array? array_member (Json.Object obj, string name) {
            if (!obj.has_member (name))
                return null;
            var node = obj.get_member (name);
            if (node == null || node.get_node_type () != Json.NodeType.ARRAY)
                return null;
            return node.get_array ();
        }

        public static int int_member (Json.Object obj, string name) {
            if (!obj.has_member (name))
                return 0;
            var node = obj.get_member (name);
            if (node == null)
                return 0;
            var type = node.get_value_type ();
            if (type == typeof (int64)) {
                int64 value = node.get_int ();
                if (value < (int64) int.MIN || value > (int64) int.MAX)
                    return 0;
                return (int) value;
            }
            if (type == typeof (double)) {
                double value = node.get_double ();
                if (value != value) // NaN
                    return 0;
                if (value < (double) int.MIN || value > (double) int.MAX)
                    return 0;
                return (int) value;
            }
            if (type == typeof (string)) {
                int value;
                if (int.try_parse (node.get_string () ?? "", out value))
                    return value;
            }
            return 0;
        }
    }
}