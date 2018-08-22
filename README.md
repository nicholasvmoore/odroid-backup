#!/bin/bash

## Make a truncated sparse disk image
#truncate -s 8G backup.img

export image="backup.img"
export subvol_root="/media/backup/subvol_root"
export loopback_device="/dev/loop0"

# Create a backup image file
truncate -s 8G

# Partition the image file
parted $image mklabel msdos
parted $image mkpart primary -a optimal 2048s 128M
parted backup.img mkpart primary -a optimal btrfs 128M 4.5G
losetup -D
losetup -P $loopback_device backup.img

# Format the partitions
mkfs.vfat -n boot ${loopback_device}p1
mkfs.btrfs -L rootfs ${loopback_device}p2

## Mount the image
mount -o rw,loop,compress=zstd,noatime,ssd ${loopback_device}p2 /media/backup
btrfs sub cr $subvol_root
mkdir -p $subvol_root/media/boot
mkdir -p $subvol_root/boot

# Create root subvolume
btrfs sub cr subvol_root ${loopback_device}p2
mount -o rw,loop ${loopback_device}p1 $subvol_root/boot
umount -R /media/backup

# Rsync
rsync -axAX /media/boot/ $subvol_root/media/boot/
rsync -axAX /boot/ $subvol_root/boot
rsync -axAX / --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} $subvol_root/

# u-boot mainline
git/u-boot/sd_fuse/sd_fusing.sh $loopback_device

# clean-up
umount -R /media/backup
losetup -D

## Compress the output
zstd backup.img
