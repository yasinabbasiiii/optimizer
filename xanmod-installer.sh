#!/bin/bash

set -e

# Colors
green()  { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }
red()    { echo -e "\033[1;31m$*\033[0m"; }

# Check for root
if [[ $EUID -ne 0 ]]; then
  red "[!] This script must be run as root."
  exit 1
fi

# CPU level detection based on feature flags
detect_cpu_level() {
  FLAGS=$(grep -m1 -oP '^flags\s+:\s+\K.+' /proc/cpuinfo | tr '\n' ' ')

  level=0
  [[ $FLAGS =~ (lm.*cmov.*cx8.*fpu.*fxsr.*mmx.*syscall.*sse2) ]] && level=1
  [[ $FLAGS =~ (cx16.*lahf_lm.*popcnt.*sse4_1.*sse4_2.*ssse3) ]] && level=2
  [[ $FLAGS =~ (avx.*avx2.*bmi1.*bmi2.*fma.*abm.*movbe.*xsave) ]] && level=3
  [[ $FLAGS =~ (avx512f.*avx512bw.*avx512cd.*avx512dq.*avx512vl) ]] && level=4

  echo "$level"
}

cpu_level=$(detect_cpu_level)

if [[ $cpu_level -lt 1 ]]; then
  red "[!] CPU not supported by XanMod kernel (no compatible instruction sets detected)."
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
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http
