# 1. آپلود فایل سالم به گیت‌هاب
git add vc.sh
git commit -m "Fix syntax error and apply creator branding"
git push origin main
rm -f $PREFIX/bin/vc
curl -fsSL https://raw.githubusercontent.com/Alireza123456w6w/V.C.-a-video-compresser-for-termux/main/install.sh | bash
