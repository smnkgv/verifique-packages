#!/bin/sh
# Installs verifique from the apt repository at the given address the way the README says, checks
# it runs, and removes it again. It runs as root in a clean Debian or Ubuntu container.
#   sh scripts/test-apt.sh https://smnkgv.github.io/verifique-packages 0.3.2
set -eu
url=${1:?the address of the repositories}
version=${2:?the version to expect}
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates > /dev/null

curl -fsSL "$url/verifique.gpg" -o /usr/share/keyrings/verifique.gpg
echo "deb [signed-by=/usr/share/keyrings/verifique.gpg] $url/deb stable main" > /etc/apt/sources.list.d/verifique.list
apt-get update -qq
apt-get install -y -qq verifique > /dev/null

got=$(verifique --version)
[ "$got" = "verifique $version" ] || { echo "installed $got, not verifique $version" >&2; exit 1; }
command -v git > /dev/null || { echo "git did not come with verifique" >&2; exit 1; }
apt-get remove -y -qq verifique > /dev/null
if command -v verifique > /dev/null; then echo "verifique is still there after removing it" >&2; exit 1; fi
echo "apt on $(. /etc/os-release && echo "$PRETTY_NAME"): installed $got from a signed repository, then removed it"
