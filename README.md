<div align="center">

# 🎬 VidCompress (`vc`)

**The all-in-one video toolkit for your phone — one Bash script, powered by ffmpeg.**
Compress, repair, subtitle, clean and vault your videos right inside **Termux**.

![version](https://img.shields.io/badge/version-3.5.1-blue)
![shell](https://img.shields.io/badge/shell-bash-4EAA25)
![platform](https://img.shields.io/badge/platform-Termux%20%2F%20Android-brightgreen)
![engine](https://img.shields.io/badge/engine-ffmpeg-007808)

**English** · [فارسی](README.fa.md)

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
termux-setup-storage          # allow access to your phone's storage (tap "Allow")
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

<div align="center">

⭐ If VidCompress saved you time (or storage), give the repository a star!

</div>
