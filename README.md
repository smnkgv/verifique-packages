# verifique packages

apt and dnf repositories and an AUR package for [verifique](https://github.com/smnkgv/verifique),
a verification queue for coding agents. They are the Linux counterpart of the
[Homebrew tap](https://github.com/smnkgv/homebrew-verifique) and the
[Scoop bucket](https://github.com/smnkgv/scoop-verifique), and hold verifique's own release
builds for x86-64 and ARM, unchanged.

## Install

Debian and Ubuntu:

```bash
curl -fsSL https://smnkgv.github.io/verifique-packages/verifique.gpg | sudo tee /usr/share/keyrings/verifique.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/verifique.gpg] https://smnkgv.github.io/verifique-packages/deb stable main" | sudo tee /etc/apt/sources.list.d/verifique.list
sudo apt update && sudo apt install verifique
```

Fedora and RHEL:

```bash
sudo curl -fsSL -o /etc/yum.repos.d/verifique.repo https://smnkgv.github.io/verifique-packages/rpm/verifique.repo
sudo dnf install verifique
```

Arch Linux, from the AUR with a helper such as yay or paru:

```bash
yay -S verifique-bin
```

Upgrades then come with the rest of the system. The packages put `verifique` in `/usr/bin` and
bring `git`. The status-bar panel stays an add-on, installed with `verifique panel install`, and
the packages suggest the libraries it needs.

## How it works

The [publish](.github/workflows/publish.yml) workflow takes one verifique release, the latest
unless told otherwise, and:

1. builds a `.deb` and an `.rpm` for each processor from the release's Linux builds, checked
   against the release's checksums, with [nfpm](https://nfpm.goreleaser.com)
   ([nfpm.yaml](nfpm.yaml));
2. builds the apt repository (one suite, `stable`) and the dnf repository, and signs the
   packages and both repositories' metadata ([scripts/build.sh](scripts/build.sh));
3. writes the AUR package's `PKGBUILD` ([aur/PKGBUILD.in](aur/PKGBUILD.in));
4. installs from the repositories in clean Ubuntu, Debian and Fedora containers, and builds and
   installs the AUR package on Arch, the way their instructions say
   ([scripts/](scripts));
5. only then publishes the repositories to GitHub Pages and the package to the AUR, and installs
   from the published repositories once more.

GitHub Pages holds only the latest release, built afresh each time, so nothing large is ever
committed here.

## Publishing a release

After a verifique release is published, run the workflow:

```bash
gh workflow run publish.yml -R smnkgv/verifique-packages
```

It needs two secrets. `SIGNING_KEY` is the armored private key that signs the packages, whose
public half is served as `verifique.asc` and `verifique.gpg`. `AUR_SSH_KEY` is the private SSH key
of the AUR account that maintains `verifique-bin`. Without `SIGNING_KEY` the workflow signs with a
throwaway key and publishes nothing, which tests everything else.
