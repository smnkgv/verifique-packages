#!/bin/sh
# Builds the signed pacman repository holding one verifique release, in site/arch/x86_64, from the
# AUR package's PKGBUILD that scripts/aur.sh wrote, so both carry the same release build. It runs as
# root in a clean Arch Linux container, given the release and a file holding the signing key.
#   sh scripts/build-arch.sh 0.3.2 aur-out /keys/signing.asc
set -eu
version=${1:?the verifique version, such as 0.3.2}
aur=$(cd "${2:?the folder holding the AUR PKGBUILD}" && pwd)
key_file=${3:?the file holding the armored signing key}
root=$(cd "$(dirname "$0")/.." && pwd)
repo=$root/site/arch/x86_64

# Containers often can't give pacman's download sandbox what it needs.
sed -i -e 's/^#DisableSandboxFilesystem/DisableSandboxFilesystem/' -e 's/^#DisableSandboxSyscalls/DisableSandboxSyscalls/' /etc/pacman.conf
pacman -Syu --noconfirm --needed --quiet base-devel git > /dev/null
gpg --batch --quiet --import "$key_file"
key=$(gpg --batch --list-secret-keys --with-colons | awk -F: '$1 == "fpr" { print $10; exit }')

# The repository's package is called verifique, so the AUR's verifique-bin can conflict with it.
useradd --create-home builder
mkdir /home/builder/package
sed -e 's/^pkgname=verifique-bin$/pkgname=verifique/' -e '/^provides=/d' -e '/^conflicts=/d' "$aur/PKGBUILD" > /home/builder/package/PKGBUILD
chown -R builder /home/builder/package
su builder -c 'cd ~/package && makepkg --noconfirm --cleanbuild' > /dev/null

mkdir -p "$repo"
cp /home/builder/package/verifique-"$version"-*-x86_64.pkg.tar.zst "$repo/"
package=$(basename "$repo"/verifique-"$version"-*-x86_64.pkg.tar.zst)
gpg --batch --yes --local-user "$key" --detach-sign "$repo/$package"
repo-add --quiet --sign --key "$key" "$repo/verifique.db.tar.gz" "$repo/$package"
# repo-add links verifique.db to the archive, and GitHub Pages serves files, not links.
for name in verifique.db verifique.db.sig verifique.files verifique.files.sig; do
    [ -L "$repo/$name" ] && cp --remove-destination "$(readlink -f "$repo/$name")" "$repo/$name"
done
echo "built the pacman repository for verifique $version in $repo"
