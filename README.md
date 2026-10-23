# Ubuntu Touch for the Nokia 7 plus (B2N)

Adaptation for the TA-1046 and the other B2N models. The phone this port is
built against is running stock Android 10, build `00WW_4_15N`, security patch
2021-03-01. The bootloader is unlocked. VoLTE and VoWiFi calls, in both
directions, and SMS were confirmed on that install before any custom image
was written.

## Layout

`deviceinfo` is read by the [Halium generic adaptation build
tools](https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools).
`./build.sh` clones those tools on first run.

The kernel branch of this repository is `halium-10`. It is a snapshot of
[LineageOS/android_kernel_nokia_sdm660](https://github.com/LineageOS/android_kernel_nokia_sdm660)
`lineage-22.2` at `fa214c1782ae25786cfe0aacee2901713f68707f` (kernel 4.4.302),
plus `arch/arm64/configs/halium.config`. That branch also repairs
`drivers/video/console/dummycon.c`, which does not compile once `CONFIG_VT`
is enabled. The same fragment is kept in
`kernel-fragments/halium.config`. The defconfig line selects
`vendor/sdm660-perf_defconfig`, `vendor/nokia/nokia.config`,
`vendor/nokia/B2N.config`, and `halium.config`, and this kernel merges those
`.config` fragments in that order.

## Radio

The stock vendor exposes `android.hardware.radio@1.4` and
`vendor.qti.hardware.radio.ims` through 1.5, on both SIM slots. IMS is left
enabled. The ofono plugin is `qti` with `radioInterface = 1.4`.

## Partitions

A/B device. Active slot on the reference phone was `_a`. System is 3072 MiB,
vendor is 1024 MiB, boot is 64 MiB. There is no `vendor_boot` or `dtbo`
partition. `persist`, `modemst1`, `modemst2`, and `fsg` hold calibration and
the IMS profile; a restore must put the dumped copies back and must not
format them.

## Firmware backup

`backup/tools/dump-stock.sh` boots the official TWRP image into RAM with
`fastboot boot` and reads every partition except userdata.
`scripts/restore-stock.sh` writes that dump back. The images stay on this
machine. They are not part of the git history.

## Device archive

`.github/workflows/boot-image.yml` runs `./build.sh` on Ubuntu. That builds
the kernel, `boot.img`, and `device_B2N.tar.xz`. The archive contains the
boot image plus the ofono and device-info overlays. Both files are uploaded
as a workflow artifact and published on the `ci/boot-img` branch. Nothing is
flashed from that workflow.

The arm64 Ubuntu Touch 24.04-2.x rootfs published for Halium 9 and newer is
`ubuntu-touch-android9plus-rootfs-arm64.tar.gz`, about 926 MiB compressed.
It is not part of this archive. Its unpacked size still has to be compared
with the 3072 MiB system slot before it is installed.

## What is not done yet

The boot image and the rootfs have not been flashed. Carrier VoLTE
configuration for the SIM in use still has to be checked against the Ubuntu
Touch carrier list.
