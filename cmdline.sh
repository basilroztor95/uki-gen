#! /bin/bash
echo "rd.luks.uuid=$(cryptsetup luksUUID /dev/sda2) root=UUID=$(blkid -s UUID -o value /dev/mapper/rootfs)" > /boot/cmdline.txt
