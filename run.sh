#!/bin/bash

## Make a truncated sparse disk image
#truncate -s 8G backup.img

export backup_image_location="/mnt/lun0/temp"
export backup_image_file="backup.img"
export backup_mount="/media/backup"
export subvol_root="/media/backup/subvol_root"
export loopback_device="/dev/loop0"

# Create a backup image file
truncate -s 5G $backup_image_location/$backup_image_file

# Partition the image file
parted $backup_image_location/$backup_image_file mklabel msdos
parted $backup_image_location/$backup_image_file mkpart primary -a optimal 2048s 128M
parted $backup_image_location/$backup_image_file mkpart primary -a optimal btrfs 128M 5G
losetup -d $loopback_device
losetup -P $loopback_device $backup_image_location/$backup_image_file  

# Format the partitions
mkfs.vfat -n boot ${loopback_device}p1
mkfs.btrfs -L rootfs ${loopback_device}p2

## Mount the image
mkdir $backup_mount
mount -o rw,loop,compress=zstd,noatime,ssd ${loopback_device}p2 $backup_mount
btrfs sub cr $subvol_root
mkdir -p $subvol_root/media/boot
mkdir -p $subvol_root/boot

# Rsync
rsync -axAX /media/boot/ $subvol_root/media/boot/
rsync -axAX /boot/ $subvol_root/boot
rsync -axAX / --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} $subvol_root/

# u-boot mainline
u-boot/sd_fuse/sd_fusing.sh $loopback_device

# clean-up
#umount -R 
#losetup -d $loopback_device

## Compress the output
#zstd $image
