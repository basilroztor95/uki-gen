#! /bin/bash
echo "rd.luks.uuid=$(cryptsetup luksUUID /dev/nvme0n1p2) root=UUID=$(blkid -s UUID -o value /dev/mapper/rootfs)" > /boot/cmdline
