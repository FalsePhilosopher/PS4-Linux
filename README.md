# PS4-Linux

Mesa was compiled for arch.  
bzImage is [kernel 6.12.y](https://github.com/crashniels/linux) compiled with seccomp, zstd, zram, and btrfs support.

## PS4 Linux WSL installer
For those running windows you can [install WSL](https://learn.microsoft.com/en-us/windows/wsl/install#install-wsl-command) and install PS4 linux under WSL.
1. Open a WSL terminal
2. Copy and paste the code below to run the installer
```
wget -qO - https://github.com/FalsePhilosopher/PS4-Linux/raw/main/ps4linuxwsl.sh | bash
```
