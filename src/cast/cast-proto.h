#ifndef GRADIO_CAST_PROTO_H
#define GRADIO_CAST_PROTO_H

#include <glib.h>
#include <stdint.h>

void cast_message_write_frame (GByteArray *buffer, void *msg);
char *cast_message_decode_json (const uint8_t *data, int data_length, int *length);

#endif
