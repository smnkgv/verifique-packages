#!/bin/sh
# Builds the AUR package in the given folder on Arch the way an AUR helper does, installs it, checks
# it runs, removes it, and writes the .SRCINFO the AUR needs beside the PKGBUILD. It runs as root in
# a clean Arch Linux container, and builds as an ordinary user, as makepkg requires.
#   sh scripts/test-aur.sh aur-out 0.3.2
set -eu
dir=$(cd "${1:?the folder holding the PKGBUILD}" && pwd)
version=${2:?the version to expect}
# Containers, and emulated ones above all, often can't give pacman's download sandbox what it needs.
sed -i -e 's/^#DisableSandboxFilesystem/DisableSandboxFilesystem/' -e 's/^#DisableSandboxSyscalls/DisableSandboxSyscalls/' /etc/pacman.conf
pacman -Syu --noconfirm --needed --quiet base-devel git > /dev/null
useradd --create-home builder
cp -r "$dir" /home/builder/package
chown -R builder /home/builder/package
su builder -c 'cd ~/package && makepkg --noconfirm --cleanbuild'
pacman -U --noconfirm /home/builder/package/verifique-bin-[0-9]*.pkg.tar.zst > /dev/null

got=$(verifique --version)
[ "$got" = "verifique $version" ] || { echo "installed $got, not verifique $version" >&2; exit 1; }
su builder -c 'cd ~/package && makepkg --printsrcinfo' > "$dir/.SRCINFO"
pacman -R --noconfirm verifique-bin > /dev/null
if command -v verifique > /dev/null; then echo "verifique is still there after removing it" >&2; exit 1; fi
echo "AUR on Arch Linux: built and installed $got, then removed it, and wrote .SRCINFO"
