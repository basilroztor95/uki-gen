#!/bin/bash

align="$(objdump -p /usr/lib/systemd/boot/efi/linuxx64.efi.stub | awk '{ if ($1 == "SectionAlignment"){print $2} }')"
align=$((16#$align))

osrel_offs="$(objdump -h "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" | awk 'NF==7 {size=strtonum("0x"$3); offset=strtonum("0x"$4)} END {print size + offset}')"
osrel_offs=$((osrel_offs + align - osrel_offs % align))

cmdline_offs=$((osrel_offs + $(stat -Lc%s "/usr/lib/os-release")))
cmdline_offs=$((cmdline_offs + align - cmdline_offs % align))

initrd_offs=$((cmdline_offs + $(stat -Lc%s "/boot/cmdline.txt")))
initrd_offs=$((initrd_offs + align - initrd_offs % align))

linux_offs=$((initrd_offs + $(stat -Lc%s "/boot/booster-linux.img")))
linux_offs=$((linux_offs + align - linux_offs % align))

echo "Offsets calculated:"
echo "OS Release: $osrel_offs"
echo "Cmdline: $cmdline_offs"
echo "Initrd: $initrd_offs"
echo "Linux: $linux_offs"
