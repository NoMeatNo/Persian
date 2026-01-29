#!/bin/bash
# Smart Scanner with Fixes

# رنگ‌ها
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}[1/4] Checking Environment...${NC}"

# ساخت فایل پروفایل اگر وجود ندارد (برای جلوگیری از ارور grep)
touch ~/.profile

# تنظیم SSL
if ! grep -q "SSL_CERT_FILE" ~/.profile; then
    echo 'export SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem' >> ~/.profile
    source ~/.profile
fi
export SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem

# چک کردن سلامت curl
if ! curl --version > /dev/null 2>&1; then
    echo -e "${RED}Critical Error: CURL is broken!${NC}"
    echo "Please run: pkg update -y && pkg upgrade -y"
    exit 1
fi

# نصب/چک کردن cfst
if [ ! -f "cfst" ]; then
    echo -e "${YELLOW}Installing CFST...${NC}"
    # استفاده از wget چون curl شما مشکل داشت (جهت اطمینان)
    wget -q -O cfst.tar.gz https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.3.4/cfst_linux_arm64.tar.gz
    tar -zxf cfst.tar.gz
    chmod +x cfst
    rm cfst.tar.gz
fi

echo -e "${CYAN}[2/4] Downloading IP List...${NC}"
rm -f ips-v4.txt raw_ips.txt

# دانلود لیست
curl -L -s "https://github.com/compassvpn/cf-tools/releases/latest/download/all_cdn_v4.txt" -o raw_ips.txt

if [ ! -s raw_ips.txt ]; then
    echo -e "${RED}Download Failed! trying wget...${NC}"
    wget -q -O raw_ips.txt "https://github.com/compassvpn/cf-tools/releases/latest/download/all_cdn_v4.txt"
fi

if [ ! -s raw_ips.txt ]; then
    echo -e "${RED}Error: Could not download IP list.${NC}"
    exit 1
fi

echo -e "${CYAN}[3/4] Randomizing IPs...${NC}"
> ips-v4.txt
shuf -n 500 raw_ips.txt | while read line; do
    clean_ip=$(echo $line | cut -d'/' -f1 | cut -d. -f1-3)
    echo "$clean_ip.$((RANDOM % 254 + 1))" >> ips-v4.txt
done

echo -e "${CYAN}[4/4] Scanning...${NC}"
echo "=================================================="

./cfst -f ips-v4.txt \
       -n 500 \
       -dn 10 \
       -tl 300 \
       -t 5 \
       -httping \
       -url https://speed.cloudflare.com/__down?bytes=2000000 \
       -o result.csv

echo "=================================================="
echo -e "${GREEN}Top IPs:${NC}"
if [ -f result.csv ]; then
    head -n 6 result.csv | awk -F, 'NR>1 {print "IP: " $1 " | Speed: " $2 " MB/s"}'
else
    echo -e "${RED}No result file generated.${NC}"
fi