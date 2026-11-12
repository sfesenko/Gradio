// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {
    [CCode (lower_case_c_prefix = "cast_", cheader_filename = "cast.pb-c.h")]
    private struct CastMessage {
        public int protocol_version;
        public string source_id;
        public string destination_id;
        public string namespace_;
        public int payload_type;
        public string payload_utf8;
    }

    [CCode (cname = "cast_message_write_frame")]
    private extern static void cast_message_write_frame (GLib.ByteArray buffer, CastMessage msg);
    [CCode (cname = "cast_message_decode_json")]
    private extern static string cast_message_decode_json (uint8[] data, out int length);

    public class CastConnection : GLib.Object {
        public signal void message_received (string json);
        public signal void closed ();

        private TlsClientConnection tls;
        private DataInputStream input;
        private DataOutputStream output;
        private bool closing = false;
        private bool closed_emitted = false;

        public async bool connect (string host, int port) throws GLib.Error {
            var client = new SocketClient ();
            var conn = yield client.connect_to_host_async (host, (uint16) port);
            var tls_conn = TlsClientConnection.@new (conn, null);
            // Cast devices present a self-signed certificate. The transport is
            // only used on the local network and the device address comes from
            // mDNS, so accept the certificate.
            tls_conn.accept_certificate.connect ((cert, errors) => true);
            yield tls_conn.handshake_async ();
            tls = tls_conn;
            input = new DataInputStream (tls_conn.get_input_stream ());
            output = new DataOutputStream (tls_conn.get_output_stream ());
            new Thread<bool> ("cast-read", () => {
                read_loop ();
                return true;
            });
            return true;
        }

        public void send_json (string @namespace, string destination, string json) throws GLib.Error {
            if (output == null)
                throw new IOError.FAILED ("not connected");
            var buffer = new ByteArray ();
            var msg = CastMessage ();
            msg.source_id = "12345678-1234-1234-1234-123456789abc";
            msg.destination_id = destination;
            msg.namespace_ = @namespace;
            msg.payload_type = 0;
            msg.payload_utf8 = json;
            cast_message_write_frame (buffer, msg);
            size_t written;
            output.write_all (buffer.data[:buffer.len], out written);
        }

        public void close () {
            if (closing)
                return;
            closing = true;
            try {
                if (tls != null)
                    tls.close ();
            } catch (GLib.Error e) {
            }
            emit_closed ();
        }

        private void read_loop () {
            while (!closing) {
                string? json;
                try {
                    json = read_json ();
                } catch (GLib.Error e) {
                    break;
                }
                if (json == null || json == "")
                    break;
                string captured = json;
                GLib.Idle.add (() => {
                    message_received (captured);
                    return false;
                });
            }
            GLib.Idle.add (() => {
                emit_closed ();
                return false;
            });
        }

        private string? read_json () throws GLib.Error {
            if (input == null)
                throw new IOError.FAILED ("not connected");
            var len_bytes = new uint8[4];
            size_t read;
            input.read_all (len_bytes, out read);
            if (read < 4)
                return null;
            uint32 length = ((uint32) len_bytes[0] << 24) | ((uint32) len_bytes[1] << 16) |
                            ((uint32) len_bytes[2] << 8) | (uint32) len_bytes[3];
            if (length == 0 || length > 1024 * 1024)
                return null;
            var frame = new uint8[length];
            input.read_all (frame, out read);
            if (read < length)
                return null;
            int out_len;
            string? decoded = cast_message_decode_json (frame, out out_len);
            if (decoded == null)
                return null;
            return decoded;
        }

        private void emit_closed () {
            if (closed_emitted)
                return;
            closed_emitted = true;
            closed ();
        }
    }
}