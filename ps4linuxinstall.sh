#!/bin/bash
mountdir="/mnt/psxitarch"
bootdir="/mnt/ps4boot"
declare -A TOOLS=(
    [zstd]="zstd"
    [7z]="p7zip-full"
    [gh]="gh"
    [curl]="curl"
    [openssl]="openssl"
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
# Mega download function grabbed from https://gist.github.com/zanculmarktum/170b94764bd9a3da31078580ccea8d7e
# Function to handle MEGA download and metadata extraction
# Copyright 2018, 2019, 2020 Azure Zanculmarktum
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
mdl() {
	local URL="$1"

	if [[ ! $URL =~ ^https?://mega(\.co)?\.nz ]]; then
		echo "Invalid MEGA URL." >&2
		return 1
	fi

	CURL="curl -Y 1 -y 10"

	for cmd in openssl; do
		if ! command -v "$cmd" &>/dev/null; then
			echo "Missing required command: $cmd" >&2
			return 1
		fi
	done

	if [[ $URL =~ .*/file/[^#]*#[^#]* ]]; then
		id="${URL#*file/}"; id="${id%%#*}"
		key="${URL##*file/}"; key="${key##*#}"
	else
		id="${URL#*!}"; id="${id%%!*}"
		key="${URL##*!}"
	fi

	raw_hex=$(echo "${key}=" | tr '\-_' '+/' | tr -d ',' | base64 -d -i 2>/dev/null | od -v -An -t x1 | tr -d '\n ')
	hex=$(printf "%016x" \
		$(( 0x${raw_hex:0:16} ^ 0x${raw_hex:32:16} )) \
		$(( 0x${raw_hex:16:16} ^ 0x${raw_hex:48:16} ))
	)

	json=$($CURL -s -H 'Content-Type: application/json' -d '[{"a":"g", "g":"1", "p":"'"$id"'"}]' 'https://g.api.mega.co.nz/cs?id=&ak=') || return 1
	json="${json#"[{"}"; json="${json%"}]"}"
	file_url="${json##*'"g":'}"; file_url="${file_url%%,*}"; file_url="${file_url//'"'/}"

	json=$($CURL -s -H 'Content-Type: application/json' -d '[{"a":"g", "p":"'"$id"'"}]' 'https://g.api.mega.co.nz/cs?id=&ak=') || return 1
	at="${json##*'"at":'}"; at="${at%%,*}"; at="${at//'"'/}"

	json=$(echo "${at}==" | tr '\-_' '+/' | tr -d ',' | openssl enc -a -A -d -aes-128-cbc -K "$hex" -iv "00000000000000000000000000000000" -nopad | tr -d '\0')
	json="${json#"MEGA{"}"; json="${json%"}"}"
	file_name="${json##*'"n":'}"
	[[ $file_name == *,* ]] && file_name="${file_name%%,*}"
	file_name="${file_name//'"'/}"

	echo "Download URL: $file_url"
	echo "Filename: $file_name"
	echo "Decryption Key (K): $hex"
	echo "IV: ${raw_hex:32:16}0000000000000000"
	curl -s "$file_url" | openssl enc -d -aes-128-ctr -K "$hex" -iv "${raw_hex:32:16}0000000000000000" > "$file_name"
}

mfdl() {
echo "The links might change and vist the link in the echo for a direct download"
echo "1) PopOS 22.04 by Noob404 https://ps4linux.com/pop-os-22-04-ps4-release"
echo "2) Fedora 38 by DF_AUS https://ps4linux.com/forums/d/117-fedora-38-by-df-aus"
read -p "Choice: " choice
    case "$choice" in
    1)
        if ! wget "https://download2326.mediafire.com/r4fzjjbrnvsgbXtQ4ExtI-Amd3e2s4557WKENBcw0ZUn5ohniLtR7zVnUoMjY7FU7tTJqdjaAB1Gm4a79XomNpFnVyDHHHh-w39xvncuIIrDt_INKADNRZlJLkU-_RFdC8qrSuFsDP33Hkx0TzZ6AUciK3j1PrlMmDhy-5nIpin-/8kq3t69aoayh7ps/popos_22_04_ps4linux.tar.xz"; then
        echo "Failed to download the release."
        exec "$0"
        fi
        ;;
    2)
        if ! wget "https://download2391.mediafire.com/665wzuzhr9xgj8aHTYGHDecUIXGC0sze6nLBf7szAHhkNQUjmLlpEa4Ob22_xdnN5IYci6lt96b_9z4H30O8kQGTWIt0akYIML5w71Wir834FZR68ChPyvw8rcF7lroohcCv62b8cb0NHdkajYKvI-q_q-cIkQESrsQ9Uijno7ya/h2evdbzgk1zm7y4/psxitarch.tar.xz"; then
        echo "Failed to download the release."
        exec "$0"
        fi
        ;;
    q|Q) exec "$0"; ;;
    *) echo "Invalid option. Try again."; exec "$0" ;;
    esac
}

dmdl() {
echo "1) Psxitarch v3 by PS3ITA https://ps4linux.com/psxitarch-v3-ps4-distro-release/"
echo "2) ArchLinux PS4 v2 by whitehax0r https://github.com/whitehax0r/ArchLinux-PS4v2"
echo "3) SteamOS 3.0 by Nazky https://ps4linux.com/steamos-3-ps4-nazky/"
echo "4) Fedora 38 by DF_AUS https://ps4linux.com/forums/d/117-fedora-38-by-df-aus"
echo "6) Retrowave by Elive https://ps4linux.com/retrowave-linux-ps4-emulationstation/"
echo "7) Batocera by Noob404 User:root Pass:linux"
echo "q) Quit"
read -rp "Choice: " choice
    case "$choice" in
        1)
            if ! mdl "https://mega.nz/file/lIBCWCxa#Lq9oWyleu7W6Zcg_qeuKA0JQNOz1SzS-WTOQAGHQ7iY"; then
            echo "Failed to download the release."
            exec "$0"
            fi
            ;;
        2)
            if ! mdl "https://mega.nz/file/vn5glJbB#ZWSZA7scPuyx1UkOiM_UW7NoUxxMc_L3pJGiUWKbmRI"; then
            echo "Failed to download the release."
            exec "$0"
            fi
            ;;
        3)
            if ! mdl "https://mega.nz/file/dtQGET5Z#2Q-gWKt0Yjgtn8FCkRTlqs23YFjW2koGFshvfO65uUU"; then
            echo "Failed to download the release."
            exec "$0"
            fi
            ;;
        4)
            if ! mdl "https://mega.nz/file/PMNVEbhQ#jd9SB0MyscQlPMPf-DKb8TyulW0ahE3nsJjuWY9TUrc"; then
            echo "Failed to download the release."
            exec "$0"
            fi
            ;;
        5)
            if ! mdl "https://mega.nz/folder/S002hSJC#Qt4biffDx3tn3hmGX1nilw/file/34kxhLwQ"; then
            echo "Failed to download part 1 of the release"
            exec "$0"
            fi
            if ! mdl "https://mega.nz/folder/S002hSJC#Qt4biffDx3tn3hmGX1nilw/file/LtslUJbZ"; then
            echo "Failed to download part 2 of the release"
            exec "$0"
            fi
            ;;
        6)
            if ! mdl "https://mega.nz/file/PMNVEbhQ#jd9SB0MyscQlPMPf-DKb8TyulW0ahE3nsJjuWY9TUrc"; then
            echo "Failed to download the release."
            exec "$0"
            fi
            ;;
        7)
            if ! mdl "https://mega.nz/file/5jl1QIoA#K2wYgFMurOwTRZ6AZFbk7Ewt8tzXil92X8HyWq_RgI8"; then
            echo "Failed to download the release."
            exec "$0"
            fi
            ;;
        q|Q) exec "$0"; ;;
        *) echo "Invalid option. Try again."; exec "$0" ;;
    esac
}

ghdl() {
echo "Select a GitHub repo to pull from:"
echo " 1) Enter a custom repo"
echo " 2) FalsePhilosopher/PS4-Linux"
echo " 3) Example/Example"
echo " 4) Example/Example"
echo " 5) Example/Example"
echo " 6) Example/Example"
echo " Q) Quit"
read -rp "Choose an option: " choice

case "$choice" in
    1) read -rp "Enter the repo owner/repo (i.e FalsePhilosopher/PS4-Linux): " repo ;;
    2) repo="FalsePhilosopher/PS4-Linux" ;;
    3) repo="Example/Example" ;;
    4) repo="Example/Example" ;;
    5) repo="Example/Example" ;;
    6) repo="Example/Example" ;;
    q|Q) exec "$0";;
    *) echo "Invalid option. Try again."; exec "$0" ;;
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
echo "[5] Download an OS from mega.nz"
echo "[6] Download an OS from mediafire"
echo "[Q] Quit"
read -rp "Choose an option (1, 2, 3, 4, 5, 6): " choice
    case "$choice" in
    1)
    ask
    read -rp "Enter full path to extract the OS to(It's usually /media/$USER/psxitarch or /mnt/psxitarch): " manual_path
    extract "$manual_path"
    echo "All done."
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
    echo "All done."
    ;;
    3)
    list
    part
    ask
    echo "Copying PS4 Linux to EXT4 partition"
    extract "$mountdir"
    clean
    echo "All done."
    ;;
    4) ghdl; echo "All done."; exec "$0" ;;
    5) dmdl; echo "All done."; exec "$0" ;;
    6) mfdl; echo "All done."; exec "$0" ;;
    q|Q) exit 0 ;;
    *) echo "Invalid choice."; exec $0 ;;
    esac
