# PS4-Linux

You can find everything you need to know about PS4 linux in the [PS4Linux-Documentation](https://github.com/Hakkuraifu/PS4Linux-Documentation)
PS4 Linux payloads on 11.00 where compiled from this [repo](https://github.com/kmeps4/PS4-Linux-Loader)  
PS4 Linux payloads on 9.00 where downloaded from [PS4linux.com](https://ps4linux.com/downloads/)
The initramfs is from [Hippie68](https://github.com/hippie68/psxitarch-how-to/releases/tag/v1.00)
Mesa was compiled for arch.  
bzImage is [kernel 6.12.y](https://github.com/crashniels/linux) compiled with seccomp, zstd, zram, and btrfs support.

## PS4 Linux installer
For those running windows you can [install WSL](https://learn.microsoft.com/en-us/windows/wsl/install#install-wsl-command) and install PS4 linux under WSL.  

This has 5 options  
1 Enter a path to extract the OS to.  
2 Scan for a partition labeled psxitarch and extract the OS to it.  
3 Format an external drive for PS4 Linux and extract the OS/bootloader to it.  
4 Download an OS from a github release  
5 Download an OS from a github release, format an external drive for PS4 Linux and extract OS/bootloader to it.  

To start you need to have bzImage, initramfs.cpio.gz, and the ps4 distro to the same folder then.  
1. Open a terminal
2. cd to the folder with the files
3. Copy and paste the code below to run the installer
```
wget https://github.com/FalsePhilosopher/PS4-Linux/raw/main/ps4linuxinstall.sh
chmod +x ps4linuxinstall.sh
./ps4linuxinstall.sh
```

Feel free to submit a PR adding your distro repo to the installer.