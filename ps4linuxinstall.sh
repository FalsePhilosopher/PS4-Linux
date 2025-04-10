#!/bin/bash
mountdir="/mnt/psxitarch"
bootdir="/mnt/ps4boot"
declare -A TOOLS=(
    [zstd]="zstd"
    [7z]="p7zip-full"
    [gh]="gh"
)
MISSING=()

for cmd in "${!TOOLS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING+=("$cmd")
    fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
    echo "All required tools are installed."
else
    echo "The following tools are missing:"
    for tool in "${MISSING[@]}"; do
        echo "  - $tool"
    done
    read -rp "Would you like to install them now? [y/N]: " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if command -v apt &> /dev/null; then
    PM="apt"
    UPDATE="sudo apt update"
    INSTALL="sudo apt install -y"
elif command -v dnf &> /dev/null; then
    PM="dnf"
    UPDATE="sudo dnf check-update"
    INSTALL="sudo dnf install -y"
elif command -v pacman &> /dev/null; then
    PM="pacman"
    UPDATE="sudo pacman -Sy"
    INSTALL="sudo pacman -S --noconfirm"
else
    echo "No supported package manager found (apt, dnf, pacman)."
    exec $0
fi
echo "Using $PM to install packages..."
eval "$UPDATE"
for tool in "${MISSING[@]}"; do
    if [[ "$tool" == "gh" && "$PM" == "apt" ]]; then
        type -p curl >/dev/null || sudo apt install -y curl
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
            sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
            sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install -y gh
    else
        # Adjust tool names for pacman or dnf if needed
        pkg="${TOOLS[$tool]}"
        if [[ "$PM" == "pacman" ]]; then
            [[ "$tool" == "7z" ]] && pkg="p7zip"
        elif [[ "$PM" == "dnf" ]]; then
            [[ "$tool" == "7z" ]] && pkg="p7zip"
        fi
        eval "$INSTALL $pkg"
    fi
done
    else
        echo "Installation skipped. Missing tools will cause issues."
    fi
fi

gh_dl() {
echo "Select a GitHub repo to pull from:"
echo " 1) Enter a custom repo"
echo " 2) FalsePhilosopher/PS4-Linux"
echo " 3) Example/Example"
echo " 4) Example/Example"
echo " 5) Example/Example"
echo " 6) Example/Example"
read -rp "Choose an option: " choice

case "$choice" in
    1) read -rp "Enter the repo owner/repo (i.e FalsePhilosopher/PS4-Linux): " repo ;;
    2) repo="FalsePhilosopher/PS4-Linux" ;;
    3) repo="Example/Example" ;;
    4) repo="Example/Example" ;;
    5) repo="Example/Example" ;;
    6) repo="Example/Example" ;;
esac

echo "Fetching release tags from GitHub..."
tags=$(curl -s "https://api.github.com/repos/$repo/releases" | jq -r '.[].tag_name')
if [[ -z "$tags" ]]; then
    echo "No releases found or failed to fetch tags."
    exec "$0"
fi

mapfile -t tag_array <<< "$tags"
echo "Available release tags:"
for i in "${!tag_array[@]}"; do
    printf "%2d) %s\n" "$((i+1))" "${tag_array[i]}"
done

read -rp "Select a release number: " tag_choice
if ! [[ "$tag_choice" =~ ^[0-9]+$ ]] || (( tag_choice < 1 || tag_choice > ${#tag_array[@]} )); then
    echo "Invalid selection."
    exec "$0"
fi
tag="${tag_array[$((tag_choice-1))]}"
echo "Selected tag: $tag"

if ! gh release download "$tag" -R "$repo"; then
    echo "Failed to download the release."
    exec "$0"
fi
}

ask() {
    read -rp "Is this a multi-part archive? (y/n): " is_multipart_input
    if [[ "$is_multipart_input" == "y" || "$is_multipart_input" == "Y" ]]; then
    is_multipart=true
    else
    is_multipart=false
    fi
read -rp "Enter the archive name without extension or multi part numbers(ie .tar.zst,.7z, or 01.tar.zst, 01.7z ): " archive_base
read -rp "Enter the archive extension(ie zst/xz/7z/gz): " archive_type
    if [[ "$archive_type" == "7z" ]]; then
    archive_name="${archive_base}.${archive_type}"
    else
    archive_name="${archive_base}.tar.${archive_type}"
    fi
}
list() {
echo "Listing external drives..."
    lsblk -dpno NAME,MODEL,SIZE | grep -vE "boot|rpmb|loop"

    read -rp "Enter the device to format (e.g. /dev/sdb): " drive

    if [[ ! -b "$drive" ]]; then
        echo "Invalid device: $drive"
        exec $0
    fi

    read -rp "ALL DATA ON $drive WILL BE LOST. Continue? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exec $0
    fi
}

part() {
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
    sudo mkdir -p "$mountdir" "$bootdir"
    
    echo "Mounting FAT32 partition..."
    sudo mount "${drive}1" "$bootdir"
    echo "Copying bzImage and initramfs.cpio.gz to FAT32 partition"
    sudo cp bzImage initramfs.cpio.gz "$bootdir/"
    sudo umount "$bootdir"
    
    echo "Mounting EXT4 partition"
    sudo mount "${drive}2" "$mountdir"
}

extract() {
    local target_path="$1"
    echo "Extracting archive to: $target_path"

    if [[ ! -d "$target_path" ]]; then
        echo "Error: '$target_path' is not a valid directory."
        exec $0
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
                sudo 7z x ${archive_base}*.${archive_type}* -o"$target_path"
            else
                sudo 7z x "$archive_name" -o"$target_path"
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

clean() {
    sudo umount "$mountdir"
    sudo umount "$bootdir"
    echo "Extraction complete."
    sudo rm -rf "$mountdir" "$bootdir"
    echo "All done."
}
    
echo "[1] Enter an extraction path"
echo "[2] Scan for a partition labeled psxitarch and extract OS to it"
echo "[3] Format an external drive for PS4 Linux and extract OS/bootloader to it"
echo "[4] Download an OS from a github release"
echo "[5] Download an OS from a github release, format an external drive for PS4 Linux and extract OS/bootloader to it"
read -rp "Choose an option (1, 2, 3, 4, 5): " choice
    case "$choice" in
    1)
    ask
    read -rp "Enter full path to extract the OS to(It's usually /media/$USER/psxitarch or /mnt/psxitarch): " manual_path
    extract "$manual_path"
    ;;
    2)
    echo "Scanning for partition with label psxitarch"
    device=$(lsblk -o NAME,LABEL,FSTYPE -nr | grep -E 'psxitarch' | awk '{print "/dev/" $1}' | head -n1)
    if [[ -n "$device" ]]; then
        mountpoint=$(lsblk -no MOUNTPOINT "$device")
        if [[ -z "$mountpoint" ]]; then
            echo "Partition is not mounted. Mounting..."
            sudo mkdir -p /mnt/psxitarch
            if sudo mount "$device" /mnt/psxitarch; then
                echo "Mounted $device to /mnt/psxitarch"
                candidate="/mnt/psxitarch"
            else
                echo "Failed to mount $device"
                exec $0
            fi
        else
            echo "Partition already mounted at: $mountpoint"
            candidate="$mountpoint"
        fi
        read -rp "Extract archive to this path? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            ask
            extract "$candidate"
            clean
        else
            echo "Aborted."
            exec $0
        fi
    else
        echo "No partition labeled psxitarch found"
        exec $0
    fi
    ;;
    3)
    list
    part
    ask
    echo "Copying PS4 Linux to EXT4 partition"
    extract "$mountdir"
    clean
    ;;
    4)
    gh_dl
    echo "All done."
    ;;
    5)
    gh_dl
    list
    part
    ls
    echo "The files are listed above"
    ask
    echo "Copying PS4 Linux to EXT4 partition"
    extract "$mountdir"
    clean
    ;;
    *)
    echo "Invalid choice."
    exec $0
    ;;
    esac
