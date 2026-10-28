#!/usr/bin/env bash
# =============================================================================
#  vc Installer | Creator: Alireza123456w6w | Website: offers-pishnahadat.vercel.app
# =============================================================================

CREATOR="Alireza123456w6w"
WEBSITE="offers-pishnahadat.vercel.app"
REPO="Alireza123456w6w/V.C.-a-video-compresser-for-termux"
BRANCH="main" # اگر شاخه اصلی شما master است، این را به master تغییر دهید
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

echo "==============================================="
echo "  vc Installer  |  by ${CREATOR}"
echo "  ${WEBSITE}"
echo "==============================================="

# 1. نصب پیش‌نیازها
command -v ffmpeg >/dev/null 2>&1 || { echo "▶ Installing ffmpeg..."; pkg install -y ffmpeg; }
command -v curl  >/dev/null 2>&1 || { echo "▶ Installing curl..."; pkg install -y curl; }

# 2. دانلود و نصب vc
echo "▶ Downloading vc.sh..."
tmp=$(mktemp)
curl -fsSL "${RAW}/vc.sh" -o "$tmp" || { echo "✘ Download failed. Check your internet or branch name."; exit 1; }
install -m 755 "$tmp" "$PREFIX/bin/vc"
rm -f "$tmp"

# 3. ساخت دستور حذف (vcdel)
echo "▶ Creating vcdel command..."
cat > "$PREFIX/bin/vcdel" <<VDEL
#!/usr/bin/env bash
echo "==============================================="
echo "  vc Uninstaller  |  by ${CREATOR}"
echo "  ${WEBSITE}"
echo "==============================================="
echo "🗑 Removing vc..."
rm -f "\$PREFIX/bin/vc" "\$HOME/bin/vc" "\$PREFIX/bin/vcdel"
hash -r
echo "✅ vc and vcdel removed successfully."
VDEL
chmod +x "$PREFIX/bin/vcdel"

hash -r
echo ""
echo "✅ Installed successfully!"
echo "   vc     → Use the tool"
echo "   vcdel  → Uninstall (removes both vc and vcdel)"
echo "   by ${CREATOR} — ${WEBSITE}"
