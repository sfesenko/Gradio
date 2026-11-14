#!/bin/sh
# Translation template checks.
#
#   ./po/check-pot.sh             regenerate po/gradio.pot and fail if it drifted
#   ./po/check-pot.sh --coverage  fail if a source file with translatable
#                                 strings is missing from po/POTFILES.in
#
# --coverage runs as part of `meson test`; --drift needs a configured builddir
# and is also the check CI runs. Keep this script POSIX sh: /bin/sh is dash on
# Debian and Ubuntu.
set -eu

po_dir=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$po_dir")
potfiles="$po_dir/POTFILES.in"
pot="$po_dir/gradio.pot"

usage() {
    cat <<'EOF'
Usage:
  ./po/check-pot.sh             regenerate po/gradio.pot and fail if it drifted
  ./po/check-pot.sh --coverage  fail if a source file with translatable
                                strings is missing from po/POTFILES.in
EOF
}

check_coverage() {
    missing=$( (cd "$root" && grep -rlE '(_|C_|N_)\([[:space:]]*"' --include='*.vala' src) |
        grep -vxF -f "$potfiles" || true)
    if [ -n "$missing" ]; then
        echo "error: po/POTFILES.in is missing these files:" >&2
        printf '%s\n' "$missing" | sed 's/^/  /' >&2
        return 1
    fi

    while IFS= read -r file; do
        case $file in
        "" | "#"*) continue ;;
        esac
        if [ ! -e "$root/$file" ]; then
            echo "error: po/POTFILES.in lists a missing file: $file" >&2
            return 1
        fi
    done <"$potfiles"

    echo "po/POTFILES.in covers every source file with translatable strings"
}

check_drift() {
    builddir=${BUILDDIR:-$root/builddir}
    if [ ! -d "$builddir" ]; then
        echo "configure a build first: meson setup builddir" >&2
        return 2
    fi

    # Location comments and the timestamp change on every run, so diff ignores
    # them. The old template goes through stdin to avoid a temporary copy.
    old=$(cat "$pot")
    meson compile -C "$builddir" gradio-pot >/dev/null

    if ! printf '%s\n' "$old" |
        diff -u -I '^#: ' -I '^"POT-Creation-Date:' \
            --label 'po/gradio.pot (committed)' \
            --label 'po/gradio.pot (extracted)' - "$pot"; then
        echo >&2
        echo "error: po/gradio.pot is stale" >&2
        echo "the file above was just regenerated; commit it" >&2
        return 1
    fi

    echo "po/gradio.pot is up to date"
}

case "${1:-}" in
--coverage) check_coverage ;;
--drift | "") check_drift ;;
-h | --help) usage ;;
*)
    usage >&2
    exit 2
    ;;
esac
