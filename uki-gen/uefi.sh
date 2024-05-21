#!/bin/bash
efibootmgr -c -d /dev/nvme0n1 -p 1 -l '\EFI\Linux\linux.efi' -u
