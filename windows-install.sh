#!/bin/bash

# Detect disk
if ls /dev/nvme0n1 >/dev/null 2>&1; then
  disk="/dev/nvme0n1"
  part1="/dev/nvme0n1p1"
  part2="/dev/nvme0n1p2"
else
  disk="/dev/sda"
  part1="/dev/sda1"
  part2="/dev/sda2"
fi

apt update -y && apt upgrade -y
apt install grub2 wimtools ntfs-3g -y

disk_size_gb=$(parted $disk --script print | awk "/^Disk ${disk}:/ {print int(\$3)}")
disk_size_mb=$((disk_size_gb * 1024))
part_size_mb=$((disk_size_mb / 4))

# Create partitions
parted $disk --script -- mklabel gpt
parted $disk --script -- mkpart primary ntfs 1MB ${part_size_mb}MB
parted $disk --script -- mkpart primary ntfs ${part_size_mb}MB $((2 * part_size_mb))MB

partprobe $disk
sleep 30
partprobe $disk
sleep 30
partprobe $disk
sleep 30

# Format partitions
mkfs.ntfs -f $part1
mkfs.ntfs -f $part2

echo "NTFS partitions created"

echo -e "r\ng\np\nw\nY\n" | gdisk $disk

mount $part1 /mnt

# Prepare directory for Windows disk
cd ~
mkdir windisk
mount $part2 windisk

grub-install --root-directory=/mnt $disk

#Edit GRUB configuration
cd /mnt/boot/grub
cat <<EOF > grub.cfg
menuentry "windows installer" {
	insmod ntfs
	search --set=root --file=/bootmgr
	ntldr /bootmgr
	boot
}
EOF

cd /root/windisk

mkdir winfile

wget -O win10.iso --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" https://bit.ly/3UGzNcB

mount -o loop win10.iso winfile

rsync -avz --progress winfile/* /mnt

umount winfile

wget -O virtio.iso https://bit.ly/4d1g7Ht

mount -o loop virtio.iso winfile

mkdir /mnt/sources/virtio

rsync -avz --progress winfile/* /mnt/sources/virtio

cd /mnt/sources

touch cmd.txt

echo 'add virtio /virtio_drivers' >> cmd.txt

wimlib-imagex update boot.wim 2 < cmd.txt

reboot


