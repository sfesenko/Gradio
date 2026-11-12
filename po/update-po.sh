#!/bin/sh
set -e

cd "$(dirname "$0")"

builddir="${BUILDDIR:-../builddir}"
if [ ! -d "$builddir" ]; then
    echo "configure a build first: meson setup builddir" >&2
    exit 1
fi

# Re-extract from POTFILES.in, then merge the new template into each catalog.
meson compile -C "$builddir" gradio-pot

for po in *.po; do
    msgmerge --update "$po" gradio.pot
done
