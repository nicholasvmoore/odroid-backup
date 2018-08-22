# Odroid Backup Image

## Make a truncated disk image
truncate -s 8G odroid.img

## Fdisk and create two partitions
```bash
# Make sure you toggle the bootable flag on the first partition

[/mnt/lun0/backup/odroid]$ fdisk -l odroid.img
Disk odroid.img: 8 GiB, 8589934592 bytes, 16777216 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0xeacd17a8

Device      Boot  Start      End  Sectors  Size Id Type
odroid.img1        2048   264191   262144  128M  c W95 FAT32 (LBA)
odroid.img2      264192 16777215 16513024  7.9G 83 Linux
```

## Make the loopback devices to partition
```bash
sudo losetup -o 1048576 --sizelimit 135265792 /dev/loop1 odroid.img
sudo losetup -o 135266304 --sizelimit 8589934080 /dev/loop2 odroid.img
sudo mkdosfs -F 32 -I /dev/loop1
sudo fatlabel /dev/loop1 boot
sudo mkfs.btrfs /dev/loop2
```

## Grab the UUIDs
```bash
ls -l /dev/disk/by-uuid/
drwxr-xr-x 2 root root 140 May 11 14:25 .
drwxr-xr-x 6 root root 120 May 10 20:20 ..
lrwxrwxrwx 1 root root  11 May 11 14:25 303A-39D1 -> ../../loop1
lrwxrwxrwx 1 root root  15 May 11 13:56 52AA-6867 -> ../../mmcblk1p1
lrwxrwxrwx 1 root root  11 May 11 14:25 5573dd9c-6ad9-40d1-918b-cc8d6ee65777 -> ../../loop2
lrwxrwxrwx 1 root root  15 May 11 14:07 e139ce78-9841-40fe-8823-96a304a09859 -> ../../mmcblk1p2
lrwxrwxrwx 1 root root   9 May 10 20:20 f0568afc-0bfb-483c-9572-257949b07d6d -> ../../sda
```

## Mount the image
```bash
sudo mount -o rw,loop,offset=135266304 /dev/loop2 /mnt/temp
# create the boot dir if missing
# sudo mkdir /mnt/temp/boot
sudo mount -o rw,loop,offset=1048576 /dev/loop1 /mnt/temp/boot
```

## Perform the backup
```bash
sudo rsync -aAX / --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} /mnt/temp/
```

## Edit the fstab and replace the UUIDs that matter
```bash
sudo vi /mnt/temp/etc/fstab
```

## Unmount and finish
```bash
btrfs check --repair /dev/loop2
sudo umount /mnt/temp/boot; sudo umount /mnt/temp;
sudo losetup -d /dev/loop1; sudo losetup -d /dev/loop2;
```