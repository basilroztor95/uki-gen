#!/bin/bash

# Exit immediately if a command exits with a non-zero status, if an unset variable is used, or if a pipeline fails
set -euo pipefail

# Define file paths
EFI_STUB="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"
COMBINED_INITRD="/boot/comb_initrd.img"
CMDLINE_TXT="/boot/cmdline.txt"
LINUX_KERNEL="/boot/vmlinuz-linux"
UCODE_IMG="/boot/intel-ucode.img"
INITRD_IMG="/boot/booster-linux.img"
OUTPUT_EFI="/efi/EFI/Linux/linux.efi"

# Function to check if required files exist
check_files_exist() {
    for file in "$@"; do
        if [[ ! -f $file ]]; then
            echo "Error: Required file $file does not exist." >&2
            exit 1
        fi
    done
}

# Function to calculate aligned offset
calculate_aligned_offset() {
    local base_offset=$1
    local size=$2
    local alignment=$3
    echo $((base_offset + size + alignment - (base_offset + size) % alignment))
}

# Function to calculate offsets and update EFI binary
update_efi_binary() {
    local align_hex
    local align
    local cmdline_size
    local initrd_size
    local linux_size
    local cmdline_offset_hex
    local cmdline_offset
    local initrd_offset
    local linux_offset

    # Get section alignment from EFI stub
    align_hex=$(objdump -p "$EFI_STUB" | awk '/SectionAlignment/ {print $2}')
    align=$((16#$align_hex))

    # Get sizes of cmdline, initrd, and kernel files
    cmdline_size=$(stat -Lc %s "$CMDLINE_TXT")
    initrd_size=$(stat -Lc %s "$COMBINED_INITRD")
    linux_size=$(stat -Lc %s "$LINUX_KERNEL")

    # Calculate cmdline offset
    cmdline_offset_hex=$(objdump -h "$EFI_STUB" | awk 'NF==7 {size=strtonum("0x"$3); offset=strtonum("0x"$4)} END {print size + offset}')
    cmdline_offset=$(calculate_aligned_offset "$cmdline_offset_hex" 0 "$align")
    initrd_offset=$(calculate_aligned_offset "$cmdline_offset" "$cmdline_size" "$align")
    linux_offset=$(calculate_aligned_offset "$initrd_offset" "$initrd_size" "$align")

    # Add sections to EFI stub
    objcopy \
        --add-section .cmdline="$CMDLINE_TXT" --change-section-vma .cmdline=$(printf 0x%x "$cmdline_offset") \
        --add-section .initrd="$COMBINED_INITRD" --change-section-vma .initrd=$(printf 0x%x "$initrd_offset") \
        --add-section .linux="$LINUX_KERNEL" --change-section-vma .linux=$(printf 0x%x "$linux_offset") \
        "$EFI_STUB" "$OUTPUT_EFI"
}

# Function to clean up temporary files
cleanup() {
    echo "Cleaning up temporary files..."
    rm -f "$COMBINED_INITRD"
}

# Set trap to clean up on exit
trap cleanup EXIT

# Main script execution
main() {
    echo "Checking if required files exist..."
    check_files_exist "$UCODE_IMG" "$INITRD_IMG" "$CMDLINE_TXT" "$LINUX_KERNEL" "$EFI_STUB"

    echo "Combining microcode and initrd images..."
    cat "$UCODE_IMG" "$INITRD_IMG" > "$COMBINED_INITRD"

    echo "Updating EFI binary..."
    update_efi_binary

    echo "EFI binary successfully created at $OUTPUT_EFI"
}

# Run the main function
main

