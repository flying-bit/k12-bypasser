#!/bin/bash
# ============================================
#  K12NET USB AUTORUN - SİSTEM KURULUM SCRİPTİ
#  Bu script bir kez çalıştırılır ve sisteme
#  USB autorun kuralını yazar.
# ============================================

KIRMIZI='\033[0;31m'
YESIL='\033[0;32m'
SARI='\033[1;33m'
MAVI='\033[0;34m'
SIFIRLA='\033[0m'

echo -e "${MAVI}======================================${SIFIRLA}"
echo -e "${MAVI}  K12NET USB AUTORUN KURULUM ARACI   ${SIFIRLA}"
echo -e "${MAVI}======================================${SIFIRLA}\n"

# Root kontrolü
if [ "$EUID" -ne 0 ]; then
    echo -e "${SARI}Root yetkisi gerekli. sudo ile tekrar deneniyor...${SIFIRLA}"
    sudo bash "$0"
    exit $?
fi

echo -e "${YESIL}[1/4] udev kuralı yazılıyor...${SIFIRLA}"

# USB takılınca tetiklenecek udev kuralı
cat > /etc/udev/rules.d/99-k12net-usb.rules << 'EOF'
# K12Net USB Autorun Kuralı
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", \
  ENV{ID_BUS}=="usb", \
  RUN+="/bin/bash -c 'sleep 3 && /usr/local/bin/k12net_usb_tetikle.sh %E{DEVNAME} &'"
EOF

echo -e "${YESIL}  ✓ /etc/udev/rules.d/99-k12net-usb.rules oluşturuldu${SIFIRLA}"

echo -e "\n${YESIL}[2/4] Tetikleyici script yazılıyor...${SIFIRLA}"

# USB takılınca çalışacak tetikleyici
cat > /usr/local/bin/k12net_usb_tetikle.sh << 'TETIKLEYICI'
#!/bin/bash
# USB takılınca çalışan tetikleyici

AYGIT="$1"
LOG="/tmp/k12net_usb.log"

echo "$(date) - USB takıldı: $AYGIT" >> "$LOG"

# Mount noktasını bul
sleep 2
MOUNT_NOKTASI=$(lsblk -o MOUNTPOINT "$AYGIT" 2>/dev/null | tail -1 | tr -d ' ')

if [ -z "$MOUNT_NOKTASI" ]; then
    # Alternatif yol: /media altında ara
    MOUNT_NOKTASI=$(findmnt -rn -o TARGET "$AYGIT" 2>/dev/null)
fi

if [ -z "$MOUNT_NOKTASI" ]; then
    # Kopyalama yoluyla mount bul
    sleep 3
    MOUNT_NOKTASI=$(lsblk -o MOUNTPOINT "$AYGIT" 2>/dev/null | grep '/' | head -1 | tr -d ' ')
fi

echo "$(date) - Mount noktası: $MOUNT_NOKTASI" >> "$LOG"

# USB'de k12net_bypass dosyasını ara
for DOSYA_ADI in "k12net_bypass" "bypass" "k12_kapat" "calistir"; do
    BYPASS="$MOUNT_NOKTASI/$DOSYA_ADI"
    if [ -f "$BYPASS" ]; then
        echo "$(date) - Program bulundu: $BYPASS" >> "$LOG"
        chmod +x "$BYPASS"
        # Tüm masaüstü oturumlarında çalıştır
        for KULLANICI_EV in /home/*/; do
            KULLANICI=$(basename "$KULLANICI_EV")
            DISPLAY_VAR=$(su - "$KULLANICI" -c 'echo $DISPLAY' 2>/dev/null)
            if [ -n "$DISPLAY_VAR" ]; then
                XAUTH=$(su - "$KULLANICI" -c 'echo $XAUTHORITY' 2>/dev/null)
                DISPLAY="$DISPLAY_VAR" XAUTHORITY="$XAUTH" sudo -u "$KULLANICI" "$BYPASS" >> "$LOG" 2>&1 &
            fi
        done
        # Root olarak da çalıştır (servisler için)
        "$BYPASS" >> "$LOG" 2>&1
        echo "$(date) - Program çalıştırıldı!" >> "$LOG"
        break
    fi
done
TETIKLEYICI

chmod +x /usr/local/bin/k12net_usb_tetikle.sh
echo -e "${YESIL}  ✓ /usr/local/bin/k12net_usb_tetikle.sh oluşturuldu${SIFIRLA}"

echo -e "\n${YESIL}[3/4] udev kuralları yeniden yükleniyor...${SIFIRLA}"
udevadm control --reload-rules
udevadm trigger
echo -e "${YESIL}  ✓ udev yeniden yüklendi${SIFIRLA}"

echo -e "\n${YESIL}[4/4] Kurulum tamamlandı!${SIFIRLA}"
echo -e "\n${MAVI}======================================${SIFIRLA}"
echo -e "${YESIL}  KURULUM BAŞARILI!${SIFIRLA}"
echo -e "${MAVI}======================================${SIFIRLA}"
echo -e "\nArtık USB'nize ${SARI}k12net_bypass${SIFIRLA} dosyasını koyun."
echo -e "USB takıldığında otomatik çalışacak!\n"
echo -e "${SARI}Log dosyası: /tmp/k12net_usb.log${SIFIRLA}\n"
