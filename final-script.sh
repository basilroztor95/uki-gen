#!/bin/bash

calculate_offsets() {
    align_hex=$(objdump -p /usr/lib/systemd/boot/efi/linuxx64.efi.stub | awk '{ if ($1 == "SectionAlignment"){print $2} }')
    align=$((16#$align_hex))

    osrel_offs_hex=$(objdump -h "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" | awk 'NF==7 {size=strtonum("0x"$3); offset=strtonum("0x"$4)} END {print size + offset}')
    osrel_offs=$((osrel_offs_hex + align - osrel_offs_hex % align))

    cmdline_offs=$((osrel_offs + $(stat -Lc%s "/usr/lib/os-release")))
    cmdline_offs=$((cmdline_offs + align - cmdline_offs % align))

    initrd_offs=$((cmdline_offs + $(stat -Lc%s "/boot/cmdline.txt")))
    initrd_offs=$((initrd_offs + align - initrd_offs % align))

    linux_offs=$((initrd_offs + $(stat -Lc%s "/boot/booster-linux.img")))
    linux_offs=$((linux_offs + align - linux_offs % align))

    # Run objcopy with calculated offsets
    objcopy \
    --add-section .osrel="/usr/lib/os-release"      --change-section-vma .osrel=$(printf 0x%x $osrel_offs) \
    --add-section .cmdline="/boot/cmdline.txt"      --change-section-vma .cmdline=$(printf 0x%x $cmdline_offs) \
    --add-section .initrd="/boot/booster-linux.img" --change-section-vma .initrd=$(printf 0x%x $initrd_offs) \
    --add-section .linux="/boot/vmlinuz-linux"      --change-section-vma .linux=$(printf 0x%x $linux_offs) \
    "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" "linux.efi"
}

# Check if root user is executing the script
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

# Call the function to calculate offsets and run objcopy
calculate_offsets
