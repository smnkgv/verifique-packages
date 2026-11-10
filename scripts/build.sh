#!/bin/sh
# Builds the signed apt and dnf repositories holding one verifique release, in site/, ready for
# GitHub Pages. Each package is made from the release's own Linux build, checked against the
# release's checksums, so the packages hold exactly what the release published.
#   sh scripts/build.sh 0.3.2
# Needs curl, nfpm, apt-ftparchive (apt-utils), createrepo_c, envsubst (gettext-base) and gpg holding
# the signing key. PACKAGES_URL is where the site will be served, for the files that name it.
set -eu

version=${1:?the verifique version to package, such as 0.3.2}
url=${PACKAGES_URL:-https://smnkgv.github.io/verifique-packages}
root=$(cd "$(dirname "$0")/.." && pwd)
site=$root/site
release=https://github.com/smnkgv/verifique/releases/download/v$version
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The signing key: the one named in PACKAGES_KEY, or the only secret key gpg holds.
key=${PACKAGES_KEY:-$(gpg --batch --list-secret-keys --with-colons | awk -F: '$1 == "fpr" { print $10; exit }')}
[ -n "$key" ] || { echo "gpg holds no secret key to sign with" >&2; exit 1; }
gpg --batch --armor --export-secret-keys "$key" > "$work/key.asc"

rm -rf "$site"
pool=$site/deb/pool/main/v/verifique
mkdir -p "$pool" "$site/rpm/packages"

curl -fsSL "$release/SHA256SUMS" -o "$work/SHA256SUMS"
for arch in amd64 arm64; do
    case $arch in
    amd64) target=linux-x64 ;;
    arm64) target=linux-arm64 ;;
    esac
    tarball=verifique-$target.tar.gz
    curl -fsSL "$release/$tarball" -o "$work/$tarball"
    (cd "$work" && grep " $tarball\$" SHA256SUMS | sha256sum -c --quiet -)
    mkdir -p "$work/$arch"
    tar -xzf "$work/$tarball" -C "$work/$arch"
    ARCH=$arch VERSION=$version BINARY=$work/$arch/verifique RPM_KEY=$work/key.asc \
        envsubst '$ARCH $VERSION $BINARY $RPM_KEY' < "$root/nfpm.yaml" > "$work/nfpm-$arch.yaml"
    nfpm package --config "$work/nfpm-$arch.yaml" --packager deb --target "$pool/"
    nfpm package --config "$work/nfpm-$arch.yaml" --packager rpm --target "$site/rpm/packages/"
done
rm "$work/key.asc"

# apt: one suite, stable, with an index per processor, and a Release file signed both inline
# (InRelease) and alongside (Release.gpg), as apt reads either.
cd "$site/deb"
for arch in amd64 arm64; do
    index=dists/stable/main/binary-$arch
    mkdir -p "$index"
    apt-ftparchive --arch "$arch" packages pool > "$index/Packages"
    gzip -9kn "$index/Packages"
done
apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=verifique \
    -o APT::FTPArchive::Release::Label=verifique \
    -o APT::FTPArchive::Release::Suite=stable \
    -o APT::FTPArchive::Release::Codename=stable \
    -o APT::FTPArchive::Release::Architectures="amd64 arm64" \
    -o APT::FTPArchive::Release::Components=main \
    -o APT::FTPArchive::Release::Description="verifique, a verification queue for coding agents" \
    release dists/stable > "$work/Release"
mv "$work/Release" dists/stable/Release
gpg --batch --yes --local-user "$key" --clearsign -o dists/stable/InRelease dists/stable/Release
gpg --batch --yes --local-user "$key" --armor --detach-sign -o dists/stable/Release.gpg dists/stable/Release

# dnf: the packages are signed themselves, and so is the repository's metadata.
createrepo_c --quiet "$site/rpm"
gpg --batch --yes --local-user "$key" --armor --detach-sign -o "$site/rpm/repodata/repomd.xml.asc" "$site/rpm/repodata/repomd.xml"
cat > "$site/rpm/verifique.repo" <<EOF
[verifique]
name=verifique
baseurl=$url/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$url/verifique.asc
EOF

# The public key, armored for dnf and people, and binary for apt's keyring.
gpg --batch --armor --export "$key" > "$site/verifique.asc"
gpg --batch --export "$key" > "$site/verifique.gpg"

sed -e "s#@URL@#$url#g" -e "s#@VERSION@#$version#g" "$root/index.html" > "$site/index.html"
touch "$site/.nojekyll"
echo "built the repositories for verifique $version in $site"
