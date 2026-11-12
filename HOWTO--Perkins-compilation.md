# HOWTO--Perkins-compilation.md

How to turn the Perkins source (`perkins.pl`) into the stand-alone binary `perkins` (Linux, macOS) or `perkins.exe` (Windows), check it and install it, and how GitHub builds the binaries and the Linux packages. Current as of Perkins v2.0.41.

## 10. What the binary is

`pp`, from PAR::Packer, packs the Perl script, the Perl interpreter and every module the script uses into one executable. The binary therefore runs on a machine with no Perl modules installed. It must be built on the operating system it will run on: a Linux binary on Linux, a Windows `.exe` on Windows, a macOS binary on macOS. GitHub builds all of them for every release (section 55), so building by hand is only needed for a version that has not been released, or for another system.

Perkins needs two modules that are not part of core Perl: `Roman` and `Lingua::ES::Numeros`. Everything else it uses is core Perl.

## 20. Linux, once per machine

Fedora:

```bash
sudo dnf install perl-PAR-Packer perl-App-cpanminus
cpanm --local-lib=~/perl5 Roman Lingua::ES::Numeros
```

Debian and Ubuntu:

```bash
sudo apt install libpar-packer-perl cpanminus
cpanm --local-lib=~/perl5 Roman Lingua::ES::Numeros
```

Perl must look in `~/perl5` for the two modules; if it does not already, add `eval "$(perl -I ~/perl5/lib/perl5 -Mlocal::lib)"` to `~/.bashrc`. Then check:

```bash
perl -MRoman -e 'print "Roman OK $Roman::VERSION\n"'
perl -MLingua::ES::Numeros -e 'print "Numeros OK $Lingua::ES::Numeros::VERSION\n"'
which pp
```

## 30. Linux, every new version

In the folder holding `perkins.pl` and `tests/`:

```bash
pp -M Roman -M Lingua::ES::Numeros -o perkins perkins.pl
./perkins -h 2>&1 | grep -m1 'Perkins v'
bash tests/run-test.sh "$PWD/perkins"
```

`pp` may print a notice about Module::Runtime; it is harmless. The version line must name the new version and the tests must end with ALL TESTS PASSED. Only then install it (section 40).

## 40. Installing the Linux binary

Any folder on the PATH will do; `~/bin` needs no root access, `/usr/local/bin` serves every user:

```bash
mkdir -p ~/bin
mv perkins ~/bin/perkins
hash -r
perkins -h 2>&1 | grep -m1 'Perkins v'
bash tests/run-test.sh
```

Without an argument `run-test.sh` checks the `perkins` on the PATH, so the last line confirms the installed copy.

Do not also install a `.deb`, `.rpm` or Arch package (section 55) on the same machine: it puts a second `perkins` in `/usr/bin`, and which of the two runs then depends on the order of the PATH.

## 50. Windows, by hand

Install Strawberry Perl, then in its command prompt:

```
cpanm PAR::Packer Roman Lingua::ES::Numeros
pp -M Roman -M Lingua::ES::Numeros -o perkins.exe perkins.pl
perkins.exe -h
```

The test script needs bash (Git Bash or WSL): `bash tests/run-test.sh ./perkins.exe`. The ready-built `.exe` of section 55 makes this unnecessary.

## 55. Binaries and packages built by GitHub

The public repository is https://github.com/Linguista/Perkins. It holds the source as `perkins.pl`, `perkins.ini`, this HOWTO and the other documents, `tests/`, the license, the build instructions for GitHub (`.github/workflows/build.yml`) and the description of the Linux packages (`packaging/nfpm.yaml`).

When a release is published there, GitHub:

1. checks that no file of the repository contains any of the private terms listed in the repository secret `PRIVATE_TERMS` (section 57);
2. builds Perkins on five kinds of machine: Linux on Intel or AMD processors and Linux on ARM processors (Ubuntu 22.04, with Perl 5.40 compiled there), Windows (Strawberry Perl), and macOS on Apple Silicon and on Intel processors;
3. runs the tests of `tests/` on each, with the Perl used for building out of reach, and again on Fedora with each Linux binary;
4. makes the Linux packages from the two Linux binaries, installs each one on Fedora, Debian and Ubuntu (and the Arch Linux package on Arch Linux) and runs the tests there;
5. attaches the binaries and the packages to the release.

| File | For | Install with |
|---|---|---|
| `perkins_2.0.42-1_amd64.deb` | Debian, Ubuntu and their derivatives | `sudo apt install ./perkins_2.0.42-1_amd64.deb` |
| `perkins-2.0.42-1.x86_64.rpm` | Fedora | `sudo dnf install ./perkins-2.0.42-1.x86_64.rpm` |
| `perkins-2.0.42-1-x86_64.pkg.tar.zst` | Arch Linux | `sudo pacman -U perkins-2.0.42-1-x86_64.pkg.tar.zst` |
| `perkins_2.0.42-1_arm64.deb` | Debian, Ubuntu and Raspberry Pi OS on ARM processors (64-bit) | `sudo apt install ./perkins_2.0.42-1_arm64.deb` |
| `perkins-2.0.42-1.aarch64.rpm` | Fedora on ARM processors | `sudo dnf install ./perkins-2.0.42-1.aarch64.rpm` |
| `perkins-linux-x86_64` | any other Linux on Intel or AMD processors | `chmod +x perkins-linux-x86_64` and move it to a folder on the PATH as `perkins` |
| `perkins-linux-arm64` | any other Linux on ARM processors (64-bit) | as above |
| `perkins-windows-x86_64.exe` | Windows, also Windows on ARM, which runs it through its emulation | rename it `perkins.exe` and put it in a folder on the PATH |
| `perkins-macos-arm64` | macOS on Apple Silicon (M1 and later) | as on Linux; see the notes below |
| `perkins-macos-x86_64` | macOS on Intel processors | as on Linux; see the notes below |

The package names carry the version, so they change with every release. A package puts `perkins` in `/usr/bin`, the documents and a sample `perkins.ini` in `/usr/share/doc/perkins/` and the license in `/usr/share/licenses/perkins/`; `sudo apt remove perkins`, `sudo dnf remove perkins` or `sudo pacman -R perkins` takes it out again. The packages are not in the distributions' own repositories, so they do not update themselves: a newer one is installed over the old one the same way.

One `.deb` serves both Debian and Ubuntu: it holds a binary that needs nothing from the system but its C library. GitHub tests it on Debian stable and Ubuntu 24.04. The binaries are built on Ubuntu 22.04, so systems older than Ubuntu 22.04 or Debian 12 may lack the C library they need. There is no Arch Linux package for ARM processors, since Arch Linux itself runs only on Intel and AMD processors.

These are all the systems GitHub can build on. Not covered: 32-bit systems, and Windows on ARM as a native program (Strawberry Perl exists only for Intel and AMD processors; the `.exe` runs there through emulation).

### Publishing a release

1. Open https://github.com/Linguista/Perkins/releases/new
2. In **Choose a tag**, type the version, for example `2.0.42`, and click **Create new tag: 2.0.42 on publish**. Leave **Target** at `master`.
3. Give it a title (`Perkins 2.0.42`) and a description.
4. Leave **Set as the latest release** ticked, and press **Publish release**.

The build takes about fifteen minutes; its progress is on the repository's **Actions** tab. When it is green, the binaries and the packages are listed under the release's **Assets**. If one platform fails, the others are still attached, and the failure's log is on the Actions tab.

The same build can be run without a release, as a check: **Actions** → **Build Perkins binaries** → **Run workflow**. The binaries and packages are then kept for 90 days as downloads of that run, not attached anywhere.

### Retiring an older release

A newer release becomes the one marked **Latest**, and the older one stays listed below it. To mark an older one as superseded, open it on the Releases page, press the pencil, add a line such as "Superseded by 2.0.41" to its description, and press **Update release**. To remove it, press the trash icon beside it on the Releases page and confirm; this removes its page and its attached files, while its tag, and the files of that version in the repository's history, remain.

### Choosing what is built

What is built is set in `.github/workflows/build.yml`:

- The list under `matrix:` → `include:` has one entry per binary: `os` is the kind of machine GitHub builds on, `out` the file `pp` writes, `asset` the name it gets on the release, and `packages` the Linux packages made from it (`deb rpm archlinux`, `deb rpm`, or empty). Delete an entry to stop building that binary, or delete a word from `packages` to stop making that package.
- The packages are described in `packaging/nfpm.yaml`.

The file can be edited on GitHub itself (open it and press the pencil). The change takes effect from the next build.

### Notes on the binaries

- The Linux binaries are built with a Perl compiled without libcrypt (Perkins never uses it). Ubuntu and Debian have `libcrypt.so.1` and Fedora has `libcrypt.so.2`, so a binary that needed either would not run on the other; these run on both, and GitHub checks them on Fedora.
- The macOS binaries are not signed. The first time, macOS refuses to open one; remove the block with `xattr -d com.apple.quarantine perkins`, or allow it under System Settings → Privacy & Security.

## 57. Keeping private information out of the repository

Nothing in the repository may name a private folder, user name, machine or project. Documents are written without local paths; anything that only makes sense on one machine is kept in files outside the repository.

The build checks this before anything else. The repository secret `PRIVATE_TERMS` (Settings → Secrets and variables → Actions) holds the terms, one per line; the build fails, naming only the files and the number of matches, if any file holds one of them. A secret is never shown on GitHub, so the terms themselves are not published. Without the secret the check is skipped.

## 60. After a new version

- Any intended change in output is reflected in `tests/expected/` and in the changelog at the top of `perkins.pl` and in `perkins_README.md`.
- The new version goes to the repository as `perkins.pl`, with the changed documents and tests, and a release is published (section 55).

## 70. History

- The binaries up to 2.0.36 were built by hand on Linux with `pp -M Roman -M Lingua::ES::Numeros`. 2.0.0 was once built with `staticperl mkapp`; that method is no longer used.
- 2.0.36 was the first version published with binaries built by GitHub for Linux, Windows and macOS, and with `.deb`, `.rpm` and Arch Linux packages.
- 2.0.37 added the check for private information (section 57), and binaries for Linux on ARM processors and macOS on Intel processors, with `.deb` and `.rpm` packages for ARM.
- 2.0.38 changed nothing in how Perkins is built; the tests grew from 26 to 40.
- 2.0.39 changed nothing in how Perkins is built; the tests grew from 40 to 46.
- 2.0.40 changed nothing in how Perkins is built; the tests grew from 46 to 57.
- 2.0.41 changed nothing in how Perkins is built; the tests grew from 57 to 65.
- 2.0.42 changed nothing in how Perkins is built; the tests grew from 65 to 68.
- The repository held Perkins 1.0.6 from 2016; that version, with its binaries, stays in the repository's history.
