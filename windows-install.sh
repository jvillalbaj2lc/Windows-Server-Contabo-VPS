#!/bin/bash

set -e

# 💣 Limpiar el disco por completo
echo "💣 Limpiando disco /dev/sda..."
sgdisk --zap-all /dev/sda
wipefs -a /dev/sda

# 🧱 Instalar dependencias
apt update -y && apt upgrade -y
apt install grub2 wimtools ntfs-3g rsync wget -y

# 💾 Usar un valor seguro de 75GB (en MB)
disk_size_mb=76800  # 75 GB exactos
part1_size_mb=$((disk_size_mb / 4))         # 25% para GRUB
part2_start_mb=$((part1_size_mb))
part2_end_mb=$((disk_size_mb - 8))          # Reservamos 8 MB para evitar errores

echo "🧮 Tamaño total: ${disk_size_mb} MB — Partición 1: ${part1_size_mb} MB, Partición 2 hasta: ${part2_end_mb} MB"

# 🧱 Crear tabla GPT y particiones
parted /dev/sda --script -- mklabel gpt
parted /dev/sda --script -- mkpart primary ntfs 1MB ${part1_size_mb}MB
parted /dev/sda --script -- mkpart primary ntfs ${part2_start_mb}MB ${part2_end_mb}MB

# 🧠 Forzar lectura de nueva tabla
for i in {1..3}; do
  partprobe /dev/sda
  sleep 5
done

# 🧼 Formatear particiones
mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2
echo "✅ Particiones NTFS creadas correctamente"

# 🛠 Reparar GPT
echo -e "r\ng\np\nw\nY\n" | gdisk /dev/sda

# 📁 Montar particiones
mount /dev/sda1 /mnt
mkdir -p ~/windisk
mount /dev/sda2 ~/windisk

# 🧩 Instalar GRUB
grub-install --root-directory=/mnt /dev/sda

# 📝 Crear configuración de GRUB
mkdir -p /mnt/boot/grub
cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "windows installer" {
    insmod ntfs
    search --set=root --file=/bootmgr
    ntldr /bootmgr
    boot
}
EOF

# ⬇️ Descargar ISO de Windows
cd ~/windisk
mkdir -p winfile
wget -O win10.iso --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" https://bit.ly/3UGzNcB

# 📦 Extraer ISO a partición de arranque
mount -o loop win10.iso winfile
rsync -avz --progress winfile/* /mnt
umount winfile

# ⬇️ Descargar drivers VirtIO
wget -O virtio.iso https://bit.ly/4d1g7Ht
mount -o loop virtio.iso winfile

# 📁 Agregar drivers a carpeta del instalador
mkdir -p /mnt/sources/virtio
rsync -avz --progress winfile/* /mnt/sources/virtio
umount winfile

# 🧪 Integrar VirtIO al instalador
cd /mnt/sources
echo 'add virtio /virtio_drivers' > cmd.txt
wimlib-imagex update boot.wim 2 < cmd.txt

echo "🎉 Instalación lista. Reiniciando VPS..."
reboot
