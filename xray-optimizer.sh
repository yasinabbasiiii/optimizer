
#!/bin/bash

set -e

green()  { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }
red()    { echo -e "\033[1;31m$*\033[0m"; }

if [ "$(id -u)" -ne 0 ]; then
  red "[!] Run this script as root."
  exit 1
fi

# === Optimize sysctl ===
backup_file="/etc/sysctl.conf.bak.$(date +%s)"
cp /etc/sysctl.conf "$backup_file"
yellow "[*] Backed up /etc/sysctl.conf to $backup_file"

cat > /etc/sysctl.conf <<EOF
fs.file-max = 1000000
net.core.netdev_max_backlog = 16384
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.somaxconn = 65535
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 600
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
EOF

sysctl -p
green "[+] sysctl settings applied."

# === Set unlimited ulimit ===
limits_conf="/etc/security/limits.conf"
if ! grep -q 'nofile' $limits_conf; then
  cat >> $limits_conf <<EOF

* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
  green "[+] Updated ulimit in limits.conf"
fi

pam_file="/etc/pam.d/common-session"
if ! grep -q pam_limits.so $pam_file; then
  echo "session required pam_limits.so" >> $pam_file
  green "[+] Enabled pam_limits in PAM config"
fi

# === XanMod Installer with Smart Fallback ===

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

current_kernel=$(uname -r)
if echo "$current_kernel" | grep -q "xanmod"; then
  green "[✓] XanMod is already installed: $current_kernel"
  exit 0
fi

apt update -q
available_versions=$(apt-cache search linux-xanmod | awk '{print $1}' | grep '^linux-xanmod-x64v' | sort -V)

chosen_pkg=""
for (( i=cpu_level; i>=1; i-- )); do
  pkg="linux-xanmod-x64v$i"
  if echo "$available_versions" | grep -q "$pkg"; then
    chosen_pkg="$pkg"
    break
  fi
done

if [ -z "$chosen_pkg" ]; then
  if apt-cache show linux-xanmod >/dev/null 2>&1; then
    chosen_pkg="linux-xanmod"
    yellow "[!] No x64vX kernel found. Fallback to: $chosen_pkg"
  else
    red "[✘] No suitable XanMod kernel package found."
    exit 1
  fi
fi

read -p "Install $chosen_pkg now? (y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  yellow "[*] Installation cancelled."
  exit 0
fi

if [ ! -f /usr/share/keyrings/xanmod-archive-keyring.gpg ]; then
  wget -qO- https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg
fi
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-release.list

apt update -q
apt install -y "$chosen_pkg"
green "[✓] $chosen_pkg installed. Reboot to activate new kernel."
