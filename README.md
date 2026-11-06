سلام!
برای استفاده و نصب افزونه کاهش‌دهنده حجم ویدیو و ... کد زیر را در ترموکس وارد کنید:
```bash
git add vc.sh
git commit -m "Fix syntax error and apply creator branding"
git push origin main
rm -f $PREFIX/bin/vc
curl -fsSL https://raw.githubusercontent.com/Alireza123456w6w/V.C.-a-video-compresser-for-termux/main/install.sh | bash
```
و پس از نصب می توانید با کد 
```bash
vc
```
وارد افزونه شوید.
و حذف از طریق کد:
```bash
vcdel
```
