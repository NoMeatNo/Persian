#!/bin/bash
# Smart Scanner for POCO X3 (Daily Use)

# رنگ‌ها
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- بخش ۱: چک کردن نصب بودن برنامه (فقط بار اول اجرا می‌شود) ---
if [ ! -f "cfst" ]; then
    echo -e "${YELLOW}First time setup detected. Installing...${NC}"
    pkg update -y && pkg install wget tar curl libandroid-posix-semaphore -y
    
    # تنظیم SSL فقط اگر در پروفایل نباشد
    if ! grep -q "SSL_CERT_FILE" ~/.profile; then
        echo 'export SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem' >> ~/.profile
        export SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem
    fi

    # دانلود باینری
    echo -e "${CYAN}Downloading CFST...${NC}"
    wget -q -O cfst.tar.gz https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.3.4/cfst_linux_arm64.tar.gz
    tar -zxf cfst.tar.gz
    chmod +x cfst
    rm cfst.tar.gz
else
    # اگر نصب بود، فقط تنظیم SSL را برای اطمینان اعمال کن
    export SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem
fi

# --- بخش ۲: عملیات اصلی (همیشه اجرا می‌شود) ---

echo -e "${CYAN}[1/3] Getting fresh CompassVPN List...${NC}"
# حذف لیست‌های قدیمی
rm -f ips-v4.txt raw_ips.txt

# دانلود لیست جدید
curl -L -s "https://github.com/compassvpn/cf-tools/releases/latest/download/all_cdn_v4.txt" -o raw_ips.txt

# بررسی دانلود
if [ ! -s raw_ips.txt ]; then
    echo -e "${RED}List download failed! Check internet connection.${NC}"
    exit 1
fi

echo -e "${CYAN}[2/3] Randomizing IPs...${NC}"
> ips-v4.txt
# پردازش سریع ۵۰۰ آی‌پی
shuf -n 500 raw_ips.txt | while read line; do
    clean_ip=$(echo $line | cut -d'/' -f1 | cut -d. -f1-3)
    echo "$clean_ip.$((RANDOM % 254 + 1))" >> ips-v4.txt
done

echo -e "${CYAN}[3/3] Scanning...${NC}"
echo "=================================================="

# اجرای اسکنر
./cfst -f ips-v4.txt \
       -n 500 \
       -dn 10 \
       -tl 300 \
       -t 5 \
       -httping \
       -url https://speed.cloudflare.com/__down?bytes=2000000 \
       -o result.csv

echo "=================================================="
echo -e "${GREEN}Top Fastest IPs:${NC}"
# نمایش تمیز نتایج
head -n 6 result.csv | awk -F, 'NR>1 {print "IP: " $1 " | Speed: " $2 " MB/s | Ping: " $4}'