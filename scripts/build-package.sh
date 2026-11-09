#!/usr/bin/env bash
# Build an Arch Linux package from the live work tree (uncommitted changes
# included). Output lands in scripts/dist/.
#
#   ./scripts/build-package.sh            build the package
#   ./scripts/build-package.sh -C         clean build (wipes the throwaway
#                                         copy in $srcdir — never the checkout)
#   ./scripts/build-package.sh -i         install after building
#   ./scripts/build-package.sh -f         rebuild even if already built
#
# All arguments are passed through to makepkg.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname "$script_dir")"
dist_dir="$script_dir/dist"

mkdir -p "$dist_dir"
cp "$script_dir/PKGBUILD" "$dist_dir/"

cd "$dist_dir"
export TEMPLATE_SOURCE_DIR="$repo_root"
exec makepkg "$@"
