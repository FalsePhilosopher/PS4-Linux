#!/bin/bash

read -p "Enter the archive base name (without .tar): " archive_base
read -p "Is the archive a .zst or .xz file? (zst/xz): " archive_type
ARCHIVE_NAME="${archive_base}.tar.${archive_type}*"
XZARCHIVE_NAME="${archive_base}.tar.${archive_type}"

extract_archive() {
    local target_path="$1"
    echo "Extracting archive to: $target_path"

    if [[ ! -d "$target_path" ]]; then
        echo "Error: '$target_path' is not a valid directory."
        exit 1
    fi

    if compgen -G "$ARCHIVE_NAME" > /dev/null; then
        case "$archive_type" in
            zst)
                cat $ARCHIVE_NAME | sudo tar -xvpf - --use-compress-program="unzstd -T0" --directory "$target_path"
                ;;
            xz)
                sudo tar -xvJpf $XZARCHIVE_NAME --directory "$target_path"
                ;;
            *)
                echo "Unsupported archive type: $archive_type"
                exit 1
                ;;
        esac
    else
        echo "No archive files matching '$ARCHIVE_NAME' found in current directory."
        exit 1
    fi
}

echo "[1] Scan for EXT4 partition named 'psxitarch'"
echo "[2] Format an external drive for PS4 Linux and extract"
echo "[3] Enter custom extraction path"
read -p "Choose an option (1, 2, or 3): " choice

if [[ "$choice" == "1" ]]; then
    echo "Scanning for external EXT4 partitions with label 'psxitarch'..."

    candidate=""
    while IFS= read -r line; do
        mount_point=$(echo "$line" | awk '{print $3}')
        label=$(lsblk -no LABEL "$mount_point" 2>/dev/null)
        fs_type=$(lsblk -no FSTYPE "$mount_point" 2>/dev/null)
        if [[ "$label" == "psxitarch" && "$fs_type" == "ext4" ]]; then
            candidate="$mount_point"
            break
        fi
    done < <(mount | grep '^/dev/' | grep '/mnt/')

    if [[ -n "$candidate" ]]; then
        echo "Found candidate mount point: $candidate"
        read -p "Extract archive to this path? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            extract_archive "$candidate"
        else
            echo "Aborted."
            exit 0
        fi
    else
        echo "No EXT4 partition labeled 'psxitarch' found under /mnt."
        exit 1
    fi

elif [[ "$choice" == "2" ]]; then
    echo "Listing external drives..."
    lsblk -dpno NAME,MODEL,SIZE | grep -vE "boot|rpmb|loop"

    read -p "Enter the device to format (e.g. /dev/sdb): " drive

    if [[ ! -b "$drive" ]]; then
        echo "Invalid device: $drive"
        exit 1
    fi

    read -p "ALL DATA ON $drive WILL BE LOST. Continue? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    echo "Wiping and partitioning $drive..."
    sudo parted -s "$drive" mklabel gpt
    sudo parted -s "$drive" mkpart primary fat32 1MiB 51MiB
    sudo parted -s "$drive" set 1 esp on

    total_size=$(lsblk -bno SIZE "$drive")
    fat32_end=$((51 * 1024 * 1024))
    swap_size=$((8 * 1024 * 1024 * 1024))
    ext4_end=$((total_size - swap_size))

    sudo parted -s "$drive" mkpart primary ext4 ${fat32_end}B ${ext4_end}B
    sudo parted -s "$drive" mkpart primary linux-swap ${ext4_end}B 100%

    sleep 1
    sudo mkfs.vfat "${drive}1"
    sudo mkfs.ext4 -L psxitarch "${drive}2"
    sudo mkswap "${drive}3"

    mountpoint="/mnt/psxitarch"
    boot_mount="/mnt/ps4boot"
    sudo mkdir -p "$mountpoint" "$boot_mount"
    
    echo "Mounting FAT32 partition..."
    sudo mount "${drive}1" "$boot_mount"
    echo "Copying bzImage and initramfs.cpio.gz to FAT32 partition..."
    sudo cp bzImage initramfs.cpio.gz "$boot_mount/"
    sudo umount "$boot_mount"
    
    echo "Mounting EXT4 partition..."
    sudo mount "${drive}2" "$mountpoint"
    echo "Copying PS4 Linux to EXT4 partition"
    extract_archive "$mountpoint"
    sudo umount "$mountpoint"
    echo "Extraction complete."

    echo "All done."

    exit 0

elif [[ "$choice" == "3" ]]; then
    read -p "Enter full path to extract the archive: " manual_path
    extract_archive "$manual_path"

else
    echo "Invalid choice."
    exit 1
fi
