#include <glib.h>
#include <stdlib.h>
#include <string.h>
#include <protobuf-c/protobuf-c.h>
#include "cast.pb-c.h"

typedef struct {
    int protocol_version;
    const char *source_id;
    const char *destination_id;
    const char *namespace_;
    int payload_type;
    const char *payload_utf8;
} CastFrame;

/* Minimal varint helpers (protobuf wire format). */
static void put_varint (GString *out, uint64_t value) {
    while (value >= 0x80) {
        g_string_append_c (out, (char) (value | 0x80));
        value >>= 7;
    }
    g_string_append_c (out, (char) value);
}

static void put_bytes (GString *out, uint8_t tag, const char *data, size_t len) {
    g_string_append_c (out, (char) tag);
    put_varint (out, (uint64_t) len);
    g_string_append_len (out, data, len);
}

static size_t get_varint (const uint8_t *in, size_t len, uint64_t *value) {
    uint64_t result = 0;
    int shift = 0;
    size_t n = 0;
    while (n < len && shift <= 63) {
        uint8_t b = in[n++];
        result |= ((uint64_t) (b & 0x7f)) << shift;
        if (!(b & 0x80))
            break;
        shift += 7;
    }
    *value = result;
    return n;
}

void cast_message_write_frame (GByteArray *buffer, void *msg_void) {
    const CastFrame *msg = (const CastFrame *) msg_void;
    GString *body = g_string_new (NULL);

    /* protocol_version (field 1, varint) */
    g_string_append_c (body, 0x08);
    put_varint (body, (uint64_t) msg->protocol_version);

    /* source_id (field 2) */
    put_bytes (body, 0x12, msg->source_id, strlen (msg->source_id));
    /* destination_id (field 3) */
    put_bytes (body, 0x1a, msg->destination_id, strlen (msg->destination_id));
    /* namespace (field 4) */
    put_bytes (body, 0x22, msg->namespace_, strlen (msg->namespace_));
    /* payload_type (field 5, varint) */
    g_string_append_c (body, 0x28);
    put_varint (body, (uint64_t) msg->payload_type);
    /* payload_utf8 (field 6) */
    if (msg->payload_utf8) {
        put_bytes (body, 0x32, msg->payload_utf8, strlen (msg->payload_utf8));
    }

    uint8_t prefix[4] = {
        (uint8_t) (body->len >> 24), (uint8_t) (body->len >> 16),
        (uint8_t) (body->len >> 8), (uint8_t) body->len
    };
    g_byte_array_append (buffer, prefix, 4);
    g_byte_array_append (buffer, (const guint8 *) body->str, body->len);
    g_string_free (body, TRUE);
}

char *cast_message_decode_json (const uint8_t *data, int data_length, int *length) {
    size_t len = data_length;
    size_t pos = 0;
    while (pos < len) {
        uint64_t key;
        size_t n = get_varint (data + pos, len - pos, &key);
        if (n == 0)
            return NULL;
        pos += n;
        int field = (int) (key >> 3);
        int wire = (int) (key & 7);
        if (wire == 0) {
            uint64_t v;
            n = get_varint (data + pos, len - pos, &v);
            if (n == 0)
                return NULL;
            pos += n;
        } else if (wire == 2) {
            uint64_t l;
            n = get_varint (data + pos, len - pos, &l);
            if (n == 0)
                return NULL;
            pos += n;
            if (l > len - pos)
                return NULL;
            if (field == 6) {
                char *out = malloc (l + 1);
                if (out == NULL)
                    return NULL;
                memcpy (out, data + pos, l);
                out[l] = '\0';
                if (length != NULL)
                    *length = (int) l;
                return out;
            }
            pos += l;
        } else {
            return NULL;
        }
    }
    return NULL;
}