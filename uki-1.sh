#!/bin/bash

cat /boot/intel-ucode.img /boot/booster-linux.img > /boot/comb_initrd.img

section_alignment=$(objdump -p /usr/lib/systemd/boot/efi/linuxx64.efi.stub | awk '/SectionAlignment/ {print $2}')

calculate_section_offset() {
    local size=$(stat -Lc%s "$1")
    local offset=$(objdump -h "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" | awk -v size="$size" 'NF==7 {print strtonum("0x"$3) + strtonum("0x"$4)}')
    echo $(( (size + offset + section_alignment - offset % section_alignment) ))
}

objcopy \
    --add-section .cmdline="/boot/cmdline.txt"      --change-section-vma .cmdline=$(printf 0x%x $(calculate_section_offset "/boot/cmdline.txt")) \
    --add-section .initrd="/boot/comb_initrd.img"   --change-section-vma .initrd=$(printf 0x%x $(calculate_section_offset "/boot/comb_initrd.img")) \
    --add-section .linux="/boot/vmlinuz-linux"      --change-section-vma .linux=$(printf 0x%x $(calculate_section_offset "/boot/vmlinuz-linux")) \
    "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" "/efi/EFI/Linux/linux.efi"
