#!/bin/sh
# Writes the AUR package's PKGBUILD for one verifique release into the given folder, with the
# release's own checksums. scripts/test-aur.sh then builds it on Arch and adds its .SRCINFO.
#   sh scripts/aur.sh 0.3.2 aur-out
set -eu
version=${1:?the verifique version, such as 0.3.2}
out=${2:?the folder to write the package into}
root=$(cd "$(dirname "$0")/.." && pwd)
sums=$(curl -fsSL "https://github.com/smnkgv/verifique/releases/download/v$version/SHA256SUMS")
x64=$(printf '%s\n' "$sums" | awk '$2 == "verifique-linux-x64.tar.gz" { print $1 }')
arm64=$(printf '%s\n' "$sums" | awk '$2 == "verifique-linux-arm64.tar.gz" { print $1 }')
[ -n "$x64" ] && [ -n "$arm64" ] || { echo "verifique $version publishes no Linux builds" >&2; exit 1; }
mkdir -p "$out"
sed -e "s/@VERSION@/$version/" -e "s/@SHA256_X64@/$x64/" -e "s/@SHA256_ARM64@/$arm64/" "$root/aur/PKGBUILD.in" > "$out/PKGBUILD"
echo "wrote $out/PKGBUILD for verifique $version"
