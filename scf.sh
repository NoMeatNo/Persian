#!/bin/bash
# Fixed Cloudflare Scanner (Original List + Syntax Fix)

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

function uploadtest(){
    # تست آپلود (بسیار مهم برای وی‌تو‌ری)
    dd if=/dev/zero of=upload_test.dat bs=512k count=1 > /dev/null 2>&1
    up_speed=$(curl --resolve speed.cloudflare.com:443:$1 -X POST --data-binary @upload_test.dat https://speed.cloudflare.com/__up -o /dev/null -s --connect-timeout 2 --max-time 5 -w %{speed_upload})
    rm -f upload_test.dat
    up_kb=$(echo $up_speed | awk '{printf ("%d", $1/1024)}')
    echo $up_kb
}

function speedtesthttps(){
    rm -rf log.txt speed.txt
    # تست دانلود
    curl --resolve speed.cloudflare.com:443:$1 https://speed.cloudflare.com/__down?bytes=1000000 -o /dev/null --connect-timeout 2 --max-time 5 > log.txt 2>&1
    
    # --- رفع ارور خط 33 (Syntax Fix) ---
    # محاسبه سرعت کیلوبایت
    for i in $(cat log.txt | tr '\r' '\n' | awk '{print $NF}' | sed '1,3d;$d' | grep k | sed 's/k//g'); do
        k=$i
        k=$((k*1024))
        echo $k >> speed.txt
    done
    
    # محاسبه سرعت مگابایت
    for i in $(cat log.txt | tr '\r' '\n' | awk '{print $NF}' | sed '1,3d;$d' | grep M | sed 's/M//g'); do
        i=$(echo | awk "{print $i*10}")
        M=$i
        M=$((M*1024*1024/10))
        echo $M >> speed.txt
    done
    # ----------------------------------
    
    max=0
    if [ -f speed.txt ]; then
        for i in $(cat speed.txt); do
            if [ $i -ge $max ]; then max=$i; fi
        done
    fi
    rm -rf log.txt speed.txt
    echo $max
}

function cloudflaretest(){
    echo -e "${YELLOW}Generating random IPs from list...${NC}"
    mkdir -p rtt
    
    # ساخت آی‌پی رندوم از لیست اصلی
    n=0
    iplist=100
    > generated_ips.txt
    
    # استفاده از shuf برای انتخاب رندوم از لیست
    if [ -s ips-v4.txt ]; then
        shuf -n $iplist ips-v4.txt > generated_ips.txt
    else
        echo -e "${RED}Error: IP list is empty! Check internet connection.${NC}"
        return
    fi
    
    echo -e "${YELLOW}Testing Latency (RTT) for generated IPs...${NC}"
    
    while read ip; do
        # تولید اکتت آخر به صورت رندوم برای شانس بیشتر
        base_ip=$(echo $ip | cut -d. -f1-3)
        final_ip="$base_ip.$((RANDOM % 256))"
        
        # تست پینگ (هندشیک)
        http_code=$(curl --resolve speed.cloudflare.com:443:$final_ip https://speed.cloudflare.com/cdn-cgi/trace -o /dev/null -s --connect-timeout 1 --max-time 2 -w %{http_code})
        
        if [ "$http_code" == "200" ]; then
            echo "$final_ip" >> rtt/valid_ips.txt
            echo -e "Found alive IP: ${GREEN}$final_ip${NC}"
        fi
    done < generated_ips.txt

    if [ ! -f rtt/valid_ips.txt ]; then
        echo -e "${RED}No alive IPs found. Trying again might help.${NC}"
        return
    fi

    echo -e "${YELLOW}Starting Speed & Upload Test...${NC}"
    echo "========================================================"
    
    while read ip; do
        dl_speed=$(speedtesthttps $ip)
        dl_kb=$((dl_speed/1024))
        
        # شرط: دانلود بالای 500 کیلوبایت
        if [ $dl_kb -ge 500 ]; then
            echo -e "Checking Upload for $ip (Download: ${GREEN}$dl_kb KB/s${NC})..."
            ul_kb=$(uploadtest $ip)
            
            # شرط: آپلود بالای 50 کیلوبایت
            if [ $ul_kb -ge 50 ]; then 
                echo -e "${GREEN}✅ GOOD IP: $ip${NC}"
                echo -e "   ⬇️ DL: $dl_kb KB/s | ⬆️ UL: $ul_kb KB/s"
                echo "$ip | DL: $dl_kb KB/s | UL: $ul_kb KB/s" >> good_result.txt
            else
                echo -e "${RED}❌ Upload Failed for $ip${NC}"
            fi
        else
            echo -e "Skipping $ip (Low Speed: $dl_kb KB/s)"
        fi
    done < rtt/valid_ips.txt
    
    rm -rf rtt generated_ips.txt
    echo "========================================================"
    echo -e "${GREEN}Scan Finished. Results saved in 'good_result.txt'${NC}"
}

function datacheck(){
    echo "Downloading IP list from Baipiao (Original Source)..."
    rm -f ips-v4.txt
    # استفاده از لینک اصلی که در کد اورجینال بود
    curl -L --retry 2 -s https://www.baipiao.eu.org/cloudflare/ips-v4 -o ips-v4.txt
    
    # اگر لینک اول کار نکرد، لینک کمکی رسمی کلادفلر
    if [ ! -s ips-v4.txt ]; then
        echo "Main link failed. Trying backup..."
        curl -L --retry 2 -s https://www.cloudflare.com/ips-v4 -o ips-v4.txt
    fi
    echo "IP List Updated."
}

# --- شروع برنامه ---
clear
echo "----------------------------------------"
echo " Cloudflare Scanner (Syntax Fixed + Original List)"
echo "----------------------------------------"

# اگر فایل آی‌پی نبود، دانلود کن
if [ ! -f "ips-v4.txt" ]; then
    datacheck
fi

# سوال برای آپدیت لیست
read -p "Do you want to force update IP list? (y/n): " update_choice
if [ "$update_choice" == "y" ]; then
    datacheck
fi

cloudflaretest