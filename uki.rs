use std::process::Command;
use std::fs;
use std::io;
use std::io::prelude::*;
use std::str::FromStr;
use std::path::Path;

fn main() -> io::Result<()> {
    // Get user input for file paths
    let cmdline_path = get_user_input("Enter path to cmdline.txt: ")?;
    let ucode_img_path = get_user_input("Enter path to intel-ucode.img: ")?;
    let booster_img_path = get_user_input("Enter path to booster-linux.img: ")?;
    let vmlinuz_path = get_user_input("Enter path to vmlinuz-linux: ")?;

    // Combine intel-ucode.img and booster-linux.img into comb_initrd.img
    Command::new("cat")
        .args(&[&ucode_img_path, &booster_img_path])
        .output()?;
    
    // Extract SectionAlignment value from linuxx64.efi.stub
    let section_alignment_output = Command::new("objdump")
        .args(&["-p", "/usr/lib/systemd/boot/efi/linuxx64.efi.stub"])
        .output()?;
    let section_alignment = String::from_utf8_lossy(&section_alignment_output.stdout);
    let alignment: usize = section_alignment.lines()
        .find_map(|line| line.strip_prefix("SectionAlignment"))
        .and_then(|line| usize::from_str(line.trim()).ok())
        .unwrap_or(0);

    // Function to calculate section offset
    fn calculate_section_offset(file: &str, alignment: usize) -> io::Result<usize> {
        let metadata = fs::metadata(file)?;
        let size = metadata.len() as usize;

        let output = Command::new("objdump")
            .args(&["-h", "/usr/lib/systemd/boot/efi/linuxx64.efi.stub"])
            .output()?;
        let output_str = String::from_utf8_lossy(&output.stdout);
        let offset = output_str.lines()
            .filter(|line| line.split_whitespace().count() == 7)
            .find_map(|line| {
                let mut fields = line.split_whitespace();
                let start = usize::from_str_radix(fields.next()?, 16).ok()?;
                let end = usize::from_str_radix(fields.next()?, 16).ok()?;
                if start + end == size {
                    Some(start)
                } else {
                    None
                }
            })
            .unwrap_or(0);

        let result = size + offset + alignment - (offset % alignment);
        Ok(result)
    }

    // Create directory /efi/EFI/Linux if it doesn't exist
    let efi_linux_dir = "/efi/EFI/Linux";
    if !Path::new(efi_linux_dir).exists() {
        fs::create_dir_all(efi_linux_dir)?;
    }

    // Modify linuxx64.efi.stub with updated section offsets
    let commands = ["cmdline", "initrd", "linux"];
    let file_paths = [&cmdline_path, "/boot/comb_initrd.img", &vmlinuz_path];

    for (command, file_path) in commands.iter().zip(file_paths.iter()) {
        let section_offset = calculate_section_offset(file_path, alignment)?;
        let command_str = format!("objcopy --add-section .{}=\"{}\" --change-section-vma .{}=$(printf 0x%x {}) \"/usr/lib/systemd/boot/efi/linuxx64.efi.stub\" \"/efi/EFI/Linux/linux.efi\"", command, file_path, command, section_offset);
        Command::new("sh")
            .arg("-c")
            .arg(&command_str)
            .output()?;
    }

    Ok(())
}

// Function to get user input
fn get_user_input(prompt: &str) -> io::Result<String> {
    print!("{}", prompt);
    io::stdout().flush()?;
    let mut input = String::new();
    io::stdin().read_line(&mut input)?;
    Ok(input.trim().to_string())
}
