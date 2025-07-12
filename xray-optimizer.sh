
#!/bin/bash

set -e

green()  { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }
red()    { echo -e "\033[1;31m$*\033[0m"; }

if [ "$(id -u)" -ne 0 ]; then
  red "[!] Run this script as root."
  exit 1
fi

# CPU Level Detection
detect_cpu_level() {
  FLAGS=$(grep -m1 -oP '^flags\s+:\s+\K.+' /proc/cpuinfo | tr ' ' '\n')
  has_flag() { echo "$FLAGS" | grep -q "^$1$"; }

  level=0
  has_flag sse2 && level=1
  has_flag ssse3 && has_flag sse4_1 && has_flag sse4_2 && has_flag popcnt && has_flag cx16 && has_flag lahf_lm && level=2
  has_flag avx && has_flag avx2 && has_flag bmi1 && has_flag bmi2 && has_flag fma && has_flag abm && has_flag movbe && level=3
  has_flag avx512f && has_flag avx512bw && has_flag avx512cd && has_flag avx512dq && has_flag avx512vl && level=4
  echo "$level"
}

cpu_level=$(detect_cpu_level)
yellow "[🔍] Detected CPU Level: x64v$cpu_level"

# Check installed kernel
current_kernel=$(uname -r)
if echo "$current_kernel" | grep -q "xanmod"; then
  green "[✓] XanMod is already installed: $current_kernel"
  exit 0
fi

# Make sure apt-cache is ready
apt update -q

# Detect available XanMod versions
available_versions=$(apt-cache search linux-xanmod | awk '{print $1}' | grep '^linux-xanmod-x64v' | sort -V)

# Try to find the highest available version <= cpu_level
chosen_pkg=""
for (( i=cpu_level; i>=1; i-- )); do
  pkg="linux-xanmod-x64v$i"
  if echo "$available_versions" | grep -q "$pkg"; then
    chosen_pkg="$pkg"
    break
  fi
done

# Fallback to general kernel if nothing matched
if [ -z "$chosen_pkg" ]; then
  if apt-cache show linux-xanmod >/dev/null 2>&1; then
    chosen_pkg="linux-xanmod"
    yellow "[!] No specific x64vX found. Falling back to generic: $chosen_pkg"
  else
    red "[✘] No suitable XanMod package found. Exiting."
    exit 1
  fi
fi

# Confirm with user
read -p "Install $chosen_pkg now? (y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  yellow "[*] Installation cancelled."
  exit 0
fi

# Add XanMod repo if needed
if [ ! -f /usr/share/keyrings/xanmod-archive-keyring.gpg ]; then
  wget -qO- https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg
fi
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-release.list

# Install
apt update -q
apt install -y "$chosen_pkg"
green "[✓] $chosen_pkg installed. Please reboot to activate the new kernel."
