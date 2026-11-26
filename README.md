<a name="english"></a>

<div align="center">

# 🎬 VidCompress (`vc`)

**The all-in-one video toolkit for your phone — one Bash script, powered by ffmpeg.**
Compress, repair, subtitle, clean and vault your videos right inside **Termux**.

![version](https://img.shields.io/badge/version-3.5.1-blue)
![shell](https://img.shields.io/badge/shell-bash-4EAA25)
![platform](https://img.shields.io/badge/platform-Termux%20%2F%20Android-brightgreen)
![engine](https://img.shields.io/badge/engine-ffmpeg-007808)

**English** · [فارسی](#persian)

</div>

---

## ✨ Why VidCompress?

- 📉 **Smart compression** — 12 ready presets (H.265, H.264, AV1, VP9, hardware), CRF or an exact **target size** (two-pass), batch and parallel jobs.
- 🛠️ **Repair & Sync Center** — fixes videos that play in VLC but drift out of sync (or refuse to play) on TVs and USB players.
- 💬 **Subtitle Studio** — embed (soft), burn (hard), extract, remove and list subtitles. Persian / Arabic `.srt` files in Windows-1256 are converted to UTF-8 automatically.
- 🧼 **Logo / watermark remover** — finds fixed or moving logos by itself and paints them out.
- 🎞️ **Frame extractor, GIF maker, audio extractor, thumbnail sheets.**
- ⚡ **Speed lab & Auto-Tune** — tests *your* phone and saves the fastest settings for it.
- 🔐 **`.w6w` vault** — one encrypted container for videos, pictures, audio, text and scripts.
- 🧪 **Built-in self-test** — `vc --selftest` checks everything on your own phone.
- 📱 Made for phones: a touch-friendly menu, a video finder that shows your newest videos, a folder browser, a live progress bar, and no typing of long paths.

---

## 📦 Installation (Termux)

> **Tip:** install Termux from **F-Droid** or the official GitHub releases — the Play Store build is outdated.

### ⚡ One-line install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Alireza123456w6w/V.C.-a-video-compresser-for-termux/main/install.sh | bash
```

The installer:

1. installs `ffmpeg` and `curl` if they are missing,
2. downloads `vc.sh` and installs it as the **`vc`** command,
3. creates a **`vcdel`** command that uninstalls everything.

Then (optional, recommended):

```bash
vc --setup                    # installs the extra tools (openssl, xz, tar, gpac ...)
vc --selftest                 # checks that everything works on your phone
```

Run `vc` to open the menu. *(Want to read the script before running it? Open [`install.sh`](install.sh) in this repository — it is short.)*

### 🔄 Update

Run the one-line install again — it replaces the old `vc`. Your settings are kept.

### 🗑️ Uninstall

```bash
vcdel                         # removes the vc and vcdel commands
rm -rf ~/.config/vidcompress  # optional: also delete saved settings, profiles and logs
```

### 🔧 Manual install (without the installer)

**1. Prepare Termux**

```bash
pkg update && pkg upgrade -y
termux-setup-storage          # allow access to your phone's storage (tap "Allow")
```

**2. Get the script**

```bash
pkg install -y git
git clone https://github.com/Alireza123456w6w/V.C.-a-video-compresser-for-termux.git
cd V.C.-a-video-compresser-for-termux
```

*(or, without git: `curl -L -o vc.sh https://raw.githubusercontent.com/Alireza123456w6w/V.C.-a-video-compresser-for-termux/main/vc.sh`)*

**3. Install the `vc` command**

```bash
bash vc.sh --install          # copies the script to $PREFIX/bin/vc
```

**4. Install everything the features need (ffmpeg, openssl, xz, tar, gpac …)**

```bash
vc --setup                    # installs what is missing, one by one, with retries
vc --doctor                   # shows what is installed and what is not
```

**5. Check that everything works on your phone**

```bash
vc --selftest                 # quick test (use "vc --selftest full" for the complete one)
```

Done — run `vc` to open the menu.

### Requirements

| Needed | Used for | Installed by `vc --setup` |
|---|---|---|
| `bash`, `awk`, `find` | the script itself | core |
| `ffmpeg` + `ffprobe` | everything video | core |
| `openssl`, `tar`, `xz`, `less` | `.w6w` vault | `w6w` group |
| `util-linux` (`taskset`) | pin work to the fast CPU cores (optional) | `perf` group |
| `gpac` (MP4Box), `untrunc` | extra repair for broken MP4 files (optional) | `repair` group |
| `termux-api`, `termux-tools`, `file` | notifications, opening files (optional) | `extras` group |

You can install a single group: `vc --setup core | w6w | perf | repair | extras`.
Some encoders (for example AV1 or the hardware encoder) depend on your ffmpeg build — `vc --doctor` shows what your phone has.

> Built for **Termux on Android**. On a normal Linux machine with `bash` + `ffmpeg` it runs too; only the phone-specific helpers (gallery refresh, `termux-open`, notifications) need Termux.

---

## 🚀 Quick start

```bash
vc                                   # interactive menu (recommended)
vc -y -p balanced movie.mp4          # compress one file, no questions
vc -y -p target -t 95 movie.mp4      # make it fit under ~95 MB
vc -y --srt auto movie.mp4           # compress + embed movie.srt as a subtitle track
vc --repair movie.mkv                # fix A/V drift, make it TV-ready
vc --sub                             # open the Subtitle Studio directly
```

### The main menu

```
VidCompress v3.5.1  -  by W6W
 Selected : 2 file(s), 1.4 GB
 Preset   : balanced
 Plan     : ...

 1) Choose videos (newest first, or search a name)
 2) Queue (view / remove)
 3) Choose preset
 4) Advanced settings
 5) Profiles (save / load)
 6) Subtitle studio (SRT add / extract / remove)
 7) Repair & sync (fix A/V drift for TVs)
 8) Tools (info, estimate, GIF, audio, thumbs)
 9) START compression
 f) Extract frames (time range -> new folder)
 l) Remove logo / watermark (finds it by itself)
 t) Speed lab & AUTO-TUNE (fastest settings for this phone)
 w) W6W vault (encrypted .w6w: video, pictures, text, audio ...)
 r) Results & compare (last batch)
 c) Clear selection
 0) Quit
```

---

## 📚 Feature guide

### 1. Choosing videos & the queue

- **Menu 1** shows your **newest videos from the whole phone** (Camera, Download, Telegram, WhatsApp …) as a short list.
  Type a number to add it, or **type part of a name** to search.
- `a` adds **every** video found (or every search result). In the folder browser, `aa` adds everything inside a folder including sub-folders, `u` goes up, `x` also shows empty folders.
- **Menu 2 (Queue)** lets you view and remove items. Repair, GIF, audio and thumbnail tools work **on the whole queue, one after another**, and ask you *which* queued videos to use (`3`, `1 3 5-7`, or `a` for all).
- On the command line you can pass files **or folders**, and options may come before or after them: `vc movie.mp4 -p turbo -y`.

### 2. Compression

**Presets** (menu 3 or `-p NAME`):

| Preset | What it does |
|---|---|
| `balanced` | H.265, CRF 26, 720p, fast encoder — best all-round (default) |
| `quality` | H.265, CRF 21, original resolution — near-transparent |
| `small` | H.265, CRF 30, 480p, 30 fps — small files |
| `tiny` | H.265, CRF 33, 360p, 24 fps — smallest, for sharing |
| `social` | H.264, 720p, 30 fps — fast, plays everywhere (chat apps) |
| `compat` | H.264, CRF 23, original resolution — maximum compatibility |
| `fast` | H.264 veryfast, 720p — quick encode for slow phones |
| `turbo` | H.265 veryfast, CRF 28, 720p — fastest H.265, good quality |
| `target` | H.265 two-pass, 720p, ~95 MB (change the size in Settings or with `-t`) |
| `hardware` | the phone's hardware H.265 encoder — very fast, experimental |
| `av1` | AV1 (SVT-AV1) — next-gen, about 30 % smaller than H.265 |
| `web` | VP9 + Opus in WebM, 720p — websites, Chrome / Firefox |

**Options**

| Option | Meaning |
|---|---|
| `-p PRESET` | choose a preset |
| `-t MB` | target size in MB (two-pass), e.g. `-t 95` |
| `-c CRF` | constant quality (x265 22–30, x264 18–27, av1 30–45; lower = better) |
| `-r PIXELS` | max short side: 1080, 720, 480 … (`0` = keep) |
| `-f FPS` | max frame rate (`0` = keep) |
| `-s SPEED` | `ultrafast` … `medium` … `veryslow` |
| `-k CODEC` | `x265`, `x264`, `av1`, `vp9`, `hw265`, `hw264` |
| `-a AUDIO` | `copy`, `none` or a bitrate in kbps, e.g. `-a 64` |
| `-S` / `-E` | trim start / end (`90`, `1:30`, `0:01:30`) |
| `-o DIR` | output folder (default: next to the source) |
| `-j N` | parallel jobs, 1–8 (try 2–3 for hardware encoders) |
| `-d` | delete originals **only after a verified result** |
| `-y` | start immediately, no menu |
| `--format FMT` | output container: `mp4` (default), `mkv`, `webm`, `mov`, `avi`, `ts` |
| `--resume` | skip files whose finished output already exists |
| `--lanczos` / `--bicubic` | sharper downscaling (≈5 % bigger files) / default |
| `--no-deint`, `--autocrop` | don't deinterlace DVD / TV sources; remove black bars |
| `--cores all\|auto\|LIST`, `--threads N` | CPU cores and encoder threads |

**Good to know**

- Reads far more than MP4: MKV, AVI, MOV, WebM, WMV/ASF, FLV, MPEG/VOB, TS/M2TS, RM/RMVB, OGV, MXF, DV, 3GP, raw H.264/H.265 … (anything ffmpeg can decode).
- Output containers get matching codecs automatically (WebM → VP9/AV1 + Opus, AVI → H.264 + MP3) and subtitles only where the container can hold them.
- Interlaced sources (DVD, TV recordings) are deinterlaced automatically.
- Audio that is already AAC at or below the target bitrate is **copied**, not re-encoded.
- Every MP4 is **built on fast local storage and moved in one pass**, which avoids the Android error *"Unable to re-open … output file for shifting data"*.
- With **Delete originals** on, vc decodes the *whole* output first and keeps the original if there is any error.
- Menu 4 (**Advanced settings**) also has: denoise, trim, filename suffix, strip metadata, parallel jobs, resume mode, after-finishing action (summary / open / results menu), CPU cores and threads, deinterlace and auto-crop. Press `s` to save your choices as the default.
- Menu 5 (**Profiles**) saves and loads complete setting sets.

### 3. 💬 Subtitle Studio (`vc --sub`, menu 6)

| Menu item | What it does |
|---|---|
| **Embed SRT** | adds a **soft**, selectable subtitle track. Instant — picture and audio are never re-encoded. |
| **Burn SRT** | draws the subtitles permanently into the picture (re-encodes). Style is configurable in Settings. |
| **Extract** | saves every subtitle track as `.srt` files. |
| **Remove** | deletes subtitle tracks (instant). |
| **List** | shows all subtitle streams. |

Use `FILE=auto` to find `movie.srt` next to `movie.mp4` automatically (`vc -y --srt auto movie.mp4`, `vc -y --srt-burn auto movie.mp4`). Other options: `--keepsubs` (default), `--nosubs`, `--nosrt`, `--mkv`.

**Embedding into MKV (v3.5.1)** — nothing is lost:

- every existing track is copied **as it is**: styled **ASS/SSA** keeps its style, **PGS / VobSub** (Blu-ray) bitmap tracks stay;
- attached **fonts** are kept, so ASS subtitles still look right;
- audio of any codec (FLAC, DTS, TrueHD, Opus …) is **always copied** — never re-encoded in an MKV;
- the new track gets a proper 3-letter language tag, and you can make it the **default track**;
- `.ass` / `.ssa` / `.vtt` files are accepted too (type their path when vc asks for the subtitle file) and keep their format in an MKV;
- the result is **checked** (track count and length) before it replaces anything, and free space is checked first.

**Embedding into MP4** — text tracks become `mov_text`; every audio track is judged on its own (AAC/MP3/AC3/E-AC3 are copied, others become AAC, 5.1 gets a fitting bitrate). Bitmap tracks cannot live in MP4 and are reported — use an MKV to keep them.

**Persian / Arabic subtitles** — many `.srt` files are saved as **Windows-1256** or UTF-16. vc detects the encoding and converts the text to **UTF-8** before using it (Persian: Arabic *yeh / kaf* become *ی / ک*). Force a specific encoding with `SUB_CHARSET=CP1256 vc --sub`. The same conversion runs before burning and in the compress path.

File names with `[brackets]`, `*` or `?` are handled correctly when searching for the matching `.srt`.

### 4. 🛠️ Repair & Sync Center (menu 7)

For videos that play fine on a phone but **drift out of sync, stutter or refuse to play on a TV / USB player**.

| Command | What it does |
|---|---|
| `vc --diagnose FILE` | reports sync / TV-compatibility problems (changes nothing). It samples the start, middle and end of the file. |
| `vc --repair FILE…` | smart repair: remux-only / audio-only / video-only / full rebuild — the **fastest path that really fixes it**. Add `-j N` to repair several files in parallel. |
| `vc --quickfix FILE` | remux only, no re-encode: faststart + clean timestamps (seconds). |
| `vc --sync-shift MS FILE` | shift the audio: `+250` = delay 250 ms, `-250` = advance. |
| `vc --repair-lab FILE` | tests **every** repair method (quick remux, smart repair, full rebuild, rescue, MP4Box, untrunc), measures time and size, re-checks each result and **keeps the best**. |

Extra options: `--oldtv` (ultra-compatibility: Main profile, no B-frames, ≤ 30 fps), `--stereo` (downmix surround), `--fps RATE`, `--repair-crf N`, `--repair-preset NAME`.

What it catches: variable frame rate, bad audio sample rates, A/V start offsets, missing faststart, TV-unsafe codecs, millisecond-rounded timestamps (the #1 cause of *gradual* drift). Every output is **verified** (length, audio/video length, the end of the file really decodes); free disk space is checked first; the original file date is kept; a **rescue mode** retries by re-encoding and skipping damaged data.

### 5. 🎞️ Frame extractor (menu `f`)

Writes **every frame between two times** into a new folder — frame-exact, even for variable-frame-rate videos.

```bash
vc --frames movie.mp4 -S 1:30 -E 1:40                       # all frames 1:30 -> 1:40
vc --frames movie.mp4 -S 90 -E +5 --frame-format png        # 5 seconds from 1:30, as PNG
vc --frames movie.mp4 -S 0 -E 60 --frame-step key --frame-height 480
```

`--frame-format jpg|png|bmp|webp`, `--frame-quality 1-31`, `--frame-step N|key`, `--frame-height PX`, `-o DIR`. Range is `[start, end)`. Without `-S/-E` an interactive flow starts.

### 6. 🧼 Logo / watermark remover (menu `l`)

```bash
vc --delogo movie.mp4                         # finds the logo, shows it, asks, removes it
vc --logo-detect movie.mp4                    # only show WHERE the logos are (+ a preview picture)
vc --delogo -y --logo-sens high clip.mp4      # no questions, also catches faint logos
vc --delogo --logo-box 1500:40:360:120 -y clip.mp4        # you give the place: X:Y:W:H
vc --delogo --logo-box 100:50:200:80@5-12 clip.mp4        # only in seconds 5–12
vc --delogo --logo-mode moving clip.mp4       # a watermark that hops between corners
```

Quality is kept: x264 CRF 17, audio copied, same size and container (normal options like `-p`, `-c`, `-r` override this). Other options: `--logo-sens low|normal|high`, `--logo-mode fixed|moving`, `--logo-window S`, `--logo-windows N`, `--logo-fill smart|simple|box`, `--logo-preview` (before/after picture, every logo boxed in red and **numbered** — type a number to resize / move / re-check it), `--logo-no-open`.

### 7. ⚡ Speed lab & Auto-Tune (menu `t`)

| Command | What it does |
|---|---|
| `vc --tune [FILE]` | **AUTO-TUNE**: you pick what matters (`--goal speed|balanced|size|quality`); vc races every preset, scores quality (SSIM), tests CPU setups, then **saves the best preset and CPU settings for your phone**. Offered once at first start. |
| `vc --race FILE` | encodes a sample with every preset: real speed, size and time. |
| `vc --race-cores FILE` | same encode on all cores / fewer threads / big cores only. |
| `vc --stamina FILE` | heat test: repeats an encode and shows speed, temperature and CPU clock — you can *see* throttling. |
| `vc --race-all FILE` | all three (a few minutes); `--no-quality` skips SSIM scoring. |
| `vc --cpu` | shows the CPU layout (big/little), pinning and readable sensors. |

On phones with big + little cores, vc can run ffmpeg only on the fast cores (`--cores auto`) — it is **off by default** because it only helps on some phones; test it with `--race-cores`.

### 8. 🧰 Tools (menu 8)

Video info · estimate output size (20 s test encode) · Subtitle Studio · **GIF maker** · **audio extraction (MP3 / M4A)** · **thumbnails / contact sheet** · check installation and encoders · install / fix all tools · install the `vc` command · show the last log · frame extractor · speed lab · logo remover.
GIF, audio and thumbnail tools work on one or many videos of the queue.

### 9. 🔐 `.w6w` vault (menu `w`)

One **encrypted** file that can hold videos, pictures, audio, text, scripts and subtitles. vc recognises what each item is and can list, play, extract and convert them.

```bash
vc --w6w pack trip.w6w movie.mp4 movie.srt cover.jpg notes.txt   # make a vault
vc --w6w pack trip.w6w ~/folder --squeeze --password --comment "Trip 2026"
vc --w6w info trip.w6w          # what is inside
vc --w6w verify trip.w6w        # check integrity
vc --w6w play trip.w6w 1        # play item 1
vc --w6w extract trip.w6w -o out 1 3     # extract items 1 and 3
vc --w6w convert trip.w6w --to mp4       # convert the items
vc --w6w key show | export | import HEX | new
```

- `--squeeze` first shrinks videos with your current preset, pictures to WebP and audio to Opus.
- `--password` uses a password instead of this phone's **device key** (export the key as a backup!).
- Security: AES-256-CBC with an HMAC-SHA256 over everything (encrypt-then-MAC), PBKDF2-HMAC-SHA256 (600 000 rounds) in password mode.
- Every pack **re-opens its own result** (MAC, manifest, whole archive) and deletes it with an error instead of reporting a false success. Extraction only takes the named items, refuses links / odd entries and sanitises names.

### 10. 📊 Results & compare (menu `r`)

After a batch: open the output or the original in your player, a **compare table** and a **side-by-side comparison video** (ORIGINAL vs COMPRESSED).

---

## 🧾 All commands at a glance

```text
vc                              interactive menu
vc --sub                        Subtitle Studio
vc [options] FILE|DIR ...       preload files / folders (menu opens unless -y)

vc --repair | --diagnose | --quickfix | --sync-shift | --repair-lab
vc --frames | --delogo | --logo-detect
vc --race | --race-cores | --stamina | --race-all | --cpu | --tune
vc --w6w pack | info | verify | play | key | extract | convert
vc --setup [GROUP]    install everything the features need
vc --doctor           show which tools are installed
vc --selftest [full]  automatic self-test on this phone
vc --install          install this script as the 'vc' command
vc --version          print the version
vc -h                 full help with every option
```

## 🍳 Recipes

```bash
vc -y -p target -t 95 movie.mp4               # under 100 MB, 720p
vc -y -p av1 movie.mp4                        # next-gen AV1, smallest files
vc -y -j 3 -p turbo ~/storage/movies          # 3 files at once
vc -y --srt auto -p balanced movie.mp4        # compress + embed movie.srt
vc -y --srt-burn auto -p social movie.mp4     # compress + burn subtitles
vc -y -p small --mkv movie.mp4                # MKV output (native SRT subs)
vc movie.mkv -p web -y                        # VP9 + Opus in WebM for websites
vc old_dvd.vob --format mp4 --autocrop -y     # DVD rip: deinterlaced, bars removed
vc --repair --oldtv movie.mkv                 # ancient TV / USB stick mode
vc --repair -j 4 *.mp4                        # repair 4 files at once
vc --sync-shift -250 movie.mp4                # audio was 250 ms late
```

## ⚙️ Files & settings

| Path | Content |
|---|---|
| `~/.config/vidcompress/settings.conf` | your saved defaults |
| `~/.config/vidcompress/profiles/` | saved profiles |
| `~/.config/vidcompress/last_run.log` | log of the last run (menu: Tools → *Show last log*) |
| `~/.config/vidcompress/setup.log` | log of `vc --setup` |

Environment: `SUB_CHARSET=CP1256` forces the encoding of a non-UTF-8 subtitle file.

## 🩺 Troubleshooting

| Problem | Fix |
|---|---|
| `ffmpeg: command not found` | `vc --setup` (or `pkg install ffmpeg`) |
| vc can't see your videos | run `termux-setup-storage` and allow storage access |
| Subtitle looks like `؟؟؟` / garbage | the file is not UTF-8: `SUB_CHARSET=CP1256 vc --sub` (install `libiconv` if the conversion reports an error) |
| A feature says a tool is missing | `vc --doctor`, then `vc --setup` |
| Phone gets hot and slows down | `vc --stamina FILE` to see throttling, lower `-j`, use `-p turbo` or `-p fast` |
| Something fails | open Tools → *Show last log*, or read `~/.config/vidcompress/last_run.log` |
| Is everything OK on my phone? | `vc --selftest full` |

## 🆕 What's new in 3.5.1

**Subtitles into MKV, rebuilt.** Fixed: existing PGS/VobSub tracks being dropped · ASS/SSA turned into plain SRT · attached fonts lost · FLAC/DTS/TrueHD/Opus audio re-encoded to AAC · Windows-1256 / UTF-16 subtitles failing or showing garbage · `.srt` names with `[brackets]` never found · MKV without a duration refused. New: choose the default track, a summary of what was kept, result check before replacing, free-space check, and a new self-test (`subtitles into MKV (nothing lost)`).

Earlier highlights: **3.5** (see the script header), **3.1** Repair Lab + auto-installer, **3.0** many more input formats, MKV/WebM/MOV/AVI/TS output, VP9, `.w6w` vault, **2.5** Auto-Tune, **2.3** frame extractor and preset race, **2.1** Repair & Sync Center, **2.0** Subtitle Studio, parallel batches, AV1. The full history is at the top of `vc.sh`.

## 🤝 Contributing

[Issues](https://github.com/Alireza123456w6w/V.C.-a-video-compresser-for-termux/issues) and pull requests are welcome. Before sending a change, run `bash -n vc.sh` and `vc --selftest full`.

## 👤 Credits

Created by **W6W** · [offers-pishnahadat.vercel.app](https://offers-pishnahadat.vercel.app)

---

<a name="persian"></a>

<div align="center">

# 🇮🇷 راهنمای فارسی

**راهنمای کامل VidCompress به زبان فارسی**

[⬆ English](#english)

</div>

---

<div dir="rtl">

## ✨ چرا VidCompress؟

- 📉 **فشرده‌سازی هوشمند** — ۱۲ پریست آماده (H.265، H.264، AV1، VP9، سخت‌افزاری)، کیفیت ثابت (CRF) یا **حجم دقیق هدف** (دو‌پاسه)، پردازش دسته‌ای و موازی.
- 🛠️ **مرکز تعمیر و همگام‌سازی** — ویدیوهایی که تو VLC خوب پخش می‌شن ولی روی تلویزیون و USB از صدا عقب می‌افتن (یا اصلاً پخش نمی‌شن) رو درست می‌کنه.
- 💬 **استودیوی زیرنویس** — اضافه کردن (نرم)، چسباندن روی تصویر (سخت)، استخراج، حذف و فهرست زیرنویس. فایل‌های `.srt` فارسی/عربی با کدگذاری Windows-1256 خودکار به UTF-8 تبدیل می‌شن.
- 🧼 **حذف لوگو و واترمارک** — لوگوی ثابت یا متحرک رو خودش پیدا می‌کنه و پاک می‌کنه.
- 🎞️ **استخراج فریم، ساخت GIF، استخراج صدا، تصویر بندانگشتی.**
- ⚡ **آزمایشگاه سرعت و Auto-Tune** — گوشی *خودت* رو تست می‌کنه و سریع‌ترین تنظیمات رو ذخیره می‌کنه.
- 🔐 **گاوصندوق `.w6w`** — یک فایل رمزگذاری‌شده برای ویدیو، عکس، صدا، متن و اسکریپت.
- 🧪 **تست خودکار داخلی** — `vc --selftest` همه‌چیز رو روی خود گوشی‌ت چک می‌کنه.
- 📱 مخصوص گوشی: منوی لمسی، یابنده‌ی ویدیو که جدیدترین ویدیوها رو نشون می‌ده، مرورگر پوشه، نوار پیشرفت زنده و بدون تایپ مسیرهای طولانی.

---

## 📦 نصب (Termux)

> **نکته:** Termux رو از **F-Droid** یا نسخه‌های رسمی GitHub نصب کن — نسخه‌ی Play Store قدیمیه.

### ⚡ نصب با یک خط (پیشنهادی)

</div>

```bash
curl -fsSL https://raw.githubusercontent.com/Alireza123456w6w/V.C.-a-video-compresser-for-termux/main/install.sh | bash
```

<div dir="rtl">

نصب‌کننده:

1. اگه `ffmpeg` و `curl` نصب نباشن نصبشون می‌کنه،
2. فایل `vc.sh` رو دانلود می‌کنه و به‌عنوان دستور **`vc`** نصب می‌کنه،
3. یک دستور **`vcdel`** می‌سازه که همه‌چیز رو پاک می‌کنه (حذف نصب).

بعدش (اختیاری ولی پیشنهادی):

</div>

```bash
vc --setup                    # ابزارهای اضافه (openssl، xz، tar، gpac ...) رو نصب می‌کنه
vc --selftest                 # چک می‌کنه همه‌چیز روی گوشی‌ت کار می‌کنه
```

<div dir="rtl">

برای باز کردن منو `vc` رو اجرا کن. *(می‌خوای قبل از اجرا اسکریپت رو بخونی؟ فایل [`install.sh`](install.sh) تو همین مخزن رو باز کن — کوتاهه.)*

### 🔄 به‌روزرسانی

دوباره همون دستور نصب یک‌خطی رو اجرا کن — `vc` قدیمی رو جایگزین می‌کنه. تنظیمات تو حفظ می‌شن.

### 🗑️ حذف نصب

</div>

```bash
vcdel                         # دستورهای vc و vcdel رو پاک می‌کنه
rm -rf ~/.config/vidcompress  # اختیاری: تنظیمات، پروفایل‌ها و لاگ‌های ذخیره‌شده هم پاک بشن
```

<div dir="rtl">

### 🔧 نصب دستی (بدون نصب‌کننده)

**۱. آماده‌سازی Termux**

</div>

```bash
pkg update && pkg upgrade -y
termux-setup-storage          # دسترسی به حافظه‌ی گوشی (روی Allow بزن)
```

<div dir="rtl">

**۲. گرفتن اسکریپت**

</div>

```bash
pkg install -y git
git clone https://github.com/Alireza123456w6w/V.C.-a-video-compresser-for-termux.git
cd V.C.-a-video-compresser-for-termux
```

<div dir="rtl">

*(یا بدون git:)*

</div>

```bash
curl -L -o vc.sh https://raw.githubusercontent.com/Alireza123456w6w/V.C.-a-video-compresser-for-termux/main/vc.sh
```

<div dir="rtl">

**۳. نصب دستور `vc`**

</div>

```bash
bash vc.sh --install          # اسکریپت رو به $PREFIX/bin/vc کپی می‌کنه
```

<div dir="rtl">

**۴. نصب همه‌ی چیزهایی که قابلیت‌ها لازم دارن (ffmpeg، openssl، xz، tar، gpac ...)**

</div>

```bash
vc --setup                    # هرچی نصب نیست رو یکی‌یکی و با تلاش مجدد نصب می‌کنه
vc --doctor                   # نشون می‌ده چی نصبه و چی نیست
```

<div dir="rtl">

**۵. چک کن همه‌چیز روی گوشی‌ت کار می‌کنه**

</div>

```bash
vc --selftest                 # تست سریع (برای تست کامل: vc --selftest full)
```

<div dir="rtl">

تمام! برای باز کردن منو فقط `vc` رو اجرا کن.

### نیازمندی‌ها

| چی لازمه | برای چی | کدوم گروه `vc --setup` نصبش می‌کنه |
|---|---|---|
| `bash`، `awk`، `find` | خود اسکریپت | core |
| `ffmpeg` + `ffprobe` | همه‌ی کارهای ویدیویی | core |
| `openssl`، `tar`، `xz`، `less` | گاوصندوق `.w6w` | گروه `w6w` |
| `util-linux` (`taskset`) | سنجاق کردن کار روی هسته‌های سریع CPU (اختیاری) | گروه `perf` |
| `gpac` (MP4Box)، `untrunc` | تعمیر بیشتر فایل‌های MP4 خراب (اختیاری) | گروه `repair` |
| `termux-api`، `termux-tools`، `file` | اعلان و باز کردن فایل‌ها (اختیاری) | گروه `extras` |

می‌تونی فقط یک گروه نصب کنی: `vc --setup core | w6w | perf | repair | extras`.
بعضی انکودرها (مثلاً AV1 یا انکودر سخت‌افزاری) به نسخه‌ی ffmpeg گوشی‌ت بستگی دارن — `vc --doctor` نشون می‌ده گوشی‌ت چی داره.

> برای **Termux روی اندروید** ساخته شده. روی لینوکس معمولی با `bash` + `ffmpeg` هم اجرا می‌شه؛ فقط ابزارهای مخصوص گوشی (به‌روزرسانی گالری، `termux-open`، اعلان) به Termux نیاز دارن.

---

## 🚀 شروع سریع

</div>

```bash
vc                                   # منوی تعاملی (پیشنهادی)
vc -y -p balanced movie.mp4          # فشرده‌سازی یک فایل، بدون سؤال
vc -y -p target -t 95 movie.mp4      # جا بشه زیر ~95 مگابایت
vc -y --srt auto movie.mp4           # فشرده‌سازی + اضافه کردن movie.srt به‌عنوان ترک زیرنویس
vc --repair movie.mkv                # رفع دیر/زود شدن صدا، آماده‌ی تلویزیون
vc --sub                             # باز کردن مستقیم استودیوی زیرنویس
```

<div dir="rtl">

### منوی اصلی

</div>

```
VidCompress v3.5.1  -  by W6W
 Selected : 2 file(s), 1.4 GB
 Preset   : balanced
 Plan     : ...

 1) Choose videos (newest first, or search a name)
 2) Queue (view / remove)
 3) Choose preset
 4) Advanced settings
 5) Profiles (save / load)
 6) Subtitle studio (SRT add / extract / remove)
 7) Repair & sync (fix A/V drift for TVs)
 8) Tools (info, estimate, GIF, audio, thumbs)
 9) START compression
 f) Extract frames (time range -> new folder)
 l) Remove logo / watermark (finds it by itself)
 t) Speed lab & AUTO-TUNE (fastest settings for this phone)
 w) W6W vault (encrypted .w6w: video, pictures, text, audio ...)
 r) Results & compare (last batch)
 c) Clear selection
 0) Quit
```

<div dir="rtl">

---

## 📚 راهنمای قابلیت‌ها

### ۱. انتخاب ویدیو و صف

- **منوی ۱** جدیدترین ویدیوهای کل گوشی (دوربین، Download، تلگرام، واتساپ ...) رو به‌صورت یک لیست کوتاه نشون می‌ده.
  شماره‌ش رو بزن تا اضافه بشه، یا **بخشی از اسمش رو تایپ کن** تا جستجو بشه.
- `a` **همه‌ی** ویدیوهای پیدا‌شده (یا همه‌ی نتایج جستجو) رو اضافه می‌کنه. تو مرورگر پوشه: `aa` همه‌چیز داخل پوشه (با زیرپوشه‌ها) رو اضافه می‌کنه، `u` یک پوشه بالا، `x` پوشه‌های خالی رو هم نشون می‌ده.
- **منوی ۲ (صف)** برای دیدن و حذف موارد. ابزارهای تعمیر، GIF، صدا و بندانگشتی روی **کل صف، یکی‌یکی** کار می‌کنن و می‌پرسن *کدوم* ویدیوهای صف رو بردارن (`3`، `1 3 5-7` یا `a` برای همه).
- تو خط فرمان می‌تونی فایل **یا پوشه** بدی و گزینه‌ها می‌تونن قبل یا بعد از فایل‌ها بیان: `vc movie.mp4 -p turbo -y`.

### ۲. فشرده‌سازی

**پریست‌ها** (منوی ۳ یا `-p NAME`):

| پریست | چیکار می‌کنه |
|---|---|
| `balanced` | H.265، CRF 26، 720p، انکودر fast — بهترین حالت عمومی (پیش‌فرض) |
| `quality` | H.265، CRF 21، رزولوشن اصلی — تقریباً بدون افت کیفیت |
| `small` | H.265، CRF 30، 480p، 30fps — فایل کوچیک |
| `tiny` | H.265، CRF 33، 360p، 24fps — کوچک‌ترین، برای اشتراک‌گذاری |
| `social` | H.264، 720p، 30fps — سریع، همه‌جا پخش می‌شه (پیام‌رسان‌ها) |
| `compat` | H.264، CRF 23، رزولوشن اصلی — حداکثر سازگاری |
| `fast` | H.264 veryfast، 720p — انکود سریع برای گوشی‌های ضعیف |
| `turbo` | H.265 veryfast، CRF 28، 720p — سریع‌ترین H.265 با کیفیت خوب |
| `target` | H.265 دو‌پاسه، 720p، حدود ۹۵ مگابایت (حجم رو از Settings یا با `-t` عوض کن) |
| `hardware` | انکودر سخت‌افزاری H.265 گوشی — خیلی سریع، آزمایشی |
| `av1` | AV1 (SVT-AV1) — نسل بعد، حدود ۳۰٪ کوچک‌تر از H.265 |
| `web` | VP9 + Opus در WebM، 720p — وب‌سایت‌ها، Chrome / Firefox |

**گزینه‌ها**

| گزینه | معنی |
|---|---|
| `-p PRESET` | انتخاب پریست |
| `-t MB` | حجم هدف به مگابایت (دو‌پاسه)، مثلاً `-t 95` |
| `-c CRF` | کیفیت ثابت (x265: ‏22–30، x264: ‏18–27، av1: ‏30–45؛ کمتر = بهتر) |
| `-r PIXELS` | حداکثر ضلع کوتاه: 1080، 720، 480 ... (`0` = بدون تغییر) |
| `-f FPS` | حداکثر فریم‌ریت (`0` = بدون تغییر) |
| `-s SPEED` | `ultrafast` ... `medium` ... `veryslow` |
| `-k CODEC` | `x265`، `x264`، `av1`، `vp9`، `hw265`، `hw264` |
| `-a AUDIO` | `copy`، `none` یا بیت‌ریت به kbps، مثلاً `-a 64` |
| `-S` / `-E` | شروع / پایانِ برش (`90`، `1:30`، `0:01:30`) |
| `-o DIR` | پوشه‌ی خروجی (پیش‌فرض: کنار فایل اصلی) |
| `-j N` | تعداد کار موازی، ۱ تا ۸ (برای انکودر سخت‌افزاری ۲–۳ رو امتحان کن) |
| `-d` | حذف فایل اصلی، **فقط بعد از نتیجه‌ی تأییدشده** |
| `-y` | شروع فوری، بدون منو |
| `--format FMT` | کانتینر خروجی: `mp4` (پیش‌فرض)، `mkv`، `webm`، `mov`، `avi`، `ts` |
| `--resume` | رد کردن فایل‌هایی که خروجی کامل‌شده‌شون وجود داره |
| `--lanczos` / `--bicubic` | کوچک‌کردن شارپ‌تر (فایل ≈۵٪ بزرگ‌تر) / پیش‌فرض |
| `--no-deint`، `--autocrop` | عدم ‌deinterlace برای DVD/تلویزیون؛ حذف نوارهای سیاه |
| `--cores all\|auto\|LIST`، `--threads N` | هسته‌های CPU و تردهای انکودر |

**خوب است بدونی**

- فقط MP4 نمی‌خونه: MKV، AVI، MOV، WebM، WMV/ASF، FLV، MPEG/VOB، TS/M2TS، RM/RMVB، OGV، MXF، DV، 3GP، H.264/H.265 خام ... (هرچی ffmpeg بتونه دیکد کنه).
- برای هر کانتینر خروجی، کدک مناسب خودکار انتخاب می‌شه (WebM ← VP9/AV1 + Opus، AVI ← H.264 + MP3) و زیرنویس فقط جایی که کانتینر پشتیبانی کنه.
- منابع interlaced (DVD، ضبط تلویزیون) خودکار deinterlace می‌شن.
- صدایی که از قبل AAC و با بیت‌ریت کمتر یا مساوی هدفه، **کپی** می‌شه، نه دوباره انکود.
- هر MP4 **روی حافظه‌ی محلی سریع ساخته و یکجا منتقل می‌شه**؛ این کار از خطای اندروید *"Unable to re-open … output file for shifting data"* جلوگیری می‌کنه.
- وقتی **Delete originals** روشنه، vc اول **کل** خروجی رو دیکد می‌کنه و اگه کوچک‌ترین خطایی باشه فایل اصلی رو نگه می‌داره.
- منوی ۴ (**Advanced settings**) این‌ها رو هم داره: denoise، برش، پسوند اسم فایل، حذف متادیتا، کار موازی، حالت resume، کار بعد از اتمام (خلاصه / باز کردن / منوی نتایج)، هسته‌ها و تردها، deinterlace و auto-crop. با `s` تنظیمات رو به‌عنوان پیش‌فرض ذخیره کن.
- منوی ۵ (**Profiles**) مجموعه‌ی کامل تنظیمات رو ذخیره و بارگذاری می‌کنه.

### ۳. 💬 استودیوی زیرنویس (`vc --sub`، منوی ۶)

| گزینه | کار |
|---|---|
| **Embed SRT** | یک ترک زیرنویس **نرم** و قابل انتخاب اضافه می‌کنه. فوری — تصویر و صدا هیچ‌وقت دوباره انکود نمی‌شن. |
| **Burn SRT** | زیرنویس رو دائمی روی تصویر می‌کشه (انکود مجدد). استایل از Settings قابل تنظیمه. |
| **Extract** | هر ترک زیرنویس رو به‌صورت فایل `.srt` ذخیره می‌کنه. |
| **Remove** | ترک‌های زیرنویس رو حذف می‌کنه (فوری). |
| **List** | همه‌ی استریم‌های زیرنویس رو نشون می‌ده. |

با `FILE=auto` فایل `movie.srt` کنار `movie.mp4` خودکار پیدا می‌شه (`vc -y --srt auto movie.mp4`، `vc -y --srt-burn auto movie.mp4`). گزینه‌های دیگه: `--keepsubs` (پیش‌فرض)، `--nosubs`، `--nosrt`، `--mkv`.

**اضافه کردن به MKV (نسخه‌ی 3.5.1)** — هیچ‌چیز از دست نمی‌ره:

- هر ترک موجود **همون‌طور که هست** کپی می‌شه: **ASS/SSA** استایل‌دار استایلش رو نگه می‌داره، ترک‌های بیت‌مپ **PGS / VobSub** (بلوری) می‌مونن؛
- **فونت‌های** ضمیمه‌شده حفظ می‌شن تا ASS هنوز درست دیده بشه؛
- صدا با هر کدکی (FLAC، DTS، TrueHD، Opus ...) **همیشه کپی** می‌شه — تو MKV هیچ‌وقت دوباره انکود نمی‌شه؛
- ترک جدید برچسب زبان درست ۳‌حرفی می‌گیره و می‌تونی اون رو **ترک پیش‌فرض** کنی؛
- فایل‌های `.ass` / `.ssa` / `.vtt` هم قبوله (وقتی vc فایل زیرنویس رو می‌پرسه مسیرش رو تایپ کن) و تو MKV فرمتشون رو نگه می‌دارن؛
- نتیجه قبل از جایگزین شدن **بررسی** می‌شه (تعداد ترک‌ها و طول) و فضای خالی هم از قبل چک می‌شه.

**اضافه کردن به MP4** — ترک‌های متنی به `mov_text` تبدیل می‌شن؛ هر ترک صدا جداگانه بررسی می‌شه (AAC/MP3/AC3/E-AC3 کپی، بقیه AAC، و ۵.۱ بیت‌ریت مناسب می‌گیره). ترک‌های بیت‌مپ تو MP4 جا نمی‌شن و گزارش می‌شن — برای نگه داشتنشون از MKV استفاده کن.

**زیرنویس فارسی / عربی** — خیلی از فایل‌های `.srt` با **Windows-1256** یا UTF-16 ذخیره شدن. vc کدگذاری رو تشخیص می‌ده و قبل از استفاده متن رو به **UTF-8** تبدیل می‌کنه (فارسی: «ي» و «ك» عربی به «ی» و «ک» تبدیل می‌شن). برای اجبار یک کدگذاری مشخص: `SUB_CHARSET=CP1256 vc --sub`. همین تبدیل قبل از burn و تو مسیر compress هم اجرا می‌شه.

اسم فایل‌هایی که `[کروشه]`، `*` یا `?` دارن موقع پیدا کردن `.srt` هم‌نام درست پردازش می‌شن.

### ۴. 🛠️ مرکز تعمیر و همگام‌سازی (منوی ۷)

برای ویدیوهایی که روی گوشی خوب پخش می‌شن ولی **روی تلویزیون / USB از صدا عقب می‌افتن، می‌پرن یا پخش نمی‌شن**.

| دستور | چیکار می‌کنه |
|---|---|
| `vc --diagnose FILE` | مشکلات همگام‌سازی و سازگاری با تلویزیون رو گزارش می‌ده (چیزی رو تغییر نمی‌ده). از ابتدا، وسط و انتهای فایل نمونه می‌گیره. |
| `vc --repair FILE…` | تعمیر هوشمند: فقط remux / فقط صدا / فقط تصویر / بازسازی کامل — **سریع‌ترین راهی که واقعاً مشکل رو حل می‌کنه**. برای چند فایل موازی `-j N` اضافه کن. |
| `vc --quickfix FILE` | فقط remux بدون انکود: faststart + تایم‌استمپ تمیز (چند ثانیه). |
| `vc --sync-shift MS FILE` | جابه‌جایی صدا: `+250` = ۲۵۰ میلی‌ثانیه تأخیر، `-250` = جلو انداختن. |
| `vc --repair-lab FILE` | **همه‌ی** روش‌های تعمیر (remux سریع، تعمیر هوشمند، بازسازی کامل، rescue، MP4Box، untrunc) رو تست می‌کنه، زمان و حجم رو می‌سنجه، هر نتیجه رو دوباره چک می‌کنه و **بهترین رو نگه می‌داره**. |

گزینه‌های بیشتر: `--oldtv` (سازگاری فوق‌العاده: پروفایل Main، بدون B-frame، حداکثر ۳۰fps)، `--stereo` (تبدیل surround به استریو)، `--fps RATE`، `--repair-crf N`، `--repair-preset NAME`.

چی رو پیدا می‌کنه: فریم‌ریت متغیر، sample rate نامناسب صدا، اختلاف شروع صدا و تصویر، نبودن faststart، کدک‌های ناسازگار با تلویزیون، تایم‌استمپ‌های گردشده به میلی‌ثانیه (علت شماره‌ی ۱ دیر/زود شدن *تدریجی*). هر خروجی **راستی‌آزمایی** می‌شه (طول، طول صدا/تصویر، دیکد شدن انتهای فایل)؛ فضای خالی دیسک از قبل چک می‌شه؛ تاریخ اصلی فایل حفظ می‌شه؛ و **حالت rescue** با انکود مجدد و رد کردن داده‌ی خراب دوباره تلاش می‌کنه.

### ۵. 🎞️ استخراج فریم (منوی `f`)

**همه‌ی فریم‌های بین دو زمان** رو تو یک پوشه‌ی جدید می‌نویسه — دقیقاً فریم‌به‌فریم، حتی برای ویدیوهای با فریم‌ریت متغیر.

</div>

```bash
vc --frames movie.mp4 -S 1:30 -E 1:40                       # همه‌ی فریم‌ها از 1:30 تا 1:40
vc --frames movie.mp4 -S 90 -E +5 --frame-format png        # 5 ثانیه از 1:30، به‌صورت PNG
vc --frames movie.mp4 -S 0 -E 60 --frame-step key --frame-height 480
```

<div dir="rtl">

`--frame-format jpg|png|bmp|webp`، `--frame-quality 1-31`، `--frame-step N|key`، `--frame-height PX`، `-o DIR`. بازه به‌صورت `[start, end)` است. بدون `-S/-E` یک جریان پرسش و پاسخ تعاملی شروع می‌شه.

### ۶. 🧼 حذف لوگو / واترمارک (منوی `l`)

</div>

```bash
vc --delogo movie.mp4                         # لوگو رو پیدا می‌کنه، نشون می‌ده، می‌پرسه، حذف می‌کنه
vc --logo-detect movie.mp4                    # فقط نشون می‌ده لوگوها کجان (+ یک عکس پیش‌نمایش)
vc --delogo -y --logo-sens high clip.mp4      # بدون سؤال، لوگوهای کم‌رنگ رو هم می‌گیره
vc --delogo --logo-box 1500:40:360:120 -y clip.mp4        # جا رو خودت می‌دی: X:Y:W:H
vc --delogo --logo-box 100:50:200:80@5-12 clip.mp4        # فقط تو ثانیه‌های 5 تا 12
vc --delogo --logo-mode moving clip.mp4       # واترمارکی که بین گوشه‌ها می‌پره
```

<div dir="rtl">

کیفیت حفظ می‌شه: x264 با CRF 17، صدا کپی، همون اندازه و کانتینر (گزینه‌های معمولی مثل `-p`، `-c`، `-r` این رو override می‌کنن). گزینه‌های دیگه: `--logo-sens low|normal|high`، `--logo-mode fixed|moving`، `--logo-window S`، `--logo-windows N`، `--logo-fill smart|simple|box`، `--logo-preview` (عکس قبل/بعد، دور هر لوگو قاب قرمز و **شماره‌دار** — شماره رو بزن تا تغییر اندازه / جابه‌جایی / بررسی مجدد بشه)، `--logo-no-open`.

### ۷. ⚡ آزمایشگاه سرعت و Auto-Tune (منوی `t`)

| دستور | چیکار می‌کنه |
|---|---|
| `vc --tune [FILE]` | **AUTO-TUNE**: تو انتخاب می‌کنی چی مهمه (`--goal speed|balanced|size|quality`)؛ vc همه‌ی پریست‌ها رو مسابقه می‌ده، کیفیت رو (SSIM) نمره می‌ده، تنظیمات CPU رو تست می‌کنه و **بهترین پریست و تنظیمات CPU برای گوشی تو رو ذخیره می‌کنه**. بار اول اجرا یک‌بار پیشنهاد می‌شه. |
| `vc --race FILE` | یک نمونه رو با هر پریست انکود می‌کنه: سرعت، حجم و زمان واقعی. |
| `vc --race-cores FILE` | همون انکود روی همه‌ی هسته‌ها / تردهای کمتر / فقط هسته‌های بزرگ. |
| `vc --stamina FILE` | تست حرارت: یک انکود رو تکرار می‌کنه و سرعت، دما و کلاک CPU رو نشون می‌ده — throttling رو *می‌بینی*. |
| `vc --race-all FILE` | هر سه (چند دقیقه)؛ `--no-quality` نمره‌دهی SSIM رو رد می‌کنه. |
| `vc --cpu` | چیدمان CPU (big/little)، سنجاق کردن و سنسورهای قابل خواندن رو نشون می‌ده. |

تو گوشی‌های big + little، vc می‌تونه ffmpeg رو فقط روی هسته‌های سریع اجرا کنه (`--cores auto`) — به‌صورت پیش‌فرض **خاموشه** چون فقط روی بعضی گوشی‌ها کمک می‌کنه؛ با `--race-cores` تستش کن.

### ۸. 🧰 ابزارها (منوی ۸)

اطلاعات ویدیو · تخمین حجم خروجی (انکود تست ۲۰ ثانیه‌ای) · استودیوی زیرنویس · **ساخت GIF** · **استخراج صدا (MP3 / M4A)** · **تصویر بندانگشتی / contact sheet** · بررسی نصب و انکودرها · نصب / تعمیر خودکار همه‌ی ابزارها · نصب دستور `vc` · نمایش آخرین لاگ · استخراج فریم · آزمایشگاه سرعت · حذف لوگو.
ابزارهای GIF، صدا و بندانگشتی روی یک یا چند ویدیوی صف کار می‌کنن.

### ۹. 🔐 گاوصندوق `.w6w` (منوی `w`)

یک فایل **رمزگذاری‌شده** که می‌تونه ویدیو، عکس، صدا، متن، اسکریپت و زیرنویس رو نگه داره. vc تشخیص می‌ده هر مورد چیه و می‌تونه فهرست، پخش، استخراج و تبدیلشون کنه.

</div>

```bash
vc --w6w pack trip.w6w movie.mp4 movie.srt cover.jpg notes.txt   # ساخت گاوصندوق
vc --w6w pack trip.w6w ~/folder --squeeze --password --comment "Trip 2026"
vc --w6w info trip.w6w          # داخلش چیه
vc --w6w verify trip.w6w        # بررسی سلامت
vc --w6w play trip.w6w 1        # پخش مورد شماره‌ی 1
vc --w6w extract trip.w6w -o out 1 3     # استخراج مورد 1 و 3
vc --w6w convert trip.w6w --to mp4       # تبدیل موارد
vc --w6w key show | export | import HEX | new
```

<div dir="rtl">

- `--squeeze` اول ویدیوها رو با پریست فعلی کوچک می‌کنه، عکس‌ها رو به WebP و صدا رو به Opus تبدیل می‌کنه.
- `--password` به‌جای **کلید دستگاه** این گوشی از رمز عبور استفاده می‌کنه (از کلید حتماً بکاپ بگیر!).
- امنیت: AES-256-CBC با HMAC-SHA256 روی کل فایل (encrypt-then-MAC)، و PBKDF2-HMAC-SHA256 (۶۰۰٬۰۰۰ دور) در حالت رمز عبور.
- هر pack نتیجه‌ی خودش رو **دوباره باز می‌کنه** (MAC، manifest، کل آرشیو) و به‌جای گزارش موفقیت دروغین، با خطا پاکش می‌کنه. استخراج فقط موارد نام‌برده‌شده رو برمی‌داره، لینک‌ها و ورودی‌های عجیب رو رد می‌کنه و نام‌ها رو پاک‌سازی می‌کنه.

### ۱۰. 📊 نتایج و مقایسه (منوی `r`)

بعد از هر دسته: باز کردن خروجی یا فایل اصلی تو پخش‌کننده، یک **جدول مقایسه** و یک **ویدیوی مقایسه‌ی کنار هم** (اصلی در برابر فشرده‌شده).

---

## 🧾 همه‌ی دستورها در یک نگاه

</div>

```text
vc                              منوی تعاملی
vc --sub                        استودیوی زیرنویس
vc [options] FILE|DIR ...       بارگذاری فایل/پوشه (منو باز می‌شه مگر با -y)

vc --repair | --diagnose | --quickfix | --sync-shift | --repair-lab
vc --frames | --delogo | --logo-detect
vc --race | --race-cores | --stamina | --race-all | --cpu | --tune
vc --w6w pack | info | verify | play | key | extract | convert
vc --setup [GROUP]    نصب همه‌ی چیزهایی که قابلیت‌ها لازم دارن
vc --doctor           نشون می‌ده چه ابزارهایی نصبه
vc --selftest [full]  تست خودکار روی همین گوشی
vc --install          نصب این اسکریپت به‌عنوان دستور 'vc'
vc --version          نمایش نسخه
vc -h                 راهنمای کامل با همه‌ی گزینه‌ها
```

<div dir="rtl">

## 🍳 دستورهای آماده

</div>

```bash
vc -y -p target -t 95 movie.mp4               # زیر 100 مگابایت، 720p
vc -y -p av1 movie.mp4                        # AV1 نسل بعد، کوچک‌ترین فایل‌ها
vc -y -j 3 -p turbo ~/storage/movies          # 3 فایل همزمان
vc -y --srt auto -p balanced movie.mp4        # فشرده‌سازی + اضافه کردن movie.srt
vc -y --srt-burn auto -p social movie.mp4     # فشرده‌سازی + چسباندن زیرنویس روی تصویر
vc -y -p small --mkv movie.mp4                # خروجی MKV (زیرنویس SRT بومی)
vc movie.mkv -p web -y                        # VP9 + Opus در WebM برای وب‌سایت
vc old_dvd.vob --format mp4 --autocrop -y     # ریپ DVD: deinterlace و حذف نوار سیاه
vc --repair --oldtv movie.mkv                 # حالت تلویزیون/USB خیلی قدیمی
vc --repair -j 4 *.mp4                        # تعمیر 4 فایل همزمان
vc --sync-shift -250 movie.mp4                # صدا 250 میلی‌ثانیه دیر بود
```

<div dir="rtl">

## ⚙️ فایل‌ها و تنظیمات

| مسیر | محتوا |
|---|---|
| `~/.config/vidcompress/settings.conf` | پیش‌فرض‌های ذخیره‌شده‌ی تو |
| `~/.config/vidcompress/profiles/` | پروفایل‌های ذخیره‌شده |
| `~/.config/vidcompress/last_run.log` | لاگ آخرین اجرا (منو: Tools ← *Show last log*) |
| `~/.config/vidcompress/setup.log` | لاگ `vc --setup` |

متغیر محیطی: `SUB_CHARSET=CP1256` کدگذاری یک فایل زیرنویس غیر UTF-8 رو اجباری می‌کنه.

## 🩺 عیب‌یابی

| مشکل | راه‌حل |
|---|---|
| `ffmpeg: command not found` | `vc --setup` (یا `pkg install ffmpeg`) |
| vc ویدیوهات رو نمی‌بینه | `termux-setup-storage` رو اجرا کن و دسترسی حافظه رو Allow کن |
| زیرنویس به شکل `؟؟؟` / متن به‌هم‌ریخته | فایل UTF-8 نیست: `SUB_CHARSET=CP1256 vc --sub` (اگه تبدیل خطا داد `libiconv` رو نصب کن) |
| یک قابلیت می‌گه ابزاری نصب نیست | `vc --doctor` و بعد `vc --setup` |
| گوشی داغ می‌شه و کند می‌شه | با `vc --stamina FILE` throttling رو ببین، `-j` رو کم کن، از `-p turbo` یا `-p fast` استفاده کن |
| چیزی خطا داد | Tools ← *Show last log* یا فایل `~/.config/vidcompress/last_run.log` رو بخون |
| همه‌چیز روی گوشی‌م درسته؟ | `vc --selftest full` |

## 🆕 تازه‌ها در 3.5.1

**اضافه کردن زیرنویس به MKV، از نو ساخته شد.** رفع شد: حذف شدن ترک‌های PGS/VobSub موجود · تبدیل ASS/SSA به SRT ساده · از بین رفتن فونت‌های ضمیمه · انکود مجدد صدای FLAC/DTS/TrueHD/Opus به AAC · خطا یا متن خراب با زیرنویس Windows-1256 / UTF-16 · پیدا نشدن `.srt` با اسم‌هایی که `[کروشه]` دارن · رد شدن MKV بدون duration. جدید: انتخاب ترک پیش‌فرض، خلاصه‌ی اینکه چی نگه داشته شد، بررسی نتیجه قبل از جایگزینی، چک فضای خالی، و یک تست خودکار جدید (`subtitles into MKV (nothing lost)`).

نکات مهم نسخه‌های قبلی: **3.5** (هدر اسکریپت رو ببین)، **3.1** آزمایشگاه تعمیر + نصب‌کننده‌ی خودکار، **3.0** فرمت‌های ورودی بسیار بیشتر، خروجی MKV/WebM/MOV/AVI/TS، VP9، گاوصندوق `.w6w`، **2.5** Auto-Tune، **2.3** استخراج فریم و مسابقه‌ی پریست‌ها، **2.1** مرکز تعمیر و همگام‌سازی، **2.0** استودیوی زیرنویس، دسته‌ی موازی، AV1. تاریخچه‌ی کامل بالای `vc.sh` هست.

## 🤝 مشارکت

[Issue](https://github.com/Alireza123456w6w/V.C.-a-video-compresser-for-termux/issues) و Pull Request خوش‌آمده. قبل از ارسال تغییر، `bash -n vc.sh` و `vc --selftest full` رو اجرا کن.

## 👤 سازنده

ساخته‌ی **W6W** · [offers-pishnahadat.vercel.app](https://offers-pishnahadat.vercel.app)

</div>

---

<div align="center">

⭐ If VidCompress saved you time (or storage), give the repository a star!
⭐ اگه VidCompress وقت (یا حافظه‌ات) رو نجات داد، به مخزن یه ستاره بده!

</div>
