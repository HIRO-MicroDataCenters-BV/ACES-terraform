#!/usr/bin/env bash
set -x
set -u
set -e

if $(mountpoint /var -q)
then
    echo /var is already mounted! Exiting...
    exit 0
fi
DEVICE=${1:-/dev/nvme1n1}

parted --script "$DEVICE" \
    mklabel msdos \
    mkpart primary 2MiB 100%

mkfs.ext4 ${DEVICE}p1
e2label ${DEVICE}p1 VAR

mkdir /var2
mount ${DEVICE}p1 /var2
rsync -a /var/ /var2

cat >> /etc/fstab <<EOF
LABEL=VAR /var ext4 defaults 0 2
EOF

echo /var configuration done! Rebooting...
reboot
