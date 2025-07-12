
#!/bin/bash

# === Ubuntu Optimizer for Xray High-Load Servers (Iran+Global Tunneling Setup) ===
# Version: 1.0 - Built on 2025-07-12
# Author: AI-generated, verified for production
# Use case: Xray servers handling 10K+ TCP connections via Tinc tunnel between Iran & global nodes.

set -e

# === Color Helpers ===
green()  { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }
red()    { echo -e "\033[1;31m$*\033[0m"; }

# === Check root ===
if [[ $EUID -ne 0 ]]; then
  red "[!] This script must be run as root."
  exit 1
fi

# === Backup sysctl ===
backup_file="/etc/sysctl.conf.bak.$(date +%s)"
cp /etc/sysctl.conf "$backup_file"
yellow "[*] Backed up /etc/sysctl.conf to $backup_file"

# === Apply Optimized sysctl Settings ===
cat > /etc/sysctl.conf <<EOF
# Optimized sysctl for high-concurrency Xray servers (Iran + Global)
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
green "[+] sysctl settings applied successfully."

# === Set high ulimit ===
ulimit_file="/etc/security/limits.conf"
if ! grep -q 'root.*nofile' $ulimit_file; then
  cat >> $ulimit_file <<EOF

# Allow high file descriptors for Xray
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
  green "[+] ulimit (nofile) increased to 1048576"
else
  yellow "[*] ulimit settings already exist in limits.conf"
fi

# === Persist PAM limits ===
pam_file="/etc/pam.d/common-session"
if ! grep -q pam_limits.so $pam_file; then
  echo "session required pam_limits.so" >> $pam_file
  green "[+] PAM limits enabled in $pam_file"
fi

# === Detect and confirm CPU level for XanMod ===
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
if [[ $cpu_level -lt 1 ]]; then
  red "[!] CPU does not support any XanMod optimized kernel variant."
else
  yellow "🔎 CPU Level Detected: x64v$cpu_level"
  read -p "Do you want to install XanMod kernel x64v$cpu_level now? (y/n): " confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    tmp_key=/tmp/xanmod.gpg
    wget -qO $tmp_key https://dl.xanmod.org/archive.key
    gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg $tmp_key
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-release.list
    apt update -q
    apt install -y "linux-xanmod-x64v$cpu_level"
    green "[+] XanMod x64v$cpu_level installed. Please reboot to activate it."
  else
    yellow "[*] XanMod installation skipped."
  fi
fi

# === Final Message ===
green "[✅] Optimization complete. Please reboot your server to apply all changes."

