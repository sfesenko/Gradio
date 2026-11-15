// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef GRADIO_LOG_WRITER_H
#define GRADIO_LOG_WRITER_H

#include <glib.h>

/* Installs the writer that duplicates GLib logs to Gradio's file sink. */
void gradio_log_install_writer (void);

#endif
