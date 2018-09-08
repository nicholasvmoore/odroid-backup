#!/bin/bash

backup_image_location="/mnt/lun0/temp"
backup_image_file="backup.img"
backup_mount="/media/backup"
subvol_root="/media/backup/subvol_root"
loopback_device="/dev/loop0"

function partition_image {
	# Partition the image file
	parted $backup_image_location/$backup_image_file mklabel msdos
	parted $backup_image_location/$backup_image_file mkpart primary -a optimal 2048s 128M
	parted $backup_image_location/$backup_image_file mkpart primary -a optimal btrfs 128M 5G
}

function format_image {
	# Format the partitions
	mkfs.vfat -n boot ${loopback_device}p1
	mkfs.btrfs -L rootfs ${loopback_device}p2
}

function backup_machine {
	# Rsync
	rsync -axAX /media/boot/ $subvol_root/media/boot/
	rsync -axAX /boot/ $subvol_root/boot
	rsync -axAX / --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} $subvol_root/
}

function u-boot_image {
	( cd sd_fuse && ./sd_fusing.sh $loopback_device )
}

function clean-up {
	umount -R 
	losetup -d $loopback_device
}

# Create a backup image file
truncate -s 5G $backup_image_location/$backup_image_file
partition_image

# Setup loopback
losetup -d $loopback_device
losetup -P $loopback_device $backup_image_location/$backup_image_file
format_image

# Mount the images
mkdir $backup_mount
mount -o rw,loop,compress=zstd,noatime,ssd ${loopback_device}p2 $backup_mount
btrfs sub cr $subvol_root
mkdir -p $subvol_root/media/boot
mkdir -p $subvol_root/boot

backup_machine
u-boot_image
clean-up

# Compress the image
zstd $image