#!/bin/sh
# Installs verifique from the dnf repository at the given address the way the README says, checks
# it runs, and removes it again. It runs as root in a clean Fedora container. The repository file
# names where the repositories are published, so testing them elsewhere points it there instead.
#   sh scripts/test-dnf.sh https://smnkgv.github.io/verifique-packages 0.3.2
set -eu
url=${1:?the address of the repositories}
version=${2:?the version to expect}
published=https://smnkgv.github.io/verifique-packages

curl -fsSL "$url/rpm/verifique.repo" | sed "s#$published#$url#g" > /etc/yum.repos.d/verifique.repo
# The repository file asks dnf to check the packages' signatures and the repository's own.
dnf install -y -q verifique

got=$(verifique --version)
[ "$got" = "verifique $version" ] || { echo "installed $got, not verifique $version" >&2; exit 1; }
command -v git > /dev/null || { echo "git did not come with verifique" >&2; exit 1; }
dnf remove -y -q verifique
if command -v verifique > /dev/null; then echo "verifique is still there after removing it" >&2; exit 1; fi
echo "dnf on $(. /etc/os-release && echo "$PRETTY_NAME"): installed $got with its signatures checked, then removed it"
