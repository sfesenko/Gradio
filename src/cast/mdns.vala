// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {
    public class Mdns {
        public static string? read_name (uint8[] data, int offset) {
            if (offset < 0 || offset >= data.length)
                return null;
            var labels = new string[] {};
            int pos = offset;
            int guard = 0;
            while (pos < data.length && guard++ < 64) {
                int len = data[pos];
                if (len == 0)
                    break;
                if (pos + 1 >= data.length)
                    return null;
                if ((len & 0xC0) == 0xC0) {
                    if (pos + 1 >= data.length)
                        return null;
                    int pointer = ((len & 0x3F) << 8) | data[pos + 1];
                    if (pointer >= data.length || pointer >= offset)
                        return null;
                    var suffix = read_name (data, pointer);
                    if (suffix == null)
                        return null;
                    if (labels.length == 0)
                        return suffix;
                    return string.joinv (".", { string.joinv (".", labels), suffix });
                }

                if (pos + 1 + len > data.length)
                    return null;
                var label = Mdns.bytes_to_string (data, pos + 1, len);
                labels += label;
                pos += 1 + len;
            }
            return string.joinv (".", labels);
        }

        public static GLib.GenericArray<MdnsRecord> parse_message (uint8[] data) {
            if (data.length < 12)
                return null;
            var records = new GLib.GenericArray<MdnsRecord> ();
            int qd = (data[4] << 8) | data[5];
            int an = (data[6] << 8) | data[7];
            int ns = (data[8] << 8) | data[9];
            int ar = (data[10] << 8) | data[11];
            if (qd < 0 || qd > 64 || an < 0 || an > 512 ||
                    ns < 0 || ns > 512 || ar < 0 || ar > 512)
                return null;

            int pos = 12;
            for (int i = 0; i < qd; i++) {
                pos = skip_name (data, pos);
                if (pos < 0 || pos + 4 > data.length)
                    return null;
                pos += 4;
            }
            int total = an + ns + ar;
            for (int i = 0; i < total; i++) {
                int name_offset = pos;
                pos = skip_name (data, pos);
                if (pos < 0 || pos + 10 > data.length)
                    return null;
                var owner = read_name (data, name_offset);
                int type = (data[pos] << 8) | data[pos + 1];
                pos += 2;
                pos += 2; // class
                pos += 4; // ttl
                int rdlen = (data[pos] << 8) | data[pos + 1];
                pos += 2;
                if (pos + rdlen > data.length)
                    return null;
                var record = MdnsRecord.for_rdata (type, owner, data, pos, rdlen);
                if (record != null)
                    records.add (record);
                pos += rdlen;
            }
            return records;
        }

        public static GLib.GenericArray<CastDevice> assemble_devices (
                GLib.GenericArray<MdnsRecord> records) {
            var devices = new GLib.GenericArray<CastDevice> ();
            for (uint i = 0; i < records.length; i++) {
                var ptr = records.get (i);
                if (ptr.type != 12 || ptr.ptr_target == "")
                    continue;
                var srv = find_record (records, 33, ptr.ptr_target);
                var txt = find_record (records, 16, ptr.ptr_target);
                string host_name = srv != null ? srv.srv_target : ptr.ptr_target;
                var addr = find_record (records, 1, host_name);
                if (addr == null)
                    addr = find_record (records, 1, ptr.ptr_target);
                if (addr == null)
                    continue;

                int port = srv != null && srv.port > 0 ? srv.port : 8009;
                string id = txt != null ? txt.txt_value ("id") : "";
                string name = txt != null ? txt.txt_value ("fn") : "";
                string model = txt != null ? txt.txt_value ("md") : "";
                if (id == "")
                    id = first_label (ptr.ptr_target);
                if (name == "")
                    name = first_label (ptr.ptr_target);

                if (contains_device (devices, id, name))
                    continue;
                devices.add (new CastDevice (id, name, addr.address, port, model));
            }
            return devices;
        }

        public static GLib.GenericArray<CastDevice> browse (int seconds) throws GLib.Error {
            var addr = new InetAddress.from_string ("224.0.0.251");
            // Send first and listen on the same ephemeral socket: Cast devices
            // answer with unicast replies to the source port.
            var socket = new Socket (SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
            socket.set_blocking (false);
            var query = build_ptr_query ("_googlecast._tcp.local");
            var dest = new InetSocketAddress (addr, 5353);
            socket.send_to (dest, query);

            var records = new GLib.GenericArray<MdnsRecord> ();
            var buffer = new uint8[4096];
            int64 deadline = GLib.get_monotonic_time () + seconds * 1000000L;
            int64 next_query = GLib.get_monotonic_time () + 1000000L;
            while (GLib.get_monotonic_time () < deadline) {
                int64 now = GLib.get_monotonic_time ();
                if (now >= next_query) {
                    socket.send_to (dest, query);
                    next_query = now + 1000000L;
                }
                if (socket.get_available_bytes () == 0) {
                    GLib.Thread.usleep (50000);
                    continue;
                }
                int read = (int) socket.receive (buffer);
                if (read <= 0)
                    continue;
                var parsed = parse_message (buffer[0:read]);
                if (parsed == null)
                    continue;
                for (uint i = 0; i < parsed.length; i++)
                    records.add (parsed.get (i));
            }
            socket.close ();
            return assemble_devices (records);
        }

        public static string bytes_to_string (uint8[] data, int start, int len) {
            var builder = new GLib.StringBuilder ();
            for (int i = 0; i < len; i++)
                builder.append_c ((char) data[start + i]);
            return builder.str;
        }

        private static MdnsRecord? find_record (GLib.GenericArray<MdnsRecord> records,
                int type, string name) {
            for (uint i = 0; i < records.length; i++) {
                var record = records.get (i);
                if (record.type == type && record.name == name)
                    return record;
            }
            return null;
        }

        private static bool contains_device (GLib.GenericArray<CastDevice> devices,
                string id, string name) {
            for (uint i = 0; i < devices.length; i++) {
                var device = devices.get (i);
                if (device.id == id && device.name == name)
                    return true;
            }
            return false;
        }

        private static string first_label (string name) {
            int dot = name.index_of_char ('.');
            return dot >= 0 ? name[0:dot] : name;
        }

        private static int skip_name (uint8[] data, int offset) {
            int pos = offset;
            int guard = 0;
            while (pos < data.length && guard++ < 64) {
                int len = data[pos];
                if (len == 0)
                    return pos + 1;
                if ((len & 0xC0) == 0xC0)
                    return pos + 2;
                pos += 1 + len;
            }
            return -1;
        }

        private static uint8[] build_ptr_query (string service) {
            var bytes = new uint8[128];
            int n = 0;
            bytes[n++] = 0; bytes[n++] = 0; // id
            bytes[n++] = 0; bytes[n++] = 0; // flags
            bytes[n++] = 0; bytes[n++] = 1; // qd
            bytes[n++] = 0; bytes[n++] = 0; // an
            bytes[n++] = 0; bytes[n++] = 0; // ns
            bytes[n++] = 0; bytes[n++] = 0; // ar
            foreach (var label in service.split (".")) {
                var raw = label.data;
                bytes[n++] = (uint8) raw.length;
                for (int i = 0; i < raw.length; i++)
                    bytes[n++] = raw[i];
            }
            bytes[n++] = 0;
            bytes[n++] = 0; bytes[n++] = 0x0c; // PTR
            bytes[n++] = 0; bytes[n++] = 1; // IN
            var query = new uint8[n];
            for (int i = 0; i < n; i++)
                query[i] = bytes[i];
            return query;
        }
    }

    public class MdnsRecord {
        public int type;
        public string name = "";
        public string ptr_target = "";
        public string srv_target = "";
        public int port = 0;
        public string address = "";
        public string[] txt = {};

        public static MdnsRecord for_rdata (int type, string owner, uint8[] data,
                int start, int length) {
            var record = new MdnsRecord ();
            record.type = type;
            record.name = owner;
            if (type == 12) { // PTR
                var target = Mdns.read_name (data, start);
                if (target == null)
                    return null;
                record.ptr_target = target;
                return record;
            }
            if (type == 33) { // SRV
                if (length < 6)
                    return null;
                record.port = (data[start + 4] << 8) | data[start + 5];
                var host = Mdns.read_name (data, start + 6);
                if (host == null)
                    return null;
                record.srv_target = host;
                return record;
            }
            if (type == 16) { // TXT
                var entries = new string[] {};
                int pos = start;
                int end = start + length;
                while (pos < end) {
                    int len = data[pos++];
                    if (pos + len > end)
                        break;
                    entries += Mdns.bytes_to_string (data, pos, len);
                    pos += len;
                }
                record.txt = entries;
                return record;
            }
            if (type == 1) { // A
                if (length < 4)
                    return null;
                record.address = "%d.%d.%d.%d".printf (data[start], data[start + 1],
                    data[start + 2], data[start + 3]);
                return record;
            }
            return null;
        }

        public string txt_value (string key) {
            foreach (var entry in txt) {
                if (entry.has_prefix (key + "="))
                    return entry.offset (key.length + 1);
            }
            return "";
        }
    }
}