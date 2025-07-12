#!/bin/bash

set -e

# Colors
green()  { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }
red()    { echo -e "\033[1;31m$*\033[0m"; }

# Must be root
if [[ $EUID -ne 0 ]]; then
  red "[!] This script must be run as root."
  exit 1
fi

# Extract flags
FLAGS=$(grep -m1 -oP '^flags\s+:\s+\K.+' /proc/cpuinfo | tr ' ' '\n')

has_flag() {
  echo "$FLAGS" | grep -q "^$1$"
}

# Default: not supported
cpu_level=0

# Check levels from low to high
if has_flag sse2; then
  cpu_level=1
fi

if has_flag ssse3 && has_flag sse4_1 && has_flag sse4_2 && has_flag popcnt && has_flag cx16 && has_flag lahf_lm; then
  cpu_level=2
fi

if has_flag avx && has_flag avx2 && has_flag bmi1 && has_flag bmi2 && has_flag fma && has_flag abm && has_flag movbe; then
  cpu_level=3
fi

if has_flag avx512f && has_flag avx512bw && has_flag avx512cd && has_flag avx512dq && has_flag avx512vl; then
  cpu_level=4
fi

if [[ $cpu_level -lt 1 ]]; then
  red "[!] CPU not supported by XanMod kernel (insufficient flags)."
  exit 1
fi

yellow "🔎 Detected CPU level: v$cpu_level"
yellow "💡 Recommended kernel: linux-xanmod-x64v$cpu_level"

read -p "Do you want to install this kernel? (y/n): " confirm

if [[ $confirm != "y" && $confirm != "Y" ]]; then
  yellow "[*] Installation cancelled."
  exit 0
fi

green "✅ Installing XanMod Kernel x64v$cpu_level..."

# Add GPG key
tmp_key=/tmp/xanmod.gpg
wget -qO $tmp_key https://dl.xanmod.org/archive.key || {
  red "[!] Failed to download GPG key from xanmod.org"
  exit 1
}
gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg $tmp_key
rm -f $tmp_key

# Add repository
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-release.list

# Install kernel
apt update -q
apt install -y "linux-xanmod-x64v$cpu_level"

green "✅ XanMod Kernel x64v$cpu_level installed successfully."
yellow "🔁 Please reboot your system to activate the new kernel."
