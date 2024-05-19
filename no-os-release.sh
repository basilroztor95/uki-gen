#!/bin/bash

calculate_offsets() {
    
    align_hex=$(objdump -p /usr/lib/systemd/boot/efi/linuxx64.efi.stub | awk '{ if ($1 == "SectionAlignment"){print $2} }')
    align=$((16#$align_hex))


    cmdline_offs_hex=$(objdump -h "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" | awk 'NF==7 {size=strtonum("0x"$3); offset=strtonum("0x"$4)} END {print size + offset}')
    cmdline_offs=$((cmdline_offs_hex + align - cmdline_offs_hex % align))


    initrd_offs=$((cmdline_offs + $(stat -Lc%s "/boot/cmdline.txt")))
    initrd_offs=$((initrd_offs + align - initrd_offs % align))


    linux_offs=$((initrd_offs + $(stat -Lc%s "/boot/comb_initrd.img")))
    linux_offs=$((linux_offs + align - linux_offs % align))


    objcopy \
    --add-section .cmdline="/boot/cmdline.txt"      --change-section-vma .cmdline=$(printf 0x%x $cmdline_offs) \
    --add-section .initrd="/boot/comb_initrd.img" --change-section-vma .initrd=$(printf 0x%x $initrd_offs) \
    --add-section .linux="/boot/vmlinuz-linux"      --change-section-vma .linux=$(printf 0x%x $linux_offs) \
    "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" "/efi/EFI/Linux/linux.efi"
}


cat /boot/intel-ucode.img /boot/booster-linux.img > /boot/comb_initrd.img


calculate_offsets
