#!/bin/sh
# Installs verifique from the pacman repository at the given address the way the README says,
# checks it runs, and removes it again. It runs as root in a clean Arch Linux container.
#   sh scripts/test-pacman.sh https://smnkgv.github.io/verifique-packages 0.3.2
set -eu
url=${1:?the address of the repositories}
version=${2:?the version to expect}
# Containers often can't give pacman's download sandbox what it needs.
sed -i -e 's/^#DisableSandboxFilesystem/DisableSandboxFilesystem/' -e 's/^#DisableSandboxSyscalls/DisableSandboxSyscalls/' /etc/pacman.conf
pacman-key --init > /dev/null 2>&1

curl -fsSL "$url/verifique.asc" | pacman-key --add - > /dev/null 2>&1
fingerprint=$(curl -fsSL "$url/verifique.asc" | gpg --batch --with-colons --show-keys 2> /dev/null | awk -F: '$1 == "fpr" { print $10; exit }')
pacman-key --lsign-key "$fingerprint" > /dev/null 2>&1
printf '\n[verifique]\nServer = %s/arch/$arch\n' "$url" >> /etc/pacman.conf
pacman -Syu --noconfirm --quiet verifique > /dev/null

got=$(verifique --version)
[ "$got" = "verifique $version" ] || { echo "installed $got, not verifique $version" >&2; exit 1; }
command -v git > /dev/null || { echo "git did not come with verifique" >&2; exit 1; }
pacman -R --noconfirm verifique > /dev/null
if command -v verifique > /dev/null; then echo "verifique is still there after removing it" >&2; exit 1; fi
echo "pacman on Arch Linux: installed $got with its signatures checked, then removed it"
