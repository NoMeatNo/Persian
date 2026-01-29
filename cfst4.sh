#!/bin/bash
# Ultimate Cloudflare Scanner for Termux (POCO X3)
# Features: Auto-Fix Env, Auto-Install, Fast Scan

# رنگ‌ها
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# تابع برای بررسی و تعمیر محیط ترموکس
function check_env() {
    # 1. فیکس کردن ارورهای SSL
    if ! grep -q "SSL_CERT_FILE" ~/.profile; then
        echo 'export SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem' >> ~/.profile
        export SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem
    fi
    
    # 2. بررسی سلامت curl (اگر خراب باشد، تعمیر می‌کند)
    if ! curl --version > /dev/null 2>&1; then
        echo -e "${RED}Critical Error: System libraries are broken!${NC}"
        echo -e "${YELLOW}Fixing environment (This happens once)...${NC}"
        pkg update -y && pkg upgrade -y
        pkg install curl wget tar -y
    fi

    # 3. نصب CFST اگر وجود نداشته باشد
    if [ ! -f "cfst" ]; then
        echo -e "${CYAN}Installing CloudflareSpeedTest...${NC}"
        wget -q -O cfst.tar.gz https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.3.4/cfst_linux_arm64.tar.gz
        if [ $? -ne 0 ]; then
            echo -e "${RED}Download failed! Check internet.${NC}"
            exit 1
        fi
        tar -zxf cfst.tar.gz
        chmod +x cfst
        rm cfst.tar.gz
    fi
}

# اجرای بررسی محیط
check_env

echo -e "${CYAN}[1/3] Downloading latest IP list...${NC}"
rm -f ips-v4.txt raw_ips.txt

# دانلود لیست CompassVPN
curl -L -s --connect-timeout 5 "https://github.com/compassvpn/cf-tools/releases/latest/download/all_cdn_v4.txt" -o raw_ips.txt

# اگر curl نتوانست، با wget تلاش کن
if [ ! -s raw_ips.txt ]; then
    wget -q -O raw_ips.txt "https://github.com/compassvpn/cf-tools/releases/latest/download/all_cdn_v4.txt"
fi

if [ ! -s raw_ips.txt ]; then
    echo -e "${RED}Error: Failed to download IP list.${NC}"
    exit 1
fi

echo -e "${CYAN}[2/3] Processing IPs...${NC}"
> ips-v4.txt
# انتخاب رندوم ۵۰۰ رنج و تبدیل به آی‌پی
shuf -n 500 raw_ips.txt | while read line; do
    clean_ip=$(echo $line | cut -d'/' -f1 | cut -d. -f1-3)
    echo "$clean_ip.$((RANDOM % 254 + 1))" >> ips-v4.txt
done

echo -e "${CYAN}[3/3] Scanning (HTTPing Mode)...${NC}"
echo "=================================================="

# اجرای اسکنر (تنظیمات بهینه برای POCO X3)
./cfst -f ips-v4.txt \
       -n 500 \
       -dn 10 \
       -tl 300 \
       -t 5 \
       -httping \
       -url https://speed.cloudflare.com/__down?bytes=2000000 \
       -o result.csv

echo "=================================================="
if [ -f result.csv ]; then
    echo -e "${GREEN}Top Fastest IPs:${NC}"
    # نمایش ۵ نتیجه برتر با فرمت خوانا
    head -n 6 result.csv | awk -F, 'NR>1 {printf "IP: %-15s | Speed: %-5s MB/s | Ping: %s ms\n", $1, $2, $4}'
else
    echo -e "${RED}No working IPs found. Try running again.${NC}"
fi