#!/bin/bash
read -rp "Is this a multi-part archive? (y/n): " is_multipart_input
if [[ "$is_multipart_input" == "y" || "$is_multipart_input" == "Y" ]]; then
    is_multipart=true
else
    is_multipart=false
fi
read -rp "Enter the archive name without extension or multi part numbers(ie .tar.zst,.7z, or 01.tar.zst, 01.7z ): " archive_base
read -rp "Enter the archive extension(ie zst/xz/7z/gz): " archive_type
archive_name=${archive_base}.tar.${archive_type}

extract_archive() {
    local target_path="$1"
    echo "Extracting archive to: $target_path"

    if [[ ! -d "$target_path" ]]; then
        echo "Error: '$target_path' is not a valid directory."
        exit 1
    fi

    case $archive_type in
        zst)
            if $is_multipart; then
                    cat ${archive_base}*.tar.${archive_type}* | sudo tar -xvpf - --use-compress-program="unzstd -T0" --directory "$target_path"
            else
                    sudo tar -xvpf "$archive_name" --use-compress-program="unzstd -T0" --directory "$target_path"
                fi
            ;;
        xz)
            if $is_multipart; then
                cat ${archive_base}*.tar.${archive_type}* | sudo tar -xvJpf - --directory "$target_path"
            else
                sudo tar -xvJpf "$archive_name" --directory "$target_path"
            fi
            ;;
        7z)
            if $is_multipart; then
                7z x ${archive_base}*.${archive_type}* -o "$target_path"
            else
                    7z x "${archive_base}.${archive_type}" -o "$target_path"
            fi
            ;;
        *)
            if $is_multipart; then
                cat ${archive_base}*.tar.${archive_type}* | sudo tar -xvpf - --directory "$target_path"
            else
                sudo tar -xvpf "$archive_name" --directory "$target_path"
            fi
            ;;
    esac
    }


echo "[1] Scan for EXT4 partition named 'psxitarch'"
echo "[2] Format an external drive for PS4 Linux and extract"
echo "[3] Enter custom extraction path"
read -rp "Choose an option (1, 2, or 3): " choice

if [[ "$choice" == "1" ]]; then
    echo "Scanning for external EXT4 partitions with label 'psxitarch'..."
    candidate=$(lsblk -o NAME,LABEL,FSTYPE,MOUNTPOINT | grep -E 'psxitarch.*ext4' | awk '{print $4}' | head -n1)
    if [[ -n "$candidate" ]]; then
        echo "Found candidate mount point: $candidate"
        read -rp "Extract archive to this path? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            extract_archive "$candidate"
        else
            echo "Aborted."
            exit 0
        fi
    else
        echo "No EXT4 partition labeled 'psxitarch' found"
        exit 1
    fi

elif [[ "$choice" == "2" ]]; then
    echo "Listing external drives..."
    lsblk -dpno NAME,MODEL,SIZE | grep -vE "boot|rpmb|loop"

    read -rp "Enter the device to format (e.g. /dev/sdb): " drive

    if [[ ! -b "$drive" ]]; then
        echo "Invalid device: $drive"
        exit 1
    fi

    read -rp "ALL DATA ON $drive WILL BE LOST. Continue? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    echo "Wiping and partitioning $drive..."
    sudo parted -s "$drive" mklabel gpt
    sudo parted -s "$drive" mkpart primary fat32 1MiB 51MiB
    sudo parted -s "$drive" set 1 esp on

    total_size=$(lsblk -bdno SIZE "$drive" | head -n1)
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
    sudo rm -rf "$mountpoint" "$boot_mount"
    echo "All done."

    exit 0

elif [[ "$choice" == "3" ]]; then
    read -rp "Enter full path to extract the archive(It's usually /media/$USER/psxitarch or /mnt/psxitarch): " manual_path
    extract_archive "$manual_path"

else
    echo "Invalid choice."
    exit 1
fi
