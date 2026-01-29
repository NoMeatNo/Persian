#!/bin/bash
# Final Setup & Scan Script for POCO X3 (Termux)

# رنگ‌ها برای نمایش بهتر
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${CYAN}[1/5] Setting up environment & Dependencies...${NC}"
# 1. نصب پیش‌نیازها و فیکس SSL (بسیار مهم: این‌ها باید اول باشند)
pkg update -y
pkg install wget tar curl libandroid-posix-semaphore -y

# اعمال تنظیمات SSL برای جلوگیری از ارور در تست HTTPing
export SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem
# برای اطمینان، این خط را به پروفایل هم اضافه می‌کنیم که دفعات بعد نیاز نباشد
if ! grep -q "SSL_CERT_FILE" ~/.profile; then
    echo 'export SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem' >> ~/.profile
fi

echo -e "${CYAN}[2/5] Downloading CFST Binary (v2.3.4)...${NC}"
# 2. دانلود و نصب برنامه اصلی
wget -q -O cfst.tar.gz https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.3.4/cfst_linux_arm64.tar.gz
tar -zxf cfst.tar.gz
chmod +x cfst

echo -e "${CYAN}[3/5] Downloading IP List (CompassVPN)...${NC}"
# 3. دانلود لیست آی‌پی
rm -f ips-v4.txt raw_ips.txt
curl -L -s "https://github.com/compassvpn/cf-tools/releases/latest/download/all_cdn_v4.txt" -o raw_ips.txt

if [ ! -s raw_ips.txt ]; then
    echo -e "${YELLOW}Download failed. Retrying...${NC}"
    curl -L -s "https://github.com/compassvpn/cf-tools/releases/latest/download/all_cdn_v4.txt" -o raw_ips.txt
fi

echo -e "${CYAN}[4/5] Processing IP Ranges...${NC}"
# 4. پردازش و رندوم‌سازی آی‌پی‌ها
> ips-v4.txt
shuf -n 500 raw_ips.txt | while read line; do
    # حذف /24 و ساخت بخش چهارم به صورت رندوم
    clean_ip=$(echo $line | cut -d'/' -f1 | cut -d. -f1-3)
    echo "$clean_ip.$((RANDOM % 254 + 1))" >> ips-v4.txt
done

echo -e "${CYAN}[5/5] Starting Scan (HTTPing Mode)...${NC}"
echo "=================================================="
# 5. اجرای اسکن نهایی
# این دستور دقیقاً همان دستوری است که خواستید
./cfst -f ips-v4.txt \
       -n 500 \
       -dn 10 \
       -tl 300 \
       -t 5 \
       -httping \
       -url https://speed.cloudflare.com/__down?bytes=2000000 \
       -o result.csv

echo "=================================================="
echo -e "${GREEN}Scan Finished! Best IPs:${NC}"
# نمایش ۵ نتیجه برتر
head -n 6 result.csv | awk -F, 'NR>1 {print "IP: " $1 " | Speed: " $2 " MB/s | Ping: " $4}'