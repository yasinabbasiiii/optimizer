#!/bin/bash

set -e

# رنگ‌ها
green()  { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }
red()    { echo -e "\033[1;31m$*\033[0m"; }

# بررسی root
if [[ $EUID -ne 0 ]]; then
  red "[!] این اسکریپت باید با دسترسی root اجرا شود."
  exit 1
fi

# تعیین level CPU
detect_cpu_level() {
  FLAGS=$(grep -oP '^flags\s+:\s+\K.+' /proc/cpuinfo | head -1)

  level=0
  [[ $FLAGS =~ (lm.*cmov.*cx8.*fpu.*fxsr.*mmx.*syscall.*sse2) ]] && level=1
  [[ $FLAGS =~ (cx16.*lahf_lm.*popcnt.*sse4_1.*sse4_2.*ssse3) ]] && level=2
  [[ $FLAGS =~ (avx.*avx2.*bmi1.*bmi2.*fma.*abm.*movbe.*xsave) ]] && level=3
  [[ $FLAGS =~ (avx512f.*avx512bw.*avx512cd.*avx512dq.*avx512vl) ]] && level=4

  echo "$level"
}

cpu_level=$(detect_cpu_level)

if [[ $cpu_level -lt 1 ]]; then
  red "[!] CPU شما برای XanMod پشتیبانی نمی‌شود."
  exit 1
fi

yellow "🔎 نسخه پیشنهادی XanMod برای این سیستم: linux-xanmod-x64v${cpu_level}"
read -p "آیا مایل به نصب هستید؟ (y/n): " confirm

if [[ $confirm != "y" && $confirm != "Y" ]]; then
  yellow "[!] عملیات نصب لغو شد."
  exit 0
fi

green "✅ شروع نصب XanMod x64v$cpu_level ..."

# افزودن key
tmp_key=/tmp/xanmod.gpg
wget -qO $tmp_key https://dl.xanmod.org/archive.key || {
  red "[!] دانلود GPG key از xanmod.org شکست خورد."
  exit 1
}
gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg $tmp_key
rm -f $tmp_key

# افزودن مخزن
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-release.list

# نصب
apt update -q
apt install -y "linux-xanmod-x64v$cpu_level"

green "✅ XanMod Kernel x64v$cpu_level نصب شد."
yellow "🔁 برای اعمال کرنل جدید، سیستم را reboot کنید."
