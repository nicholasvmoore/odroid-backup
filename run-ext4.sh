#!/bin/bash

backup_image_location="/mnt/lun0/temp"
backup_image_file="backup.img"
backup_mount="/media/backup"
loopback_device="/dev/loop0"

function partition_image {
	# Partition the image file
	parted $backup_image_location/$backup_image_file mklabel msdos
	parted $backup_image_location/$backup_image_file mkpart primary -a optimal 2048s 128M
	parted $backup_image_location/$backup_image_file mkpart primary -a optimal ext4 128M 5G
}

function format_image {
	# Format the partitions
	mkfs.vfat -n boot ${loopback_device}p1
	mkfs.ext4 -L rootfs ${loopback_device}p2
}

function backup_machine {
	# Rsync
	rsync -axAX /media/boot/ $backup_mount/media/boot/
	rsync -axAX /boot/ $backup_mount/boot
	rsync -axAX / --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} $backup_mount/
}

function u-boot_image {
	( cd sd_fuse && ./sd_fusing.sh $loopback_device )
}

function clean-up {
	umount -R $backup_mount
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
mount -o rw,loop,noatime,discard ${loopback_device}p2 $backup_mount
mkdir -p $backup_mount/media/boot
mkdir -p $backup_mount/boot

backup_machine
u-boot_image
clean-up

# Compress the image
zstd $image
