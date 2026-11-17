# Custom Debian ISO

## Overview

You'll build a Mercy OS installer ISO based on Debian 13 (Trixie) using live-build. The ISO includes Mercy Shell, packaged as a `.deb`. When you install Mercy OS on a Proxmox VM, the `mercy-shell` command is available on the installed system.

## Before you start

Run everything below on your Debian 13 Trixie machine. Install the tools:

```bash
sudo apt install build-essential live-build
```

## Step 1. Write and package Mercy Shell

```bash
mkdir -p ~/mercy-os-work && cd ~/mercy-os-work

cat > mercy-shell.c <<'EOF'
#include <stdio.h>
int main(void) { puts("Hello from Mercy Shell!"); return 0; }
EOF

mkdir -p pkg/usr/bin pkg/DEBIAN
gcc -O2 -o pkg/usr/bin/mercy-shell mercy-shell.c

cat > pkg/DEBIAN/control <<'EOF'
Package: mercy-shell
Version: 1.0
Architecture: amd64
Maintainer: Your Name <you@example.com>
Depends: libc6
Description: Mercy Shell for Mercy OS
EOF

dpkg-deb --build --root-owner-group pkg mercy-shell_1.0_amd64.deb
```

You now have `mercy-shell_1.0_amd64.deb` in `~/mercy-os-work`.

## Step 2. Build the Mercy OS ISO

```bash
mkdir ~/mercy-os-work/image && cd ~/mercy-os-work/image

lb config \
  --distribution trixie \
  --archive-areas "main non-free-firmware" \
  --debian-installer live \
  --image-name mercy-os \
  --iso-volume "Mercy OS" \
  --iso-application "Mercy OS"

cp ../mercy-shell_1.0_amd64.deb config/packages.chroot/

sudo lb build
```

The `--image-name` option names the output file, and the two `--iso-` options set the label your VM and tools show for the disc. The first build downloads a full base system, so it takes a while. When it finishes, you'll have `mercy-os-amd64.hybrid.iso` in the `image` directory.

## Step 3. Upload the ISO to Proxmox

In the Proxmox web UI, go to your node, open the `local` storage (or whichever storage holds ISOs), choose "ISO Images", and click "Upload".

Or copy it over SSH:

```bash
scp mercy-os-amd64.hybrid.iso root@your-proxmox-host:/var/lib/vz/template/iso/mercy-os.iso
```

## Step 4. Create the VM and install

Click "Create VM" and set the following:

1. On the General tab, name the VM `mercy-os`. Proxmox doesn't allow spaces in VM names.
2. On the OS tab, select `mercy-os.iso` and leave the guest OS type as Linux.
3. On the System tab, keep the defaults (SeaBIOS).
4. On the Disks tab, give it at least 10 GB.
5. On the CPU and Memory tabs, use 2 cores and 2048 MB.
6. Leave the network on the default bridge so the installer has internet access.

Start the VM and open the console. Pick "Install" or "Graphical install" from the boot menu and go through the installer. When it asks for a hostname, you can enter `mercy-os`.

When it finishes, shut the VM down. On the VM's Hardware tab, edit the CD/DVD drive and choose "Do not use any media" so it boots from the disk.

## Step 5. Test Mercy Shell

Start the VM, log in, and run:

```bash
mercy-shell
```

You should see `Hello from Mercy Shell!`.

## Rebuilding after changes

1. Make your changes to `mercy-shell.c` and bump `Version` in `pkg/DEBIAN/control`.
2. Rebuild the `.deb` with the `gcc` and `dpkg-deb` commands from step 1. The `.deb` filename changes with the version.
3. Remove the old `.deb` from `image/config/packages.chroot/` and copy in the new one.
4. In the `image` directory, run `sudo lb clean` then `sudo lb build`.
5. Upload the new ISO to Proxmox as `mercy-os.iso` to overwrite the old one.

Keep the `image/config/` directory in git. That directory is the definition of Mercy OS.

## Next steps

- Build Mercy Shell from a proper source package with `debhelper` and `dpkg-buildpackage` instead of a hand-made `.deb`.
- Host a Mercy OS APT repository with `reprepro` or `aptly`, so installed machines get Mercy Shell updates through `apt upgrade`.
- Add a preseed file at `config/includes.installer/preseed.cfg` to make the install unattended and set the hostname to `mercy-os` automatically.
- Brand the installed system as Mercy OS. Right now `/etc/os-release` still says Debian, because the `base-files` package owns it. The usual approach is a small `mercy-os-release` package that uses `dpkg-divert` to replace it, so Debian updates don't overwrite your version.
- If Mercy Shell becomes a real login shell, add a `postinst` script that runs `add-shell /usr/bin/mercy-shell` and a `postrm` that runs `remove-shell`.
