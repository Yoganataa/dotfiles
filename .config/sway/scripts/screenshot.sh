#!/usr/bin/env bash

# -----------------------------------------------------
# KONFIGURASI DIREKTORI (STANDALONE / NO ML4W)
# -----------------------------------------------------

# Deteksi folder Pictures pengguna standar (XDG)
if [ -f ~/.config/user-dirs.dirs ]; then
    source ~/.config/user-dirs.dirs
    BASE_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}"
else
    BASE_DIR="$HOME/Pictures"
fi

# Folder penyimpanan hasil screenshot
SAVE_DIR="$BASE_DIR/Screenshots"
mkdir -p "$SAVE_DIR"

# Format nama file: Screenshot_YYYY-MM-DD_HH-MM-SS.png
NAME="Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

# Setup Notifikasi Sederhana
APP_NAME="Screen Capture"

notify_cmd() {
    notify-send -a "$APP_NAME" -i "camera-photo-symbolic" "$1" "$2" -t 2000
}

# -----------------------------------------------------
# FUNGSI UTAMA
# -----------------------------------------------------

# Fungsi Membuka Cliphist (Clipboard Manager)
open_cliphist() {
    # Cek apakah cliphist terinstall
    if ! command -v cliphist &> /dev/null; then
        notify_cmd "Error" "Cliphist tidak terinstall!"
        exit 1
    fi
    
    # Buka menu cliphist -> decode -> copy ke clipboard
    cliphist list | rofi -dmenu -i -p "Clipboard" -width 50 | cliphist decode | wl-copy
    
    if [ $? -eq 0 ]; then
        notify_cmd "Clipboard" "Item disalin ke clipboard!"
    fi
    exit 0
}

# Fungsi Menangkap Layar
# $1 = Mode (screen/output/area)
perform_capture() {
    local mode=$1
    local tmp_file="/tmp/$NAME"

    case $mode in
        "screen")
            grim "$tmp_file"
            ;;
        "output")
            # Mengambil monitor yang sedang aktif (perlu jq)
            if command -v jq &> /dev/null; then
                FOCUSED_OUTPUT=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .name')
                grim -o "$FOCUSED_OUTPUT" "$tmp_file"
            else
                notify_cmd "Error" "jq tidak terinstall, fallback ke fullscreen."
                grim "$tmp_file"
            fi
            ;;
        "area")
            GEOM=$(slurp)
            if [ -z "$GEOM" ]; then exit 0; fi # Batal
            grim -g "$GEOM" "$tmp_file"
            ;;
    esac
    echo "$tmp_file"
}

# Fungsi Finalisasi (Simpan/Copy/Edit)
finalize_screenshot() {
    local action=$1
    local file=$2
    local target="$SAVE_DIR/$NAME"

    if [ ! -f "$file" ]; then exit 1; fi

    case $action in
        "copy")
            wl-copy < "$file"
            notify_cmd "Copied" "Screenshot disalin ke Clipboard"
            rm "$file"
            ;;
        "save")
            mv "$file" "$target"
            notify_cmd "Saved" "Tersimpan di: $target"
            ;;
        "copysave")
            wl-copy < "$file"
            cp "$file" "$target"
            notify_cmd "Saved & Copied" "Tersimpan di: $target"
            rm "$file"
            ;;
        "edit")
            swappy -f "$file" -o "$target"
            # Bersihkan tmp file setelah swappy ditutup
            rm "$file" 2>/dev/null
            ;;
    esac
}

# Helper Rofi
rofi_cmd() {
    rofi -dmenu -i -no-show-icons -lines 4 -width 30 -p "$1"
}

# -----------------------------------------------------
# ALUR MENU (WORKFLOW)
# -----------------------------------------------------

# MENU 1: Tipe Aksi (Termasuk akses Cliphist)
option_instant="⚡ Screenshot (Instant)"
option_timer="⏳ Screenshot (Timer)"
option_cliphist="📂 Open Clipboard History"

TYPE_START=$(echo -e "$option_instant\n$option_timer\n$option_cliphist" | rofi_cmd "Start")

if [ -z "$TYPE_START" ]; then exit 0; fi

# JIKA MEMILIH CLIPHIST
if [[ "$TYPE_START" == "$option_cliphist" ]]; then
    open_cliphist
    exit 0
fi

# JIKA MEMILIH TIMER
countdown=0
if [[ "$TYPE_START" == "$option_timer" ]]; then
    opt_5s="5 Detik"
    opt_10s="10 Detik"
    opt_20s="20 Detik"
    
    SEL_TIMER=$(echo -e "$opt_5s\n$opt_10s\n$opt_20s" | rofi_cmd "Timer")
    if [ -z "$SEL_TIMER" ]; then exit 0; fi
    
    # Ambil angka dari string
    countdown=$(echo "$SEL_TIMER" | grep -o -E '[0-9]+')
fi

# MENU 2: Mode Capture
opt_full="🖥️  Fullscreen"
opt_active="📺 Active Monitor"
opt_region="✂️  Region / Select"

TYPE_MODE=$(echo -e "$opt_full\n$opt_active\n$opt_region" | rofi_cmd "Mode")
if [ -z "$TYPE_MODE" ]; then exit 0; fi

mode="screen"
if [[ "$TYPE_MODE" == "$opt_active" ]]; then mode="output"; fi
if [[ "$TYPE_MODE" == "$opt_region" ]]; then mode="area"; fi

# MENU 3: Aksi Akhir
opt_copy="📋 Copy to Clipboard"
opt_save="💾 Save to File"
opt_copysave="📑 Copy & Save"
opt_edit="🖌️  Edit (Swappy)"

TYPE_ACTION=$(echo -e "$opt_copy\n$opt_save\n$opt_copysave\n$opt_edit" | rofi_cmd "Action")
if [ -z "$TYPE_ACTION" ]; then exit 0; fi

action="copy"
if [[ "$TYPE_ACTION" == "$opt_save" ]]; then action="save"; fi
if [[ "$TYPE_ACTION" == "$opt_copysave" ]]; then action="copysave"; fi
if [[ "$TYPE_ACTION" == "$opt_edit" ]]; then action="edit"; fi

# -----------------------------------------------------
# EKSEKUSI
# -----------------------------------------------------

# 1. Handle Delay Timer
if [ "$countdown" -gt 0 ]; then
    while [ "$countdown" -gt 0 ]; do
        notify_cmd "Timer" "Mengambil gambar dalam ${countdown}s..."
        sleep 1
        ((countdown--))
    done
else
    # Delay kecil agar menu rofi hilang sepenuhnya
    sleep 0.5
fi

# 2. Lakukan Capture
TEMP_IMG=$(perform_capture "$mode")

# 3. Proses Akhir
if [ -f "$TEMP_IMG" ]; then
    finalize_screenshot "$action" "$TEMP_IMG"
fi