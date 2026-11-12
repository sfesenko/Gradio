// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {
    [CCode (lower_case_c_prefix = "cast_")]
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

        private TlsClientConnection? tls = null;
        private DataInputStream? input = null;
        private DataOutputStream? output = null;
        private GLib.Cancellable cancellable = new GLib.Cancellable ();
        private GLib.Queue<GLib.Bytes> write_queue =
            new GLib.Queue<GLib.Bytes> ();
        // Keeps the frame alive until the asynchronous write completes.
        private GLib.Bytes? in_flight = null;
        private bool writing = false;
        private bool closing = false;
        private bool draining = false;
        private bool finishing = false;
        private bool closed_emitted = false;

        public async bool connect (string host, int port,
                GLib.Cancellable? session_cancellable = null) throws GLib.Error {
            if (session_cancellable != null)
                cancellable = session_cancellable;

            var client = new SocketClient ();
            var conn = yield client.connect_to_host_async (host, (uint16) port,
                cancellable);
            var tls_conn = TlsClientConnection.@new (conn, null);
            // Self-signed certificate on the local network; the address comes
            // from mDNS, so accept it.
            tls_conn.accept_certificate.connect ((cert, errors) => true);
            yield tls_conn.handshake_async (GLib.Priority.DEFAULT, cancellable);

            tls = tls_conn;
            input = new DataInputStream (tls_conn.get_input_stream ());
            output = new DataOutputStream (tls_conn.get_output_stream ());
            read_loop_async.begin ();
            return true;
        }

        public void send_json (string @namespace, string destination, string json) throws GLib.Error {
            if (output == null || closing)
                throw new IOError.FAILED ("not connected");

            var buffer = new ByteArray ();
            var msg = CastMessage ();
            msg.source_id = "12345678-1234-1234-1234-123456789abc";
            msg.destination_id = destination;
            msg.namespace_ = @namespace;
            msg.payload_type = 0;
            msg.payload_utf8 = json;
            cast_message_write_frame (buffer, msg);

            var frame = new GLib.Bytes (buffer.data);
            write_queue.push_tail (frame);
            pump_writes ();
        }

        public async void close_async () {
            if (closing) {
                yield finish_close_async ();
                return;
            }
            closing = true;
            draining = false;
            cancellable.cancel ();
            write_queue.clear ();
            yield finish_close_async ();
        }

        // Used by STOP: queue the request first, then close once the write has
        // drained. This keeps the UI non-blocking without dropping the command.
        public void close_after_drain () {
            if (closing) {
                if (!draining)
                    finish_close_async.begin ();
                return;
            }
            closing = true;
            draining = true;
            if (!writing && write_queue.is_empty ())
                finish_close_async.begin ();
            else
                pump_writes ();
        }

        private async void finish_close_async () {
            if (closed_emitted || finishing)
                return;
            finishing = true;

            cancellable.cancel ();
            try {
                if (tls != null)
                    yield tls.close_async (GLib.Priority.DEFAULT, null);
            } catch (GLib.Error e) {
            }

            tls = null;
            input = null;
            output = null;
            emit_closed ();
        }

        private void pump_writes () {
            if (writing || output == null || write_queue.is_empty ())
                return;
            if (closing && !draining)
                return;

            writing = true;
            var frame = write_queue.pop_head ();
            in_flight = frame;
            // Do not copy: the pointer must stay valid for the whole
            // asynchronous write, which is why `in_flight` holds a reference.
            unowned uint8[] data = in_flight.get_data ();
            var stream = output;
            stream.write_all_async.begin (data, GLib.Priority.DEFAULT, cancellable,
                (obj, res) => {
                    try {
                        size_t written;
                        stream.write_all_async.end (res, out written);
                    } catch (GLib.Error e) {
                        writing = false;
                        in_flight = null;
                        close_async.begin ();
                        return;
                    }
                    writing = false;
                    in_flight = null;
                    if (!write_queue.is_empty ())
                        pump_writes ();
                    else if (closing && draining)
                        finish_close_async.begin ();
                });
        }

        private async void read_loop_async () {
            while (!closing) {
                var len_bytes = new uint8[4];
                size_t read = 0;
                try {
                    var stream = input;
                    yield stream.read_all_async (len_bytes, GLib.Priority.DEFAULT,
                        cancellable, out read);
                } catch (GLib.Error e) {
                    break;
                }

                if (closing)
                    break;
                if (read < 4)
                    break;

                uint32 length = ((uint32) len_bytes[0] << 24) |
                                ((uint32) len_bytes[1] << 16) |
                                ((uint32) len_bytes[2] << 8) |
                                (uint32) len_bytes[3];
                if (length == 0 || length > 1024 * 1024)
                    break;

                var frame = new uint8[length];
                try {
                    var stream = input;
                    yield stream.read_all_async (frame, GLib.Priority.DEFAULT,
                        cancellable, out read);
                } catch (GLib.Error e) {
                    break;
                }
                if (closing)
                    break;
                if (read < length)
                    break;

                int out_len;
                string? decoded = cast_message_decode_json (frame, out out_len);
                if (decoded == null || decoded == "")
                    continue;

                string captured = decoded;
                message_received (captured);
            }

            if (draining) {
                if (!writing && write_queue.is_empty ())
                    finish_close_async.begin ();
            } else if (!closing) {
                close_async.begin ();
            }
        }

        private void emit_closed () {
            if (closed_emitted)
                return;
            closed_emitted = true;
            closed ();
        }
    }
}