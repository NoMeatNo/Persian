#!/bin/bash
# Ultimate Cloudflare Scanner (Re-Run Friendly)
# Features: Auto-Fix, Auto-Clean, Ping Display

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Cleanup function (Runs on exit or Ctrl+C)
cleanup() {
    rm -f raw_ips.txt ips-v4.txt
}
trap cleanup EXIT

function check_env() {
    echo -e "${CYAN}[1/4] Checking Environment...${NC}"
    
    # 1. Prevent "grep" errors on fresh Termux
    touch ~/.profile

    # 2. Fix SSL Certificate issues
    if ! grep -q "SSL_CERT_FILE" ~/.profile; then
        echo 'export SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem' >> ~/.profile
        export SSL_CERT_FILE=$PREFIX/etc/tls/cert.pem
    fi
    
    # 3. Auto-Repair System if curl is broken
    if ! curl --version > /dev/null 2>&1; then
        echo -e "${RED}System libraries need repair...${NC}"
        echo -e "${YELLOW}Auto-fixing (This happens once)...${NC}"
        pkg update -y && pkg upgrade -y
        pkg install curl wget tar -y
    fi

    # 4. Install CFST if missing
    if [ ! -f "cfst" ]; then
        echo -e "${CYAN}Installing CloudflareSpeedTest...${NC}"
        wget -q -O cfst.tar.gz https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.3.4/cfst_linux_arm64.tar.gz
        if [ $? -ne 0 ]; then
            echo -e "${RED}Download failed! Check internet connection.${NC}"
            exit 1
        fi
        tar -zxf cfst.tar.gz
        chmod +x cfst
        rm cfst.tar.gz
    fi
}

check_env

echo -e "${CYAN}[2/4] Downloading IP list...${NC}"

# --- SAFETY CLEANUP FOR RE-RUNS ---
# We delete the old result file here so you never see old data
rm -f result.csv
# ----------------------------------

curl -L -s --connect-timeout 5 "https://github.com/compassvpn/cf-tools/releases/latest/download/all_cdn_v4.txt" -o raw_ips.txt

# Fallback if curl fails
if [ ! -s raw_ips.txt ]; then
    wget -q -O raw_ips.txt "https://github.com/compassvpn/cf-tools/releases/latest/download/all_cdn_v4.txt"
fi

if [ ! -s raw_ips.txt ]; then
    echo -e "${RED}Error: Failed to download IP list.${NC}"
    exit 1
fi

echo -e "${CYAN}[3/4] Generating Target IPs...${NC}"
> ips-v4.txt
shuf -n 500 raw_ips.txt | while read line; do
    clean_ip=$(echo $line | cut -d'/' -f1 | cut -d. -f1-3)
    echo "$clean_ip.$((RANDOM % 254 + 1))" >> ips-v4.txt
done

echo -e "${CYAN}[4/4] Scanning (HTTPing Mode)...${NC}"
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
if [ -f result.csv ]; then
    echo -e "${GREEN}Top Fastest IPs:${NC}"
    head -n 6 result.csv | awk -F, 'NR>1 {printf "IP: %-15s | Speed: %-5s MB/s | Ping: %s ms\n", $1, $2, $4}'
else
    echo -e "${RED}No working IPs found in this run.${NC}"
fi