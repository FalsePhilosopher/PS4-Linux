# PS4-Linux

PS4 Linux payloads on 11.00 where compiled from this [repo](https://github.com/kmeps4/PS4-Linux-Loader)  
Ps4 Linux payloads on 9.00 where downloaded from [PS4linux.com](https://ps4linux.com/downloads/)

Mesa was compiled for arch.  
bzImage is [kernel 6.12.y](https://github.com/crashniels/linux) compiled with seccomp, zstd, zram, and btrfs support.

## PS4 Linux WSL installer
For those running windows you can [install WSL](https://learn.microsoft.com/en-us/windows/wsl/install#install-wsl-command) and install PS4 linux under WSL.  
You need to download bzImage, initramfs.cpio.gz, and all the ps4distro.tar.zst parts or ps4distro.tar.xz to the same folder

1. Open a WSL terminal
2. cd to the folder with the files
2. Copy and paste the code below to run the installer
```
wget https://github.com/FalsePhilosopher/PS4-Linux/raw/main/ps4linuxinstall.sh
chmod +x ps4linuxinstall.sh
./ps4linuxinstall.sh
```
This has 3 options  
1 Scan for a mounted EXT4 partition named psxitarch and extract the OS to it.  
2 Format an external drive for PS4 Linux and extract the OS to it.  
3 Enter custom extraction path to extract the OS/bootloader to.  
4 Download an OS from a gh release, format an external drive for PS4 Linux and extract OS/bootloader to it.  
