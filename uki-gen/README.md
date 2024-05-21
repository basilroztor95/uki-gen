# EFI Binary Creation Script

This script combines a microcode image, an initrd image, a kernel image, and a cmdline file into a single EFI binary. The script checks for required files, calculates aligned offsets, updates the EFI binary, and ensures temporary files are cleaned up upon completion or exit.

## Requirements

- Linux environment
- `objdump` and `objcopy` utilities (typically available in the `binutils` package)
- Required files:
  - EFI stub: `/usr/lib/systemd/boot/efi/linuxx64.efi.stub`
  - Cmdline: `/proc/cmdline`
  - Kernel image: `vmlinuz-linux`
  - Microcode image: `intel-ucode.img` or `amd-ucode.img`
  - Initrd image: `booster-linux.img` or `initramfs-linux.img`
 
  - Change this constants to your own in uki-gen.sh:
```bash
KERNEL="/path/to/kernel"
UCODE="/path/to/microcode"
INITRD="/path/to/initrd"
```

## Usage

1. **Ensure all required files are available**: The script checks for the existence of required files and will exit with an error message if any are missing. 

2. **Run the script**: Execute the script with appropriate permissions.
```bash
chmod +x uki-gen.sh
./uki-gen.sh
```

3. **Output**: The resulting EFI binary will be created at `/efi/EFI/Linux/linux.efi`.

## Script Details

### File Paths

- `EFI_STUB`: Path to the EFI stub (`/usr/lib/systemd/boot/efi/linuxx64.efi.stub`)
- `COMBINED_INITRD`: Path for the combined initrd image (`/tmp/comb_initrd.img`)
- `CMDLINE`: Path to the cmdline file (`/proc/cmdline`)
- `KERNEL`: Path to the kernel image (`/boot/vmlinuz-linux`)
- `UCODE`: Path to the microcode image (`/boot/intel-ucode.img`)
- `INITRD`: Path to the initrd image (`/boot/booster-linux.img`)
- `OUTPUT_EFI`: Path for the output EFI binary (`/efi/EFI/Linux/linux.efi`)

### Functions

#### `check_files_exist`

Checks if the specified files exist. If any file does not exist, the script exits with an error.

#### `calculate_aligned_offset`

Calculates the aligned offset for a given base offset, size, and alignment value.

#### `update_efi_binary`

- Retrieves section alignment from the EFI stub.
- Calculates sizes for cmdline, initrd, and kernel files.
- Calculates aligned offsets for each section.
- Adds sections to the EFI stub and updates their virtual memory addresses.

#### `cleanup`

Removes the temporary combined initrd image.

### Main Execution

1. **File Existence Check**: The script verifies the presence of all required files.
2. **Combine Microcode and Initrd**: Combines the microcode and initrd images into a single file.
3. **Update EFI Binary**: Updates the EFI binary with the combined initrd, kernel, and cmdline sections.
4. **Cleanup**: Ensures temporary files are removed upon script completion or exit.

### Trap for Cleanup

A trap is set to call the `cleanup` function on script exit, ensuring temporary files are always removed.

### Example with LUKS encryption rootfs and efibootmgr for creation entry

```bash
echo "rd.luks.uuid=$(cryptsetup luksUUID /dev/nvme0n1p2) root=UUID=$(blkid -s UUID -o value /dev/mapper/rootfs)" > /proc/cmdline
chmod +x uki-gen.sh
./uki-gen.sh
efibootmgr -c -d /dev/nvme0n1 -p 1 -l '\EFI\Linux\linux.efi' -u
```

### For automatic generate UKI when kernel or microcode update

- Move `uki-gen.sh` to `/urs/local/bin`
- Create pacman hook
 `/etc/pacman.d/hooks/update-uki.hook`

```
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux
Target = intel-ucode

[Action]
Description = Update linux.efi after kernel or microcode upgrade
When = PostTransaction
Exec = /usr/local/bin/uki-gen.sh
```
- Replace Targets with your own kernel and microcode packagas. Names must be match with names which uses in your package manager.

## Notes

- Ensure you have the necessary permissions to access and modify the specified files and directories.
- This script is designed to be run on systems that use systemd and have the appropriate files in place. Adjust paths and file names as needed for your specific environment.
