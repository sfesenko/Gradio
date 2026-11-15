// SPDX-License-Identifier: GPL-3.0-or-later

#include "log-writer.h"

/* Implemented in log.vala: formats and appends one already-filtered line. */
extern void gradio_log_write_file (gint flags, const gchar *domain,
                                   const gchar *message);

static GLogWriterOutput
gradio_log_writer (GLogLevelFlags flags, const GLogField *fields,
                   gsize n_fields, gpointer user_data)
{
    const gchar *message = NULL;
    const gchar *domain = NULL;

    for (gsize i = 0; i < n_fields; i++) {
        if (g_strcmp0 (fields[i].key, "MESSAGE") == 0)
            message = fields[i].value;
        else if (g_strcmp0 (fields[i].key, "GLIB_DOMAIN") == 0)
            domain = fields[i].value;
    }

    if (message != NULL && !g_log_writer_default_would_drop (flags, domain))
        gradio_log_write_file ((gint) flags, domain, message);

    /* Keep the console/journald output exactly as GLib would print it. */
    return g_log_writer_default (flags, fields, n_fields, user_data);
}

void
gradio_log_install_writer (void)
{
    g_log_set_writer_func (gradio_log_writer, NULL, NULL);
}
