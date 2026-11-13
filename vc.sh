#!/usr/bin/env bash
# =============================================================================
#  VidCompress (vc) v3.0 - ffmpeg video compression toolkit for Termux
#  Creator : W6W
#  Website : offers-pishnahadat.vercel.app
#
#  Quick start (in Termux):
#     bash vc.sh --setup      # install ffmpeg + storage access
#     bash vc.sh --install    # install the "vc" command
#     vc                      # interactive menu
#     vc --sub                # subtitle studio (SRT add/extract/remove)
#     vc --repair movie.mp4   # fix A/V sync drift (TV & USB player ready)
#     vc --frames movie.mp4 -S 1:30 -E 1:40   # EVERY frame 1:30 -> 1:40 into a new folder
#     vc --race movie.mp4     # which preset is fastest / smallest / best quality on THIS phone?
#     vc --race-all movie.mp4 # + CPU-core test + heat test (does speed drop while it runs?)
#     vc --cpu                # CPU layout (big/little cores), pinning, sensors
#     vc --tune               # AUTO-TUNE: test this phone, pick + save the fastest settings
#     vc -y -p target -t 95 video.mp4     # CLI: compress to ~95 MB
#     vc -h                   # all options
#
#  What's new in 3.0:
#   + FORMATS: reads far more video formats (MPEG/VOB/TS/M2TS, WMV/ASF, FLV, RM/RMVB,
#     OGV, MXF, DV, 3GP, raw H.264/H.265 and more - anything ffmpeg can decode works,
#     also files with unusual extensions when you type the path). Output containers:
#     MP4, MKV, WebM, MOV, AVI, TS (vc picks matching codecs: WebM = VP9/AV1 + Opus,
#     AVI = H.264 + MP3, subtitles only where the container can hold them).
#   + NEW CODEC: VP9 (+ preset "web" -> WebM) next to x265, x264, AV1, hardware.
#   + Interlaced sources (DVD, TV recordings) are deinterlaced automatically (also in
#     Repair); optional AUTO-CROP removes black bars (smaller files).
#   + .w6w VAULT: a new container that holds videos, pictures, audio, text, scripts,
#     subtitles... encrypted. vc detects what each item is, and can list, play,
#     extract and convert them. See menu w or: vc --w6w
#
#  What's new in 2.8:
#   + PICK FROM THE QUEUE: in Repair & Sync and in the Tools (GIF / audio / thumbnails /
#     info) you now choose WHICH of the videos you queued earlier to work on: one
#     (type its number), several (1 3 5-7) or all (a / Enter). The rest of the queue
#     stays untouched for later.
#
#  What's new in 2.7:
#   + "a" = ADD ALL: in the video finder, a adds EVERY video that is found (or every
#     search result), not just one page. Tools (GIF / audio / thumbnails) and
#     Repair open the same finder when the queue is empty, so a works everywhere.
#   + FOLDER BROWSER FIXED: on phones where ~/storage/shared is a link, it showed only
#     "/sdcard" with no folders and no videos. Now it lists folders (with how many
#     videos each holds, newest first), x shows empty folders too, aa adds everything
#     inside a folder including sub-folders, u goes up. Folders typed as /sdcard or
#     ~/storage/shared also work on the command line now.
#   + Queued videos are now ticked correctly in the finder list on every phone.
#
#  What's new in 2.6:
#   + QUEUE FOR EVERYTHING: pick many videos once (menu 1), then Repair & Sync
#     (diagnose / auto-repair / quick fix / audio shift) and the Tools (GIF,
#     audio, thumbnails) run over the whole queue ONE AFTER ANOTHER on their own.
#     Questions are asked once and reused; failures never stop the queue; a
#     summary lists every file. Diagnose-all offers to repair only the broken ones.
#   + REPAIR IS MORE RELIABLE: RESCUE MODE (if the first attempt fails, vc retries
#     by re-encoding and skipping damaged data), a VERIFY step on every output
#     (length, audio/video length, the end of the file really decodes), disk-space
#     check BEFORE a long job, original date kept (file time + creation_time, so the
#     gallery keeps its place), damaged headers read with a bigger probe, HDR warning.
#
#  What's new in 2.5:
#   + EASY VIDEO FINDER: menu 1 now shows your NEWEST videos from the whole phone
#     (Camera, Download, Telegram, WhatsApp...) as a short list. Pick by number,
#     or just TYPE PART OF A NAME to search. Nothing to browse, nothing to paste.
#   + AUTO-TUNE (menu t, first launch, or vc --tune): you say what matters
#     (speed / balanced / small / quality); vc races every preset on one of your
#     videos, scores the quality (SSIM), tests the CPU setup, then picks and SAVES
#     the best preset and CPU settings for this phone. Offered once at first start.
#   + Speed lab is now on the main menu (t).
#
#  What's new in 2.4:
#   + BIG-CORE PINNING: on phones with big + little cores (e.g. 4 fast + 4 slow)
#     vc finds the fast cores and runs ffmpeg only on them, with the encoder
#     thread count matched to those cores, so slow cores no longer hold the
#     encode back. OFF by default (all cores) because it only helps on some phones:
#     test it with vc --race-cores, then enable with --cores auto or Settings 24.
#   + SPEED LAB (vc --race-all, Tools 12): preset race now also scores quality
#     (SSIM); a CPU test compares all cores / fewer threads / big cores only;
#     a HEAT TEST repeats the same encode and shows speed, temperature and CPU
#     clock per round so you can SEE thermal throttling. It can save the best
#     CPU setup as your default.
#   + --threads N / Settings 25: fixed encoder thread budget.
#
#  What's new in 2.3:
#   + FRAME EXTRACTOR: choose a start and an end time, vc creates a new folder
#     and writes EVERY frame between the two points as images (JPG / PNG / BMP /
#     WebP). Frame-exact (never duplicates or drops frames, even on variable
#     frame rate videos), checks free space first, builds on fast local storage
#     and moves the finished folder in one pass. Menu: f   CLI: --frames
#   + PRESET RACE: encodes a short sample with every preset and shows the real
#     speed, estimated size and estimated time on YOUR device (vc --race).
#   + Much less overhead: one ffprobe call instead of 3-5 per file, repair
#     diagnosis scans its 3 sections in parallel, progress bar and menus no
#     longer fork helper processes, file sizes are cached.
#   + Parallel batches share the CPU properly (threads are split between jobs
#     instead of every job fighting for all cores).
#   + Audio that is already AAC at or below the target bitrate is copied
#     instead of re-encoded: faster AND no generation loss.
#   + The frame-rate filter now runs BEFORE scaling/denoise, so dropped frames
#     are never processed. New option: sharper Lanczos downscaling (Settings 23
#     or --lanczos; a bit bigger files, off by default).
#   + --resume skips files whose finished output already exists; directories
#     passed on the command line no longer re-compress earlier outputs.
#   + Options may now come before or after the files (vc movie.mp4 -p turbo -y).
#   + Fixed: with --nosubs (or bitmap subtitles) plus --srt, old subtitle tracks
#     were still mapped; HDR sources now get a clear warning.
#
#  What's new in 2.2:
#   + FIXED the Android error "Unable to re-open ... output file for
#     shifting data / Error writing trailer": every MP4 is now BUILT on fast
#     local storage (Termux-private) and moved to the destination in one
#     pass. Also faster, atomic, and no .part files left in your folders.
#   + Repair speed overhaul - speed first, quality never below before:
#     - Turbo re-encode by default: CRF 16 @ veryfast = the quality of
#       CRF 18 @ medium, roughly 2x faster
#     - Smart tiers: remux-only / audio-only rebuild (minutes!) / full
#       rebuild - re-encodes ONLY what is actually broken
#     - Parallel repair:  vc --repair a.mp4 b.mp4 -j 4
#   + Drift-proof timestamps: detects & rebuilds millisecond-rounded frame
#     timestamps (the No.1 cause of GRADUAL drift on TVs) and drops the old
#     forced 90000 timescale that itself planted rounding on 23.976 fps films
#   + Deeper diagnosis: samples 3 sections of the file (start/middle/end),
#     stricter audio checks (mp3 & 44.1 kHz now flagged for TV safety)
#
#  What's new in 2.1:
#   + Repair & Sync Center: fixes videos that play fine in VLC but drift
#     out of sync (or refuse to play) on TVs / USB players:
#       - Diagnose    : finds variable frame rate, bad audio rates,
#                       A/V start offsets, missing faststart, TV-unsafe codecs
#       - Auto-Repair : VFR -> CFR, 48 kHz AAC, H.264, clean timestamps,
#                       faststart MP4 - re-encodes ONLY what is broken
#       - Quick fix   : seconds-fast remux (faststart + clean timestamps)
#       - Shift audio : move the soundtrack by +/- milliseconds
#   + CLI: --repair, --diagnose, --quickfix, --sync-shift, --oldtv, --stereo
#
#  What's new in 2.0:
#   + Subtitle Studio: embed (soft) / burn (hard) / extract / remove SRT
#   + Results menu: open output in player, compare table, side-by-side
#     comparison video (ORIGINAL vs COMPRESSED)
#   + Parallel batch compression (multiple files at once)
#   + AV1 (SVT-AV1) next-gen codec support
#   + Faster tuned presets (balanced now uses encoder speed "fast")
#   + Real folder browser for picking videos
#   + Tools: GIF maker, audio extraction, thumbnails / contact sheet
#   + MP4 / MKV output, keep-subtitle-tracks option, configurable
#     "after finishing" action
# =============================================================================

VERSION="3.0"
CREATOR="W6W"
WEBSITE="offers-pishnahadat.vercel.app"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vidcompress"
CONF="$CONF_DIR/settings.conf"
PROF_DIR="$CONF_DIR/profiles"
LOG="$CONF_DIR/last_run.log"
VIDEO_EXT='mp4|m4v|mov|qt|mkv|mk3d|webm|avi|divx|xvid|wmv|asf|wm|flv|f4v|3gp|3g2|3gpp|mpg|mpeg|mpe|m1v|m2v|mpv|ts|m2ts|mts|m2t|tp|trp|vob|ogv|ogm|rm|rmvb|mxf|dv|dif|mj2|y4m|ivf|nut|gxf|amv|bik|smk|vro|evo|wtv|dvr-ms|mjpeg|mjpg|h264|264|h265|265|hevc|avc|vc1|lrv|insv|mp4v'
SETTING_VARS="CODEC CRF VBR SPEED HEIGHT FPS ABR AUDIO TARGET_MB DENOISE STRIP_META OUTDIR SUFFIX PRESET_NAME PARALLEL_JOBS KEEP_SUBS SUB_MODE SUB_FILE SUB_LANG SUB_SIZE SUB_COLOR OUT_EXT FINISH_ACTION SKIP_DONE FRAME_FMT FRAME_Q FRAME_STEP FRAME_H SCALER CORES THREADS DEINT AUTOCROP"
PRESET_LIST="balanced quality small tiny social compat fast turbo target hardware av1 web"

# ------------------------------------------------------------------ colors ---
if [[ -t 1 ]]; then
  C_B=$'\e[1m'; C_D=$'\e[2m'; C_R=$'\e[31m'; C_G=$'\e[32m'
  C_Y=$'\e[33m'; C_C=$'\e[36m'; C_0=$'\e[0m'
else
  C_B=; C_D=; C_R=; C_G=; C_Y=; C_C=; C_0=
fi
ok()   { printf '%s\n' "${C_G}✔ $*${C_0}"; }
warn() { printf '%s\n' "${C_Y}! $*${C_0}" >&2; }
err()  { printf '%s\n' "${C_R}✘ $*${C_0}" >&2; }
info() { printf '%s\n' "${C_C}$*${C_0}"; }

# ------------------------------------------------------------------- state ---
SELECTED=()
RESULTS=()
IN_OPTS=()
VFARG=()
VENC=()
AENC=()
META=()
TMPD=""
CUR_TMP=""
BATCH_TMP=""
WAKE=0
EDUR=0
DUR=0
N_OK=0
N_FAIL=0
TOTAL_IN=0
TOTAL_OUT=0
NONINTERACTIVE=0
SIMPLE=0            # 1 = compact output (parallel mode)
LOGF=""             # per-job log file override
STATS=""            # per-job stats file (parallel mode)
RESULT_FILE=""      # per-job results file (parallel mode)
SUBFILTER=""
COMPARE_OUT=""
# --- repair & sync (v2.1)
REPAIR_ACTION=""; REPAIR_SHIFT_MS=""; REPAIR_FPS=""
REPAIR_CRF=16; REPAIR_PRESET=veryfast; REPAIR_OLDTV=0; REPAIR_STEREO=0; REPAIR_AUTO=0
STAGE_ROOT=""; STAGE_WARNED=0; OT_TMP=""; OT_DIRECT=0
# --- speed internals (v2.3)
declare -A SZC=()                 # cached sizes of source files (never of outputs)
TERM_COLS=""                      # terminal width, refreshed on resize only
THREADS_PER_JOB=0                 # 0 = encoder default; >0 = split CPU between parallel jobs
STATS_OPT=(); FPSMODE_OPT=(-vsync 0); ENCTB_OPT=(); FF_VER=""; FF_CAPS_DONE=0
AUD_COPY=0; BATCH_T0=0; CUR_TMPDIR=""; SEL_BYTES=0; FSZ=0; RATIO=0; SECS_US=0; FMT_TAG=""
SRC_AFPS=0; SRC_PIX=""; SRC_TRC=""; SRC_ACH=0; SRC_NSUBS=0; SRC_SUBBAD=0
FR_ARGS=(); FR_VF=(); FR_EXT=jpg
# --- CPU layout / pinning / sensors (v2.4). VC_* paths can be overridden for tests.
VC_SYSFS=${VC_SYSFS:-/sys/devices/system/cpu}
VC_CPUINFO=${VC_CPUINFO:-/proc/cpuinfo}
VC_THERMAL=${VC_THERMAL:-/sys/class/thermal}
CPU_DONE=0; CPU_N=0; CPU_HETERO=0; CPU_TOPO=""; CPU_SRC="none"; BIG_LIST=""; BIG_MASK=""; BIG_N=0
ORIG_MASK=""; PIN_MASK=""; PIN_N=0; PIN_LIST=""; PIN_NOTE=""; TASKSET=""; MASK_HEX=""; MASK_N=0
TEMP_C=""; TEMP_NOTE=""; FREQ_FILE=""; FREQ_PID=""; FREQ_CPUS=""; FREQ_AVG=""; FREQ_MIN=""
NOQUALITY=0; SSIM_VAL=""; NOW_US=0; CPU_MODE=0
declare -a CPU_CAP=() CPU_FREQ=() CPU_PART=() CPU_BIGIDX=()
RACE_LEN=8; TUNE_GOAL=""; TUNE_PICK=""; TUNE_WHY=""; AGE_TXT=""; TUNE_MODE=0
ASK_MEMO_DIR=""; FORCE_TARGET=""; QUEUE_MS=""; VERIFY_OK=1; VERIFY_NOTE=""; DIAG_NPROBS=-1
AENC_NAME=aac; CT_SUBS=mov_text; CT_FMT=mp4; CT_FAST=1; CT_STAGE=1; CT_HVC=1; CROP_VF=""; SRC_FIELD=""; D_FIELD=""
FV_ROOT=""; FV_REAL=""
declare -a PICKED=()
declare -a DIAG_PROBS=()
D_CTIME=""; D_TRC=""; D_NSUBS=0; D_VDUR=""; D_ADUR=""
declare -a RACE_R_NAMES=() RACE_R_SPD=() RACE_R_SZ=() RACE_R_Q=() RACE_R_TM=() FV_ALL=()

# --------------------------------------------------------- small utilities ---
fsize()     { stat -c %s -- "$1" 2>/dev/null || echo 0; }
fsize_v()    { local f=$1; if [[ -z ${SZC[$f]-} ]]; then SZC[$f]=$(stat -c %s -- "$f" 2>/dev/null || echo 0); fi; FSZ=${SZC[$f]}; }
sum_sizes()  { local f; SEL_BYTES=0; for f in "${SELECTED[@]}"; do fsize_v "$f"; SEL_BYTES=$(( SEL_BYTES + FSZ )); done; }
clear_screen() { [[ -t 1 ]] && printf '\033[H\033[2J\033[3J'; return 0; }
pause()     { if [[ -t 0 && $NONINTERACTIVE -eq 0 ]]; then read -r -p "Press Enter to continue..." _ || true; fi; }
refresh_cols() { local c; c=$(tput cols 2>/dev/null) || c=${COLUMNS:-44}; [[ $c =~ ^[0-9]+$ ]] || c=44; TERM_COLS=$c; }
term_cols() { [[ -n $TERM_COLS ]] || refresh_cols; echo "$TERM_COLS"; }
fonts_dir() {   # best directory of ttf fonts for subtitle burn-in
  if [[ -d /system/fonts ]]; then printf '%s' /system/fonts
  elif [[ -d /usr/share/fonts ]]; then printf '%s' /usr/share/fonts
  else printf '%s' ""; fi
}
label_font() {  # a bold ttf for drawtext labels
  local c
  for c in /system/fonts/Roboto-Bold.ttf \
           /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf \
           /usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf; do
    [[ -f $c ]] && { printf '%s' "$c"; return 0; }
  done
  return 1
}
human() {   # bytes -> "1.5 GB" / "12.3 MB" / "800 KB" (pure bash, no forks)
  local b=${1:-0} x
  [[ $b =~ ^[0-9]+$ ]] || b=0
  if   (( b >= 1073741824 )); then x=$(( (b * 100 + 536870912) / 1073741824 )); printf '%d.%02d GB' $(( x / 100 )) $(( x % 100 ))
  elif (( b >= 1048576 ));    then x=$(( (b * 10 + 524288) / 1048576 ));        printf '%d.%d MB' $(( x / 10 )) $(( x % 10 ))
  elif (( b < 1024 )); then printf '%d B' "$b"
  else printf '%d KB' $(( (b + 512) / 1024 )); fi
}
fmt_time() {   # seconds -> hh:mm:ss (pure bash)
  local s=${1%%.*}
  [[ $s =~ ^[0-9]+$ ]] || s=0
  printf '%02d:%02d:%02d' $(( s / 3600 )) $(( s % 3600 / 60 )) $(( s % 60 ))
}
pretty() {
  local p=$1 sh="$HOME/storage/shared"
  if [[ $p == "$sh"* ]]; then p="/sdcard${p#"$sh"}"; fi
  printf '%s' "$p"
}
trunc() {
  local m=$(( ${TERM_COLS:-44} - 15 ))
  (( m < 12 )) && m=12
  if (( ${#1} > m )); then printf '%s…' "${1:0:m-1}"; else printf '%s' "$1"; fi
}
to_sec() {   # "90" | "1:30" | "0:01:30.5"  ->  seconds (millisecond precision)
  [[ $1 =~ ^([0-9]+:){0,2}[0-9]+(\.[0-9]+)?$ ]] || return 1
  awk -F: '{ if (NF==3) v=$1*3600+$2*60+$3; else if (NF==2) v=$1*60+$2; else v=$1
             s=sprintf("%.3f", v); sub(/0+$/, "", s); sub(/\.$/, "", s); print s }' <<<"$1"
}
secs_us() {   # "12.345" -> SECS_US=12345000 (integer microseconds, no forks)
  local s=${1:-0} i f
  i=${s%%.*}; f=""; [[ $s == *.* ]] && f=${s#*.}
  [[ $i =~ ^[0-9]+$ ]] || i=0
  f=${f}000000; f=${f:0:6}
  [[ $f =~ ^[0-9]+$ ]] || f=0
  SECS_US=$(( 10#$i * 1000000 + 10#$f ))
}
ratio_dec() {   # "30000/1001" | "25" , decimals(2|3) -> RATIO="29.97" (no forks)
  local r=$1 n d sc=${2:-2} pw=100
  (( sc == 3 )) && pw=1000
  if [[ $r == */* ]]; then n=${r%/*}; d=${r#*/}; else n=$r; d=1; fi
  if ! [[ $n =~ ^[0-9]+$ && $d =~ ^[0-9]+$ ]]; then RATIO=0; return; fi
  if (( d == 0 )); then RATIO=$n; return; fi
  local x=$(( (n * pw + d / 2) / d ))
  printf -v RATIO '%d.%0*d' $(( x / pw )) "$sc" $(( x % pw ))
}
ask() {
  local p=$1 d=${2:-} a mk=""
  if [[ -n $ASK_MEMO_DIR ]]; then               # batch tools: reuse the first answer for every file
    mk="$ASK_MEMO_DIR/${p//[^A-Za-z0-9]/_}"; mk=${mk:0:240}
    if [[ -f $mk ]]; then printf '%s' "$(<"$mk")"; return 0; fi
  fi
  if [[ -n $d ]]; then
    read -r -p "$p [$d]: " a || exit 0
    a=${a:-$d}
  else
    read -r -p "$p: " a || exit 0
  fi
  [[ -n $mk ]] && printf '%s' "$a" > "$mk"
  printf '%s' "$a"
}
ask_int() {   # prompt min max default
  local a
  while true; do
    a=$(ask "$1 ($2-$3)" "$4")
    if [[ $a =~ ^[0-9]+$ ]] && (( a >= $2 && a <= $3 )); then printf '%s' "$a"; return; fi
    err "Enter a number between $2 and $3." >&2
  done
}
yesno() {     # prompt default(y|n)
  local a
  if [[ -n $ASK_MEMO_DIR && $1 == Open* ]]; then [[ ${2:-y} == y* ]]; return; fi   # never open files in a batch
  a=$(ask "$1 (y/n)" "${2:-y}")
  [[ ${a,,} == y* ]]
}

# ============================================ CPU LAYOUT & PINNING (v2.4)
# Phones mix fast and slow cores. The encoder splits its work evenly, so one slow
# core can hold every other thread back. vc finds the fast cores and (when Android
# allows it) restricts ffmpeg to them. Everything is best-effort: if a sysfs file
# or taskset is not available, vc simply runs on all cores like before.
idx_ranges() {   # sorted indexes -> "0-3,5"
  local out="" start="" prev="" cur
  for cur in "$@"; do
    if [[ -z $start ]]; then start=$cur; prev=$cur; continue; fi
    if (( cur == prev + 1 )); then prev=$cur; continue; fi
    if (( start == prev )); then out+="${out:+,}$start"; else out+="${out:+,}$start-$prev"; fi
    start=$cur; prev=$cur
  done
  if [[ -n $start ]]; then if (( start == prev )); then out+="${out:+,}$start"; else out+="${out:+,}$start-$prev"; fi; fi
  printf '%s' "$out"
}
mask_of_list() {   # "4-7,2" -> MASK_HEX / MASK_N
  local part a b i m=0 n=0
  local -a parts
  IFS=',' read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    if [[ $part =~ ^([0-9]+)-([0-9]+)$ ]]; then a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}
    elif [[ $part =~ ^[0-9]+$ ]]; then a=$part; b=$part
    else return 1; fi
    (( a <= b && b < 62 )) || return 1
    for (( i = a; i <= b; i++ )); do
      if (( ! (m & (1 << i)) )); then m=$(( m | (1 << i) )); n=$(( n + 1 )); fi
    done
  done
  (( n > 0 )) || return 1
  printf -v MASK_HEX '%x' "$m"; MASK_N=$n
}
find_taskset() {
  [[ -n $TASKSET ]] && return 0
  TASKSET=$(command -v taskset 2>/dev/null)
  [[ -z $TASKSET && -x /system/bin/taskset ]] && TASKSET=/system/bin/taskset
  [[ -n $TASKSET ]]
}
get_affinity() {   # hex mask of THIS shell (children inherit it), "" if unknown
  local out
  find_taskset || return 1
  out=$("$TASKSET" -p $$ 2>/dev/null) || return 1
  out=${out##*[: ]}; out=${out#0x}
  [[ $out =~ ^[0-9a-fA-F]+$ ]] || return 1
  printf '%x' "$(( 16#$out ))"
}
set_affinity() {   # hex mask -> 0 = applied and confirmed
  local want got
  find_taskset || return 1
  "$TASKSET" -p "$1" $$ >/dev/null 2>&1 || return 1
  want=$(( 16#$1 )); got=$(get_affinity) || return 1
  (( 16#$got == want ))
}

detect_cpu() {   # CPU_N, CPU_TOPO, CPU_HETERO, BIG_LIST/BIG_MASK/BIG_N, CPU_SRC
  (( CPU_DONE )) && return 0
  CPU_DONE=1
  local d i on cap fq maxi=-1 n=0 mx=0 thr j line cur a b ok_cap=1 ok_fq=1 metric="none" run_a run_b run_m tag
  local -a seen=() M=() isbig=()
  CPU_CAP=(); CPU_FREQ=(); CPU_PART=(); CPU_BIGIDX=()
  BIG_LIST=""; BIG_MASK=""; BIG_N=0; CPU_HETERO=0; CPU_TOPO=""; CPU_SRC="none"
  for d in "$VC_SYSFS"/cpu[0-9]*; do
    [[ -d $d ]] || continue
    i=${d##*/cpu}; [[ $i =~ ^[0-9]+$ ]] || continue
    on=1; [[ -r $d/online ]] && { read -r on < "$d/online"; } 2>/dev/null
    [[ $on == 0 ]] && continue
    cap=""; fq=""
    [[ -r $d/cpu_capacity ]] && { read -r cap < "$d/cpu_capacity"; } 2>/dev/null
    [[ -r $d/cpufreq/cpuinfo_max_freq ]] && { read -r fq < "$d/cpufreq/cpuinfo_max_freq"; } 2>/dev/null
    if [[ -z $fq && -r $d/cpufreq/scaling_max_freq ]]; then { read -r fq < "$d/cpufreq/scaling_max_freq"; } 2>/dev/null; fi
    [[ $cap =~ ^[0-9]+$ ]] || { cap=""; ok_cap=0; }
    [[ $fq  =~ ^[0-9]+$ ]] || { fq="";  ok_fq=0; }
    CPU_CAP[i]=$cap; CPU_FREQ[i]=$fq; seen[i]=1; n=$(( n + 1 )); (( i > maxi )) && maxi=$i
  done
  CPU_N=$n
  if (( n == 0 )); then
    CPU_N=$(nproc --all 2>/dev/null || nproc 2>/dev/null || echo 0); [[ $CPU_N =~ ^[0-9]+$ ]] || CPU_N=0
    return 0
  fi
  # which number tells fast from slow? capacity (best) > max frequency > CPU part
  if   (( ok_cap )); then metric=cap;  thr=60; CPU_SRC="cpu_capacity"
  elif (( ok_fq  )); then metric=freq; thr=80; CPU_SRC="max frequency"
  fi
  if [[ $metric != none ]]; then
    for (( i = 0; i <= maxi; i++ )); do
      [[ -n ${seen[i]-} ]] || continue
      if [[ $metric == cap ]]; then M[i]=${CPU_CAP[i]}; else M[i]=${CPU_FREQ[i]}; fi
      (( M[i] > mx )) && mx=${M[i]}
    done
    for (( i = 0; i <= maxi; i++ )); do
      [[ -n ${seen[i]-} ]] || continue
      if (( M[i] * 100 >= mx * thr )); then isbig[i]=1; else isbig[i]=0; fi
    done
  elif [[ -r $VC_CPUINFO ]]; then
    cur=""
    while IFS= read -r line; do
      case $line in
        processor*) cur=${line##*: };;
        "CPU part"*) [[ $cur =~ ^[0-9]+$ ]] && CPU_PART[cur]=${line##*: };;
      esac
    done < "$VC_CPUINFO"
    local littles=0 bigs=0 unk=0 prt
    for (( i = 0; i <= maxi; i++ )); do
      [[ -n ${seen[i]-} ]] || continue
      prt=${CPU_PART[i]-}
      [[ -n $prt ]] || { unk=1; continue; }
      case ${prt,,} in
        0xd01|0xd02|0xd03|0xd04|0xd05|0xd46|0xd80|0xc05|0xc07) isbig[i]=0; littles=$(( littles + 1 ));;
        *) isbig[i]=1; bigs=$(( bigs + 1 ));;
      esac
    done
    if (( unk )); then return 0; fi
    CPU_SRC="CPU part"; metric=part
  else
    return 0
  fi
  for (( i = 0; i <= maxi; i++ )); do
    [[ -n ${seen[i]-} ]] || continue
    if [[ ${isbig[i]} == 1 ]]; then CPU_BIGIDX+=("$i"); else CPU_HETERO=1; fi
  done
  (( ${#CPU_BIGIDX[@]} == 0 )) && { CPU_HETERO=0; return 0; }
  BIG_N=${#CPU_BIGIDX[@]}; BIG_LIST=$(idx_ranges "${CPU_BIGIDX[@]}")
  mask_of_list "$BIG_LIST" && BIG_MASK=$MASK_HEX
  # topology text: runs of identical cores
  run_a=""; run_m=""
  for (( i = 0; i <= maxi + 1; i++ )); do
    if (( i <= maxi )) && [[ -z ${seen[i]-} ]]; then continue; fi
    if (( i <= maxi )); then
      if [[ $metric == cap ]]; then cur="${CPU_CAP[i]}|${CPU_FREQ[i]}"; elif [[ $metric == freq ]]; then cur="${CPU_FREQ[i]}"; else cur="${CPU_PART[i]}"; fi
    else cur="<end>"; fi
    if [[ -n $run_a && $cur != "$run_m" ]]; then
      tag=""
      if [[ -n ${CPU_FREQ[run_b]} ]]; then local f10=$(( (CPU_FREQ[run_b] + 5000) / 10000 )); printf -v tag '%d.%02d GHz' $(( f10 / 100 )) $(( f10 % 100 ))
      elif [[ -n ${CPU_CAP[run_b]} ]]; then tag="cap ${CPU_CAP[run_b]}"
      else tag="part ${CPU_PART[run_b]-?}"; fi
      if (( CPU_HETERO )); then if [[ ${isbig[run_b]} == 1 ]]; then tag+=" big"; else tag+=" little"; fi; fi
      if (( run_a == run_b )); then CPU_TOPO+="${CPU_TOPO:+ | }cpu$run_a $tag"; else CPU_TOPO+="${CPU_TOPO:+ | }cpu$run_a-$run_b $tag"; fi
      run_a=""
    fi
    if (( i <= maxi )); then
      if [[ -z $run_a ]]; then run_a=$i; run_m=$cur; fi
      run_b=$i
    fi
  done
  return 0
}

apply_cores() {   # CORES setting -> pin this process (children inherit). Sets PIN_* ; never fatal
  local list=""
  PIN_MASK=""; PIN_N=0; PIN_LIST=""; PIN_NOTE=""
  [[ -z $ORIG_MASK ]] && ORIG_MASK=$(get_affinity 2>/dev/null)
  case $CORES in
    all) PIN_NOTE="all cores (CORES=all)"; return 0;;
    auto)
      detect_cpu
      if (( ! CPU_HETERO )) || [[ -z $BIG_LIST ]]; then
        if (( CPU_N > 0 )) && [[ $CPU_SRC != none ]]; then PIN_NOTE="all cores (all cores are equally fast)"
        else PIN_NOTE="all cores (could not tell big from little cores)"; fi
        return 0
      fi
      list=$BIG_LIST;;
    *) list=$CORES;;
  esac
  if ! find_taskset; then PIN_NOTE="all cores (taskset not found - pkg install util-linux)"; return 1; fi
  if ! mask_of_list "$list"; then PIN_NOTE="all cores (bad core list '$list')"; return 1; fi
  if set_affinity "$MASK_HEX"; then
    PIN_MASK=$MASK_HEX; PIN_N=$MASK_N; PIN_LIST=$list
    PIN_NOTE="pinned to cores $list"
    return 0
  fi
  PIN_NOTE="all cores (Android refused pinning to $list)"
  return 1
}
reapply_cores() {   # after a settings change: undo the old pin, apply the new one
  [[ -n $ORIG_MASK ]] && set_affinity "$ORIG_MASK" >/dev/null 2>&1
  apply_cores >/dev/null 2>&1
  calc_threads 1
}

read_temp() {   # TEMP_C = hottest CPU/SoC thermal sensor in C (or battery temp via Termux:API), "" if unreadable
  local z v ty cpu_best=-1 all_best=-1
  TEMP_C=""; TEMP_NOTE=""
  for z in "$VC_THERMAL"/thermal_zone*; do
    [[ -r $z/temp ]] || continue
    v=""; { read -r v < "$z/temp"; } 2>/dev/null
    [[ $v =~ ^-?[0-9]+$ ]] || continue
    if (( v > 1000 || v < -1000 )); then v=$(( v / 1000 )); fi
    (( v < 10 || v > 150 )) && continue
    ty=""; { read -r ty < "$z/type"; } 2>/dev/null; ty=${ty,,}
    case $ty in
      *bat*|*chg*|*charg*|*usb*|*modem*|*wifi*|*nand*|*flash*|*xo*|*camera*|*display*|*quiet*|*case*) continue;;
    esac
    (( v > all_best )) && all_best=$v
    case $ty in *cpu*|*soc*|*cluster*|*tsens*|*big*|*mid*|*little*|*apss*|*mtk*) (( v > cpu_best )) && cpu_best=$v;; esac
  done
  if   (( cpu_best >= 0 )); then TEMP_C=$cpu_best
  elif (( all_best >= 0 )); then TEMP_C=$all_best
  elif command -v termux-battery-status >/dev/null 2>&1; then
    v=$(timeout 3 termux-battery-status 2>/dev/null | sed -n 's/.*"temperature": *\(-\{0,1\}[0-9]*\).*/\1/p' | head -n1)
    if [[ $v =~ ^[0-9]+$ ]]; then TEMP_C=$v; TEMP_NOTE=" (battery)"; fi
  fi
}
freq_sample_start() {   # samples the clock of FREQ_CPUS once a second in the background
  local i any=0
  FREQ_FILE=""; FREQ_PID=""
  [[ -n $FREQ_CPUS ]] || return 0
  for i in $FREQ_CPUS; do [[ -r $VC_SYSFS/cpu$i/cpufreq/scaling_cur_freq ]] && any=1; done
  (( any )) || return 0
  FREQ_FILE=$(mktemp) || { FREQ_FILE=""; return 0; }
  (
    local s c m f k
    while :; do
      s=0; c=0; m=0
      for k in $FREQ_CPUS; do
        f=""; { read -r f < "$VC_SYSFS/cpu$k/cpufreq/scaling_cur_freq"; } 2>/dev/null
        [[ $f =~ ^[0-9]+$ ]] || continue
        s=$(( s + f )); c=$(( c + 1 )); if (( m == 0 || f < m )); then m=$f; fi
      done
      (( c > 0 )) && echo "$(( s / c )) $m" >> "$FREQ_FILE"
      sleep 1
    done
  ) >/dev/null 2>&1 &
  FREQ_PID=$!
}
freq_sample_stop() {   # FREQ_AVG / FREQ_MIN in MHz ("" = could not read)
  local a m n=0 sa=0 mm=0
  FREQ_AVG=""; FREQ_MIN=""
  if [[ -n $FREQ_PID ]]; then kill "$FREQ_PID" 2>/dev/null; wait "$FREQ_PID" 2>/dev/null; fi
  FREQ_PID=""
  if [[ -n $FREQ_FILE && -s $FREQ_FILE ]]; then
    while read -r a m; do
      sa=$(( sa + a )); n=$(( n + 1 )); if (( mm == 0 || m < mm )); then mm=$m; fi
    done < "$FREQ_FILE"
    if (( n > 0 )); then FREQ_AVG=$(( sa / n / 1000 )); FREQ_MIN=$(( mm / 1000 )); fi
  fi
  [[ -n $FREQ_FILE ]] && rm -f -- "$FREQ_FILE"
  FREQ_FILE=""
}
race_cpus() {   # which CPUs to watch: the pinned ones, else all
  local i
  FREQ_CPUS=""
  detect_cpu
  if [[ -n $PIN_LIST ]]; then
    local part a b; local -a parts
    IFS=',' read -ra parts <<<"$PIN_LIST"
    for part in "${parts[@]}"; do
      if [[ $part =~ ^([0-9]+)-([0-9]+)$ ]]; then a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}; else a=$part; b=$part; fi
      for (( i = a; i <= b; i++ )); do FREQ_CPUS+="$i "; done
    done
  else
    for d in "$VC_SYSFS"/cpu[0-9]*; do i=${d##*/cpu}; [[ $i =~ ^[0-9]+$ ]] && FREQ_CPUS+="$i "; done
  fi
}
device_report() {
  local sensors="" tmp
  detect_cpu
  printf '\n%s== CPU & sensors ==%s\n' "$C_B" "$C_0"
  if [[ -n $CPU_TOPO ]]; then
    printf '  Cores   : %s total\n' "$CPU_N"
    printf '            %s\n' "$CPU_TOPO"
    printf '            %s(told apart by: %s)%s\n' "$C_D" "$CPU_SRC" "$C_0"
  else
    printf '  Cores   : %s (layout could not be read - Android hides it)\n' "$CPU_N"
  fi
  if (( CPU_HETERO )); then printf '  Fast    : cores %s (%s of %s)\n' "$BIG_LIST" "$BIG_N" "$CPU_N"; fi
  printf '  Pinning : %s  [setting: %s]\n' "${PIN_NOTE:-not applied}" "$CORES"
  if (( THREADS > 0 )); then printf '  Threads : fixed at %s\n' "$THREADS"
  elif (( PIN_N > 0 )); then printf '  Threads : auto (%s = number of pinned cores)\n' "$PIN_N"
  else printf '  Threads : auto (encoder decides)\n'; fi
  read_temp
  if [[ -n $TEMP_C ]]; then sensors="temperature ${TEMP_C}°C${TEMP_NOTE}"; else sensors="temperature NOT readable"; fi
  race_cpus
  freq_sample_start
  if [[ -n $FREQ_FILE ]]; then sensors+=", CPU clock readable"; else sensors+=", CPU clock NOT readable"; fi
  freq_sample_stop
  printf '  Sensors : %s\n' "$sensors"
}
detect_ff_caps() {   # once per run (call it in the parent so parallel jobs inherit it)
  (( FF_CAPS_DONE )) && return 0
  FF_CAPS_DONE=1; STATS_OPT=(); FPSMODE_OPT=(-vsync 0); ENCTB_OPT=(); FF_VER=""
  local v maj min
  v=$(ffmpeg -version 2>/dev/null | head -n1)
  v=${v#ffmpeg version }; v=${v#[nN]}; FF_VER=${v%% *}
  if [[ $v =~ ^([0-9]+)\.([0-9]+) ]]; then
    maj=${BASH_REMATCH[1]}; min=${BASH_REMATCH[2]}
    (( maj > 4 || (maj == 4 && min >= 4) )) && STATS_OPT=(-stats_period 1)
    (( maj > 5 || (maj == 5 && min >= 1) )) && FPSMODE_OPT=(-fps_mode passthrough)
    # microsecond encoder time base: without it, millisecond timestamps (MKV/WebM, odd
    # frame rates) collide after rounding and the image muxer silently DROPS frames
    (( maj > 4 || (maj == 4 && min >= 3) )) && ENCTB_OPT=(-enc_time_base 1:1000000)
  else   # git / nightly build: assume modern
    STATS_OPT=(-stats_period 1); FPSMODE_OPT=(-fps_mode passthrough); ENCTB_OPT=(-enc_time_base 1:1000000)
  fi
}
calc_threads() {   # $1 = parallel jobs -> THREADS_PER_JOB (0 = encoder default)
  local n=${1:-1} c=0
  if (( THREADS > 0 )); then c=$THREADS                    # fixed budget from --threads / Settings 25
  elif (( PIN_N > 0 )); then c=$PIN_N                      # one thread per pinned core
  elif (( n > 1 )); then                                    # parallel jobs: split the CPU
    c=$(nproc 2>/dev/null || echo 4); [[ $c =~ ^[0-9]+$ ]] || c=4
  fi
  if (( c > 0 )); then THREADS_PER_JOB=$(( (c + n - 1) / n )); else THREADS_PER_JOB=0; fi
}
have_enc() { ffmpeg -hide_banner -encoders 2>/dev/null | grep -qw -- "$1"; }
hw_encoder_name() { case $CODEC in hw265) echo hevc_mediacodec;; hw264) echo h264_mediacodec;; esac; }
sel_size() { sum_sizes; echo "$SEL_BYTES"; }

# ----------------------------------------------------------------- presets ---
preset_desc() {
  case $1 in
    balanced) echo "H.265, CRF 26, 720p, fast encoder - best all-round (default)";;
    quality)  echo "H.265, CRF 21, original resolution - near-transparent";;
    small)    echo "H.265, CRF 30, 480p, 30 fps - small files";;
    tiny)     echo "H.265, CRF 33, 360p, 24 fps - smallest, for sharing";;
    social)   echo "H.264, 720p, 30 fps - fast, plays everywhere (chat apps)";;
    compat)   echo "H.264, CRF 23, original resolution - max compatibility";;
    fast)     echo "H.264 veryfast, 720p - quick encode for slow phones";;
    turbo)    echo "H.265 veryfast, CRF 28, 720p - fastest H.265, good quality";;
    target)   echo "H.265 two-pass, 720p, ~95 MB (change size in Settings)";;
    hardware) echo "Phone's hardware H.265 encoder - very fast, experimental";;
    av1)      echo "AV1 (SVT-AV1) - next-gen, ~30% smaller than H.265";;
    web)      echo "VP9 + Opus in WebM, 720p - websites, Chrome/Firefox";;
  esac
}
apply_preset() {
  PRESET_NAME=$1
  CODEC=x265; CRF=26; VBR=1800; SPEED=fast; HEIGHT=720; FPS=0
  AUDIO=aac; ABR=96; TARGET_MB=0
  case $1 in
    balanced) ;;
    quality)  CRF=21; SPEED=medium; HEIGHT=0; ABR=128;;
    small)    CRF=30; HEIGHT=480; FPS=30; ABR=64;;
    tiny)     CRF=33; SPEED=faster; HEIGHT=360; FPS=24; ABR=48;;
    social)   CODEC=x264; CRF=26; SPEED=veryfast; FPS=30;;
    compat)   CODEC=x264; CRF=23; SPEED=fast; HEIGHT=0; ABR=128;;
    fast)     CODEC=x264; CRF=28; SPEED=veryfast;;
    turbo)    CRF=28; SPEED=veryfast;;
    target)   TARGET_MB=95;;
    hardware) CODEC=hw265;;
    av1)      CODEC=av1; CRF=34;;
    web)      CODEC=vp9; CRF=34; SPEED=veryfast;;
    *) return 1;;
  esac
}
set_defaults() {
  apply_preset balanced
  DENOISE=0; STRIP_META=0; OUTDIR=""; SUFFIX="_compressed"
  DELETE_ORIG=0; TRIM_START=""; TRIM_END=""
  PARALLEL_JOBS=1; KEEP_SUBS=1; SUB_MODE="soft"; SUB_FILE=""
  SUB_LANG="fa"; SUB_SIZE=24; SUB_COLOR="&H00FFFFFF"
  OUT_EXT="mp4"; FINISH_ACTION="menu"
  SKIP_DONE=0; FRAME_FMT="jpg"; FRAME_Q=2; FRAME_STEP=1; FRAME_H=0; SCALER="bicubic"; CORES="all"; THREADS=0; DEINT=1; AUTOCROP=0
}

# ------------------------------------------------------ settings & profiles ---
write_settings() { local v; for v in $SETTING_VARS; do printf '%s=%q\n' "$v" "${!v}"; done > "$1"; }
save_settings()  { write_settings "$CONF"; }
load_conf()      { [[ -f $1 ]] && source "$1"; return 0; }

# ------------------------------------------------------------------ labels ---
codec_label() {
  case $CODEC in
    x265)  echo "H.265 / HEVC (libx265)";;
    x264)  echo "H.264 / AVC (libx264)";;
    av1)   echo "AV1 (SVT-AV1) - next-gen";;
    vp9)   echo "VP9 (libvpx-vp9) - WebM / web";;
    hw265) echo "H.265 hardware (MediaCodec, experimental)";;
    hw264) echo "H.264 hardware (MediaCodec, experimental)";;
  esac
}
vp9_cpu() {   # x265-style speed names -> libvpx-vp9 cpu-used (0 slowest .. 5 fastest useful)
  case $SPEED in
    veryslow) echo 0;; slower|slow) echo 1;; medium) echo 2;; fast) echo 3;;
    faster|veryfast) echo 4;; *) echo 5;;
  esac
}
svt_preset_num() {   # map x265-style speed names to SVT-AV1 preset numbers
  case $SPEED in
    ultrafast)          echo 11;;
    superfast|veryfast) echo 10;;
    faster)             echo 9;;
    fast)               echo 8;;
    medium)             echo 7;;
    slow)               echo 6;;
    slower)             echo 4;;
    veryslow)           echo 3;;
    *)                  echo 8;;
  esac
}
mode_label() {
  if (( TARGET_MB > 0 )); then echo "Target size ~${TARGET_MB} MB (two-pass)"
  elif [[ $CODEC == hw* ]]; then echo "Bitrate ${VBR} kbps"
  else echo "CRF $CRF (lower = better quality)"; fi
}
res_label()     { if (( HEIGHT > 0 )); then echo "max ${HEIGHT}p (never upscaled)"; else echo "keep original"; fi; }
fps_label()     { if (( FPS > 0 )); then echo "max $FPS fps"; else echo "keep original"; fi; }
audio_label()   { case $AUDIO in copy) echo "copy (no re-encode)";; none) echo "remove audio";; *) echo "AAC ${ABR} kbps";; esac; }
denoise_label() { case $DENOISE in 1) echo light;; 2) echo medium;; 3) echo strong;; *) echo off;; esac; }
yn_label()      { if (( $1 )); then echo yes; else echo no; fi; }
out_label()     { if [[ -n $OUTDIR ]]; then pretty "$OUTDIR"; else echo "same folder as source"; fi; }
trim_label() {
  if [[ -n $TRIM_START || -n $TRIM_END ]]; then
    local e="end"; [[ -n $TRIM_END ]] && e="${TRIM_END}s"
    echo "${TRIM_START:-0}s -> $e"
  else echo off; fi
}
sub_mode_label() {
  case $SUB_MODE in
    soft) echo "embed matching .srt (soft)";;
    burn) echo "burn .srt into the picture";;
    *) echo off;;
  esac
}
sub_style_label() {
  local col=white
  [[ $SUB_COLOR == "&H0000FFFF" ]] && col=yellow
  echo "size $SUB_SIZE, $col"
}
finish_label() {
  case $FINISH_ACTION in
    summary) echo "summary only";;
    open)    echo "summary + open first output";;
    *)       echo "results menu (open / compare)";;
  esac
}
plan_line() {
  local r="orig"; (( HEIGHT > 0 )) && r="<=${HEIGHT}p"
  local m="CRF $CRF"
  (( TARGET_MB > 0 )) && m="~${TARGET_MB}MB"
  [[ $CODEC == hw* && $TARGET_MB -eq 0 ]] && m="${VBR}k"
  echo "$CODEC | $m | $r | $(audio_label)"
}

# --------------------------------------------------------------- probing -----
probe() {   # one ffprobe call -> DUR + SRC_* (video, audio, subtitle info)
  local f=$1 line kv k v ctype codec w h rfr afr br pix trc ach dur fo
  local vdone=0 adone=0
  local -a P
  DUR=""; SRC_VCODEC=""; SRC_W=""; SRC_H=""; SRC_FPS=0; SRC_AFPS=0; SRC_VBR=""; SRC_PIX=""; SRC_TRC=""; SRC_FIELD=""
  SRC_ACODEC=""; SRC_ABR=""; SRC_ACH=0; SRC_NSUBS=0; SRC_SUBBAD=0
  [[ -f $f ]] || { err "Not a file: $f"; return 1; }
  while IFS= read -r line; do
    ctype=""; codec=""; w=""; h=""; rfr=""; afr=""; br=""; pix=""; trc=""; ach=""; dur=""; fo=""
    IFS='|' read -ra P <<<"$line"
    for kv in "${P[@]:1}"; do
      k=${kv%%=*}; v=${kv#*=}
      case $k in
        field_order)     fo=$v;;
        codec_type)      ctype=$v;;
        codec_name)      codec=$v;;
        width)           w=$v;;
        height)          h=$v;;
        r_frame_rate)    rfr=$v;;
        avg_frame_rate)  afr=$v;;
        bit_rate)        br=$v;;
        pix_fmt)         pix=$v;;
        color_transfer)  trc=$v;;
        channels)        ach=$v;;
        duration)        dur=$v;;
      esac
    done
    case ${P[0]} in
      format) DUR=$dur;;
      stream)
        case $ctype in
          video)
            if (( ! vdone )); then
              vdone=1; SRC_VCODEC=$codec; SRC_W=$w; SRC_H=$h; SRC_PIX=$pix; SRC_TRC=$trc; SRC_FIELD=$fo
              ratio_dec "$rfr" 2; SRC_FPS=$RATIO
              ratio_dec "$afr" 3; SRC_AFPS=$RATIO
              [[ $br =~ ^[0-9]+$ ]] && SRC_VBR=$(( br / 1000 ))
            fi;;
          audio)
            if (( ! adone )); then
              adone=1; SRC_ACODEC=$codec
              [[ $br =~ ^[0-9]+$ ]] && SRC_ABR=$(( br / 1000 ))
              [[ $ach =~ ^[0-9]+$ ]] && SRC_ACH=$ach
            fi;;
          subtitle)
            SRC_NSUBS=$(( SRC_NSUBS + 1 ))
            case $codec in subrip|srt|ass|ssa|mov_text|webvtt|text|stl) ;; *) SRC_SUBBAD=1;; esac;;
        esac;;
    esac
  done < <(ffprobe -v error -show_entries \
    'format=duration:stream=codec_type,codec_name,width,height,r_frame_rate,avg_frame_rate,bit_rate,pix_fmt,color_transfer,channels,field_order' \
    -of compact -- "$f" 2>/dev/null)
  [[ $DUR =~ ^[0-9]+(\.[0-9]+)?$ ]] || { err "Cannot read duration: $(basename -- "$f")"; return 1; }
  [[ -n $SRC_VCODEC ]] || { err "No video stream: $(basename -- "$f")"; return 1; }
  return 0
}

# -------------------------------------------------------- subtitle probing ---
count_subs() {   # number of subtitle streams
  ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 -- "$1" 2>/dev/null | awk 'END{print NR}'
}
sub_codecs_ok() {   # 0 = all text-based (safe to copy), 1 = bitmap subs present
  local c bad=0
  while IFS= read -r c; do
    case $c in
      subrip|srt|ass|ssa|mov_text|webvtt|text|stl) ;;
      *) bad=1;;
    esac
  done < <(ffprobe -v error -select_streams s -show_entries stream=codec_name -of csv=p=0 -- "$1" 2>/dev/null)
  return $bad
}
list_sub_streams() {   # prints "relidx codec lang" lines
  local i=0 codec lang
  while IFS=, read -r codec lang; do
    i=$(( i + 1 ))
    printf '%d %s %s\n' "$i" "${codec:-?}" "${lang:--}"
  done < <(ffprobe -v error -select_streams s -show_entries stream=codec_name:stream_tags=language -of csv=p=0 -- "$1" 2>/dev/null)
}
find_srt() {   # $1 video -> echo matching .srt path (asks if several)
  local dir base cands=() i c
  dir=$(dirname -- "$1"); base=$(basename -- "$1"); base=${base%.*}
  mapfile -t cands < <(find "$dir" -maxdepth 1 -type f \( -iname "$base.srt" -o -iname "$base.*.srt" \) -printf '%p\n' 2>/dev/null | sort)
  (( ${#cands[@]} == 0 )) && return 1
  (( ${#cands[@]} == 1 )) && { printf '%s' "${cands[0]}"; return 0; }
  echo "  Multiple subtitle files found:"
  for i in "${!cands[@]}"; do printf ' %2d) %s\n' $(( i + 1 )) "$(basename -- "${cands[i]}")"; done
  c=$(ask "Number" "1")
  if [[ $c =~ ^[0-9]+$ ]] && (( c >= 1 && c <= ${#cands[@]} )); then printf '%s' "${cands[c-1]}"; return 0; fi
  return 1
}
resolve_srt() {   # SUB_FILE (or 'auto') > find_srt > ask ; echoes path
  local p
  if [[ -n $SUB_FILE && -f $SUB_FILE ]]; then printf '%s' "$SUB_FILE"; return 0; fi
  if p=$(find_srt "$1"); then printf '%s' "$p"; return 0; fi
  warn "No .srt found next to the video."
  p=$(ask "Path to .srt (blank = cancel)" "")
  [[ -n $p && -f $p ]] && { printf '%s' "$p"; return 0; }
  return 1
}
make_sub_filter() {   # $1 size  $2 color -> subtitles filter (needs ./sub.srt in cwd)
  local f="subtitles=sub.srt" fd
  fd=$(fonts_dir)
  [[ -n $fd ]] && f+=":fontsdir=$fd"
  f+=":force_style='FontSize=$1,PrimaryColour=$2,Outline=1,Shadow=1'"
  printf '%s' "$f"
}
lang3() {   # 2-letter -> 3-letter ISO 639 code (MP4 mov_text only stores 3-letter)
  case ${1,,} in
    fa) echo fas;; en) echo eng;; ar) echo ara;; de) echo ger;; es) echo spa;;
    fr) echo fra;; it) echo ita;; pt) echo por;; ru) echo rus;; tr) echo tur;;
    hi) echo hin;; ur) echo urd;; zh) echo zho;; ja) echo jpn;; ko) echo kor;;
    id) echo ind;; ms) echo msa;; nl) echo dut;; sv) echo swe;; no) echo nor;;
    da) echo dan;; fi) echo fin;; pl) echo pol;; az) echo aze;; ku) echo kur;;
    ps) echo pus;; tg) echo tgk;; he) echo heb;; sw) echo swa;; bn) echo ben;;
    ta) echo tam;; te) echo tel;; th) echo tha;; vi) echo vie;; el) echo gre;;
    uk) echo ukr;; ro) echo rum;; hu) echo hun;; sr) echo srp;; bg) echo bul;;
    hr) echo hrv;; sq) echo alb;; mk) echo mkd;; lt) echo lit;; lv) echo lav;;
    et) echo est;; sk) echo slk;; sl) echo slv;; ka) echo kat;; hy) echo hye;;
    am) echo amh;; ne) echo nep;; si) echo sin;; my) echo mya;; km) echo khm;;
    lo) echo lao;; ml) echo mal;; kn) echo kan;; mr) echo mar;; gu) echo guj;;
    pa) echo pan;; uz) echo uzb;; kk) echo kaz;; ky) echo kir;; tk) echo tuk;;
    *) printf '%s' "$1";;
  esac
}
setup_burn() {   # $1 src ; sets SUBFILTER (needs TMPD) ; 0 = burning subtitles
  SUBFILTER=""
  [[ $SUB_MODE == burn ]] || return 1
  local srt=""
  if [[ -n $SUB_FILE && -f $SUB_FILE ]]; then srt=$SUB_FILE
  else srt=$(find_srt "$1" 2>/dev/null) || srt=""; fi
  if [[ -z $srt ]]; then warn "No matching .srt found - subtitles skipped."; return 1; fi
  cp -f -- "$srt" "$TMPD/sub.srt" || return 1
  if awk -v s="${TRIM_START:-0}" 'BEGIN{ exit !(s+0 > 0) }'; then
    shift_srt "$TMPD/sub.srt" "$TMPD/sub2.srt" "${TRIM_START:-0}" && mv -f "$TMPD/sub2.srt" "$TMPD/sub.srt" \
      && info "Subtitles re-timed to match the trim start."
  fi
  SUBFILTER=$(make_sub_filter "$SUB_SIZE" "$SUB_COLOR")
  info "Burning subtitles: $(basename -- "$srt")"
  return 0
}
shift_srt() {   # $1 in.srt  $2 out.srt  $3 seconds-to-subtract (drops cues that end before 0)
  awk -v sh="$3" '
    function ms(t,  a, b) { split(t, a, ","); split(a[1], b, ":"); return (((b[1]*60+b[2])*60+b[3])*1000) + (a[2]+0) }
    function fmt(v,  h, m, s, x) { if (v < 0) v = 0; h = int(v/3600000); m = int((v%3600000)/60000); s = int((v%60000)/1000); x = v%1000; return sprintf("%02d:%02d:%02d,%03d", h, m, s, x) }
    /^$/ { if (hold) { if (!drop) printf "%s", out; hold = 0; out = ""; drop = 0 } print ""; next }
    /^[0-9]+$/ { hold = 1; out = $0 "\n"; next }
    / --> / {
      if (!hold) { hold = 1; out = "" }
      split($0, p, " --> ")
      e = ms(p[2]) - sh*1000
      if (e <= 0) { drop = 1; next }
      out = out fmt(ms(p[1]) - sh*1000) " --> " fmt(e) "\n"; next
    }
    { if (hold) out = out $0 "\n"; else print }
    END { if (hold && !drop) printf "%s", out }
  ' "$1" > "$2" || { rm -f -- "$2"; return 1; }
  return 0
}

calc_edur() {   # sets EDUR + IN_OPTS from DUR and trim settings
  IN_OPTS=()
  EDUR=$(awk -v d="$DUR" -v s="${TRIM_START:-0}" -v e="${TRIM_END:-0}" \
    'BEGIN{ if (e>0 && e<d) d=e; d-=s; if (d<0) d=0; printf "%.3f", d }')
  awk -v d="$EDUR" 'BEGIN{ exit !(d>=0.2) }' || return 1
  if [[ -n $TRIM_START || -n $TRIM_END ]]; then IN_OPTS=(-ss "${TRIM_START:-0}" -t "$EDUR"); fi
  return 0
}

calc_bitrate() {   # video kbps needed to hit TARGET_MB (decimal MB, 3% safety margin)
  local a=0
  audio_plan
  case $AUDIO in
    aac)  if (( AUD_COPY )); then a=$SRC_ABR; else a=$ABR; fi;;
    copy) a=${SRC_ABR:-128};;
    none) a=0;;
  esac
  awk -v mb="$TARGET_MB" -v d="$EDUR" -v a="$a" \
    'BEGIN{ v = mb*8000*0.97/d - a; if (v < 40) exit 1; printf "%d", v }'
}
audio_plan() {   # AUD_COPY=1 when the source audio is already the target codec at/below the target bitrate
  AUD_COPY=0
  [[ $AUDIO == aac ]] || return 0
  case $AENC_NAME in
    libopus)    [[ $SRC_ACODEC == opus ]] || return 0;;
    libmp3lame) [[ $SRC_ACODEC == mp3 ]]  || return 0;;
    *)          [[ $SRC_ACODEC == aac ]]  || return 0;;
  esac
  [[ $SRC_ABR =~ ^[0-9]+$ ]] && (( SRC_ABR > 0 && SRC_ABR <= ABR )) || return 0
  if (( ABR <= 48 )); then (( SRC_ACH == 1 )) || return 0
  else (( SRC_ACH >= 1 && SRC_ACH <= 2 )) || return 0; fi
  AUD_COPY=1
}

# ============================ repair diagnostics (v2.1) ======================
# Deep checks for the classic "plays fine in VLC, drifts on the TV" problems:
# variable frame rate (VFR), odd audio sample rates, A/V start offsets,
# TV-unsafe codecs and missing faststart.

num_or0() { [[ $1 =~ ^-?[0-9]+(\.[0-9]+)?$ ]] && printf '%s' "$1" || echo 0; }

frac2dec() {   # "30000/1001" | "29.97" -> decimal number
  awk -v r="$1" 'BEGIN{
    n = split(r, a, "/")
    if (n == 2 && a[2] + 0 != 0) printf "%.4f", a[1] / a[2]
    else if (r ~ /^[0-9]*\.?[0-9]+$/) printf "%.4f", r + 0
    else print "0" }'
}

_diag_probe_run() {   # $1 file  $2 extra ffprobe flags (split on purpose)
  local f=$1 extra=$2 line kv k v ctype codec w h pix rfr afr st tb sr ch dur fmt ctime trc fo
  local vdone=0 adone=0
  local -a P
  D_VCODEC=""; D_W=0; D_H=0; D_PIX=""; D_RFPS=""; D_AFPS=""; D_VSTART=""; D_VTB=""
  D_ACODEC=""; D_ARATE=0; D_ACH=0; D_ASTART=""; D_ANUM=0; D_DUR=0; D_FMT=""; D_VTS=0
  D_CTIME=""; D_TRC=""; D_NSUBS=0; D_VDUR=""; D_ADUR=""; D_FIELD=""
  while IFS= read -r line; do
    ctype=""; codec=""; w=""; h=""; pix=""; rfr=""; afr=""; st=""; tb=""; sr=""; ch=""; dur=""; fmt=""; ctime=""; trc=""; fo=""
    IFS='|' read -ra P <<<"$line"
    for kv in "${P[@]:1}"; do
      k=${kv%%=*}; v=${kv#*=}
      case $k in
        codec_type)         ctype=$v;;
        codec_name)         codec=$v;;
        width)              w=$v;;
        height)             h=$v;;
        pix_fmt)            pix=$v;;
        r_frame_rate)       rfr=$v;;
        avg_frame_rate)     afr=$v;;
        start_time)         st=$v;;
        time_base)          tb=$v;;
        sample_rate)        sr=$v;;
        channels)           ch=$v;;
        duration)           dur=$v;;
        format_name)        fmt=$v;;
        color_transfer)     trc=$v;;
        field_order)        fo=$v;;
        tag:creation_time)  ctime=$v;;
      esac
    done
    case ${P[0]} in
      format) D_DUR=$dur; D_FMT=$fmt; D_CTIME=$ctime;;
      stream)
        case $ctype in
          video)
            if (( ! vdone )); then
              vdone=1; D_VCODEC=$codec; D_W=$w; D_H=$h; D_PIX=$pix; D_RFPS=$rfr; D_AFPS=$afr; D_VSTART=$st; D_VTB=$tb
              D_TRC=$trc; D_VDUR=$dur; D_FIELD=$fo
            fi;;
          audio)
            D_ANUM=$(( D_ANUM + 1 ))
            if (( ! adone )); then
              adone=1; D_ACODEC=$codec; D_ARATE=$sr; D_ACH=$ch; D_ASTART=$st; D_ADUR=$dur
            fi;;
          subtitle) D_NSUBS=$(( D_NSUBS + 1 ));;
        esac;;
    esac
  done < <(ffprobe -v error $extra -show_entries \
    'format=duration,format_name:format_tags=creation_time:stream=codec_type,codec_name,width,height,pix_fmt,r_frame_rate,avg_frame_rate,start_time,time_base,sample_rate,channels,color_transfer,duration,field_order' \
    -of compact -- "$f" 2>/dev/null)
}
diag_probe() {   # $1 file -> D_* fields; fails when there is no video stream (damaged headers get a bigger probe)
  local f=$1
  [[ -f $f ]] || return 1
  _diag_probe_run "$f" ""
  [[ -n $D_VCODEC ]] || _diag_probe_run "$f" "-analyzeduration 200M -probesize 200M"
  [[ -n $D_VCODEC ]] || return 1
  case $D_VCODEC in mjpeg|jpegls|png|bmp|tiff) return 1;; esac
  [[ $D_W =~ ^[0-9]+$ ]] || D_W=0
  [[ $D_H =~ ^[0-9]+$ ]] || D_H=0
  [[ $D_ARATE =~ ^[0-9]+$ ]] || D_ARATE=0
  [[ $D_ACH =~ ^[0-9]+$ ]] || D_ACH=0
  [[ $D_VDUR =~ ^[0-9]+(\.[0-9]+)?$ ]] || D_VDUR=""
  [[ $D_ADUR =~ ^[0-9]+(\.[0-9]+)?$ ]] || D_ADUR=""
  if [[ $D_VTB == */* && ${D_VTB#*/} =~ ^[0-9]+$ ]]; then D_VTS=${D_VTB#*/}; fi
  [[ $D_DUR =~ ^[0-9]+(\.[0-9]+)?$ ]] || D_DUR=0
  D_FMT=${D_FMT%%,*}; D_FMT=${D_FMT//\"/}
  return 0
}

diag_vfr_scan() {   # $1 file -> D_VFR D_FPSMED D_VFRBAD D_VFRDUP D_VFRN D_ROUND D_TSX
  # Samples three sections of the file (start / middle / near the end) so
  # timing problems hiding deep inside a movie are found too. Finds:
  #   D_VFR=1   variable frame rate (frames at genuinely uneven intervals)
  #   D_ROUND=1 constant rate but timestamps snapped to coarse ticks (e.g.
  #             whole milliseconds) - the classic GRADUAL-drift-on-TV cause
  #   D_TSX     1 = every sampled frame duration identical (exact timing),
  #             0 = not uniform, -1 = unknown (container has no durations)
  local f=$1 out iv all=""
  D_VFR=0; D_FPSMED=0; D_VFRBAD=0; D_VFRDUP=0; D_VFRN=0; D_ROUND=0; D_TSX=-1
  local -a ivs=("%+#300")
  if (( $(awk -v d="${D_DUR:-0}" 'BEGIN{print (d+0 > 25) ? 1 : 0}') )); then
    ivs+=("$(awk -v d="${D_DUR:-0}" 'BEGIN{printf "%.0f%%+#300", d/2}')" \
          "$(awk -v d="${D_DUR:-0}" 'BEGIN{printf "%.0f%%+#300", d*0.9}')")
  fi
  # the sections are independent, so they are scanned at the same time
  local td j=0 pid; local -a pids=()
  td=$(mktemp -d) || td=""
  if [[ -n $td ]]; then
    for iv in "${ivs[@]}"; do
      ffprobe -v error -select_streams v:0 -read_intervals "$iv" \
        -show_entries packet=pts_time,duration -of csv=p=0 -- "$f" >"$td/$j" 2>/dev/null &
      pids+=($!); j=$(( j + 1 ))
    done
    for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null; done
    for (( iv = 0; iv < j; iv++ )); do all+=$'\n'$(<"$td/$iv"); done
    rm -rf -- "$td"
  fi
  out=$(printf '%s' "$all" | awk -F, '
    BEGIN { vfr=0; fps=0; bad=0; dup=0; n1=0; rnd=0; tsx=-1 }
    $1 ~ /^[0-9]+(\.[0-9]+)?$/ { p[np++] = $1 + 0 }
    $2 ~ /^[0-9]+$/ && $2 + 0 > 0 { d[nd++] = $2 + 0 }
    END {
      if (np >= 12) {
        m = np - 1
        for (i = 0; i < m; i++) for (j = i + 1; j < np; j++) if (p[j] < p[i]) { t = p[i]; p[i] = p[j]; p[j] = t }
        for (i = 0; i < m; i++) { dd[i] = p[i+1] - p[i]; s[i] = dd[i] }
        for (i = 0; i < m; i++) for (j = i + 1; j < m; j++) if (s[j] < s[i]) { t = s[i]; s[i] = s[j]; s[j] = t }
        med = s[int(m/2)]
        if (med > 0) {
          bad = 0; dup = 0
          for (i = 0; i < m; i++) {
            r = dd[i] / med
            if (r < 0.25) dup++
            else if (r < 0.98 || r > 1.02) bad++
          }
          vfr = ((bad > m/50) || dup > 0) ? 1 : 0
          fps = 1/med; n1 = np
        }
      }
      if (nd >= 10) {
        for (i = 0; i < nd; i++) for (j = i + 1; j < nd; j++) if (d[j] < d[i]) { t = d[i]; d[i] = d[j]; d[j] = t }
        dmed = d[int(nd/2)]
        if (dmed > 0) {
          u = 0; prev = -1
          for (i = 0; i < nd; i++) if (d[i] != prev) { u++; prev = d[i] }
          tsx = (u == 1) ? 1 : 0
          # constant rate but only 2-3 nearly-equal tick values -> rounded
          if (tsx == 0 && u <= 3 && (d[nd-1] - d[0]) / dmed < 0.06) rnd = 1
        }
      }
      printf "%d %.6f %d %d %d %d %d\n", vfr, fps, bad, dup, n1, rnd, tsx
    }')
  [[ -n $out ]] && read -r D_VFR D_FPSMED D_VFRBAD D_VFRDUP D_VFRN D_ROUND D_TSX <<<"$out"
  return 0
}

diag_faststart() {   # $1 file -> D_FAST: 1 = faststart, 0 = moov at end, -1 = n/a
  D_FAST=-1
  local f=$1 line off name mo="" mdat=""
  case ${f##*.} in
    mp4|MP4|m4v|M4V|mov|MOV|3gp|3GP|3g2|3G2) ;;
    *) return 0;;
  esac
  # 'moov' before 'mdat' = faststart. One pass over the first 2 MB finds both
  # atoms in file order (small files: the ORDER matters, not just presence).
  while IFS=: read -r off name; do
    case $name in
      moov) [[ -n $mo ]]   || mo=$off;;
      mdat) [[ -n $mdat ]] || mdat=$off;;
    esac
    [[ -n $mo && -n $mdat ]] && break
  done < <(LC_ALL=C head -c 2097152 -- "$f" 2>/dev/null | LC_ALL=C grep -abo -e moov -e mdat 2>/dev/null)
  if [[ -n $mo ]]; then
    if [[ -z $mdat ]] || (( mo < mdat )); then D_FAST=1; else D_FAST=0; fi
  else
    D_FAST=0
  fi
}

snap_fps() {   # $1 detected fps -> "<fps-filter arg> <display>" (NTSC as exact fractions)
  awk -v f="$1" 'BEGIN{
    split("23.976 24 25 29.97 30 48 50 59.94 60 15", vals, " ")
    split("24000/1001 24 25 30000/1001 30 48 50 60000/1001 60 15", args, " ")
    best = 1; bd = f - vals[1]; if (bd < 0) bd = -bd
    for (i = 2; i <= 10; i++) { d = f - vals[i]; if (d < 0) d = -d; if (d < bd) { bd = d; best = i } }
    if (bd / vals[best] <= 0.03) printf "%s %.3f", args[best], vals[best]
    else printf "%.3f %.3f", f, f }'
}

diag_report() {   # $1 file -> human-readable sync / TV-compatibility report
  local f=$1 vst ast aoff ms offword i=0
  local -a probs=()
  DIAG_NPROBS=-1; DIAG_PROBS=()
  diag_probe "$f" || { err "No video stream (damaged or not a video): $(basename -- "$f")"; return 1; }
  diag_vfr_scan "$f"; diag_faststart "$f"
  vst=$(num_or0 "$D_VSTART"); ast=$(num_or0 "$D_ASTART")
  printf '\n%s== Diagnosis: %s ==%s\n' "$C_B" "$(basename -- "$f")" "$C_0"
  printf '  File       : %s, %s, %s\n' "${D_FMT:-?}" "$(fmt_time "$D_DUR")" "$(human "$(fsize "$f")")"
  printf '  Video      : %sx%s %s %s, %s fps, 1/%s time base\n' "$D_W" "$D_H" "$D_VCODEC" "$D_PIX" "$(frac2dec "$D_RFPS")" "$( (( D_VTS > 0 )) && echo "$D_VTS" || echo "?" )"
  if (( D_ROUND )); then
    probs+=("rounded video timestamps - the No.1 cause of GRADUAL audio drift on TVs")
    printf '  Timing     : %srounded timestamps%s (frame times snapped to coarse 1/%s ticks)\n' \
      "$C_Y" "$C_0" "$( (( D_VTS > 0 )) && echo "$D_VTS" || echo "?" )"
  elif (( D_VFR )); then
    probs+=("variable frame rate (VFR) - causes stutter and drift on TVs")
    printf '  Timing     : %svariable frame rate%s (%d of %d frames uneven, %d dup, median %.2f fps)\n' \
      "$C_Y" "$C_0" "$D_VFRBAD" "$D_VFRN" "$D_VFRDUP" "$D_FPSMED"
  else
    printf '  Timing     : constant frame rate, exact timestamps%s (ok)%s\n' "$C_D" "$C_0"
  fi
  if (( D_ANUM > 0 )); then
    printf '  Audio      : %s %s Hz, %s ch, starts at %s s\n' "${D_ACODEC:-?}" "$D_ARATE" "$D_ACH" "$ast"
    case $D_ACODEC in aac|ac3|eac3) ;; *) probs+=("audio codec '$D_ACODEC' - not reliably playable on TV/USB players");; esac
    [[ $D_ARATE == 48000 ]] || probs+=("audio sample rate ${D_ARATE} Hz - non-48k audio drifts on some players")
  else
    printf '  Audio      : (none)\n'
  fi
  aoff=$(awk -v a="$ast" -v v="$vst" 'BEGIN{ printf "%.3f", a - v }')
  if awk -v x="$aoff" 'BEGIN{ x = (x < 0) ? -x : x; exit !(x > 0.04) }'; then
    ms=$(awk -v x="$aoff" 'BEGIN{ printf "%d", x * 1000 }')
    offword=$(awk -v x="$aoff" 'BEGIN{ print (x > 0) ? "late" : "early" }')
    probs+=("audio starts ${ms#-} ms $offword relative to the video (constant offset)")
    printf '  A/V start  : video %s s, audio %s s -> %saudio starts %s ms %s%s\n' \
      "$vst" "$ast" "$C_Y" "${ms#-}" "$offword" "$C_0"
  else
    printf '  A/V start  : aligned (video %s s, audio %s s)\n' "$vst" "$ast"
  fi
  [[ $D_VCODEC != h264 ]] && probs+=("video codec '$D_VCODEC' - old TVs want H.264")
  [[ $D_PIX != yuv420p ]] && probs+=("pixel format '$D_PIX' - old TVs want 8-bit yuv420p")
  case $D_FAST in
    1)  printf '  MP4 index  : faststart (ok)\n';;
    0)  probs+=("MP4 index (moov) at the end - slow or broken start on TV/USB players")
        printf '  MP4 index  : %smoov at the end (no faststart)%s\n' "$C_Y" "$C_0";;
    *)  printf '  MP4 index  : (not an MP4-family file)\n';;
  esac
  if (( ${#probs[@]} )); then
    printf '\n  %s! Problems found (%d):%s\n' "$C_Y" "${#probs[@]}" "$C_0"
    for p in "${probs[@]}"; do i=$(( i + 1 )); printf '    %d. %s\n' "$i" "$p"; done
    printf '\n  %s-> Fix them with:  vc --repair %s%s\n' "$C_G" "$(basename -- "$f")" "$C_0"
  else
    printf '\n  %sNo sync problems found - should play fine on any device.%s\n' "$C_G" "$C_0"
  fi
  DIAG_NPROBS=${#probs[@]}; DIAG_PROBS=("${probs[@]}")
  return 0
}

# ----------------------------------------------------- ffmpeg arg builders ---
build_vf() {
  local f=() sf=""
  [[ $SCALER == lanczos ]] && sf=":flags=lanczos"
  # interlaced sources (DVD, TV recordings): remove the comb lines first
  case $SRC_FIELD in tt|bb|tb|bt) (( DEINT )) && f+=("yadif=mode=0:parity=-1:deint=1");; esac
  [[ -n $CROP_VF ]] && f+=("$CROP_VF")
  # frame-rate limit FIRST: dropped frames are never scaled or denoised
  if (( FPS > 0 )) && awk -v s="$SRC_FPS" -v t="$FPS" 'BEGIN{ exit !(s > t+0.5) }'; then
    f+=("fps=$FPS")
  fi
  if (( HEIGHT > 0 )); then
    f+=("scale='if(gt(iw,ih),-2,min($HEIGHT,iw))':'if(gt(iw,ih),min($HEIGHT,ih),-2)'$sf")
  fi
  case $DENOISE in
    1) f+=("hqdn3d=1.5:1.5:6:6");;
    2) f+=("hqdn3d=3:2.5:8:7");;
    3) f+=("hqdn3d=4:3:10:8");;
  esac
  (IFS=,; printf '%s' "${f[*]}")
}
build_venc() {   # $1 = single|p1|p2   $2 = video kbps (empty = CRF mode)
  local pass=$1 br=$2 xp="log-level=error" th=""
  VENC=()
  (( THREADS_PER_JOB > 0 )) && th=$THREADS_PER_JOB
  case $CODEC in
    x265)
      VENC+=(-c:v libx265 -preset "$SPEED" -pix_fmt yuv420p)
      (( CT_HVC )) && VENC+=(-tag:v hvc1)
      if [[ -n $br ]]; then VENC+=(-b:v "${br}k"); else VENC+=(-crf "$CRF"); fi
      case $pass in
        p1) xp+=":pass=1:stats=$TMPD/x265.stats";;
        p2) xp+=":pass=2:stats=$TMPD/x265.stats";;
      esac
      [[ -n $th ]] && xp+=":pools=$th"
      VENC+=(-x265-params "$xp");;
    x264)
      VENC+=(-c:v libx264 -preset "$SPEED" -pix_fmt yuv420p)
      [[ -n $th ]] && VENC+=(-threads "$th")
      [[ $OUT_EXT == avi ]] && VENC+=(-bf 0)
      if [[ -n $br ]]; then VENC+=(-b:v "${br}k"); else VENC+=(-crf "$CRF"); fi
      case $pass in
        p1) VENC+=(-pass 1 -passlogfile "$TMPD/x264");;
        p2) VENC+=(-pass 2 -passlogfile "$TMPD/x264");;
      esac;;
    av1)
      VENC+=(-c:v libsvtav1 -preset "$(svt_preset_num)" -pix_fmt yuv420p)
      [[ -n $th ]] && VENC+=(-threads "$th")
      if [[ -n $br ]]; then VENC+=(-b:v "${br}k"); else VENC+=(-crf "$CRF"); fi;;
    vp9)
      VENC+=(-c:v libvpx-vp9 -pix_fmt yuv420p -row-mt 1 -tile-columns 2 -deadline good -cpu-used "$(vp9_cpu)" -threads "${th:-$(nproc 2>/dev/null || echo 4)}")
      if [[ -n $br ]]; then VENC+=(-b:v "${br}k"); else VENC+=(-b:v 0 -crf "$CRF"); fi
      case $pass in
        p1) VENC+=(-pass 1 -passlogfile "$TMPD/vp9");;
        p2) VENC+=(-pass 2 -passlogfile "$TMPD/vp9");;
      esac;;
    hw265) VENC+=(-c:v hevc_mediacodec -b:v "${br:-$VBR}k")
           (( CT_HVC )) && VENC+=(-tag:v hvc1);;
    hw264) VENC+=(-c:v h264_mediacodec -b:v "${br:-$VBR}k");;
  esac
}
build_aenc() {
  audio_plan
  local ac=2; (( ABR <= 48 )) && ac=1
  case $AUDIO in
    none) AENC=(-an);;
    copy) if acodec_ok "$SRC_ACODEC"; then AENC=(-c:a copy)
          else
            case $AENC_NAME in libopus) AENC=(-c:a libopus -b:a "${ABR}k" -vbr on);; libmp3lame) AENC=(-c:a libmp3lame -b:a "${ABR}k");; *) AENC=(-c:a aac -b:a "${ABR}k");; esac
          fi;;
    *)    if (( AUD_COPY )); then
            AENC=(-c:a copy)
          else
            case $AENC_NAME in
              libopus)    AENC=(-c:a libopus -b:a "${ABR}k" -ac "$ac" -vbr on);;
              libmp3lame) AENC=(-c:a libmp3lame -b:a "${ABR}k" -ac "$ac");;
              *)          AENC=(-c:a aac -b:a "${ABR}k" -ac "$ac");;
            esac
          fi;;
  esac
}
acodec_ok() {   # can this source audio codec be copied into the chosen container? (empty = no audio = fine)
  [[ -n $1 ]] || return 0
  case $OUT_EXT in
    mkv)  return 0;;
    webm) [[ $1 == opus || $1 == vorbis ]];;
    avi)  case $1 in mp3|aac|ac3|pcm_s16le) return 0;; *) return 1;; esac;;
    ts)   case $1 in aac|ac3|eac3|mp2|mp3) return 0;; *) return 1;; esac;;
    *)    case $1 in aac|mp3|ac3|eac3|alac|opus) return 0;; *) return 1;; esac;;
  esac
}

# --------------------------------------------------- progress-bar runner -----
# run_ffmpeg LABEL PASS_INDEX PASS_TOTAL <ffmpeg args...>
run_ffmpeg() {   # run_ffmpeg LABEL PASS_INDEX PASS_TOTAL <ffmpeg args...>
  local label=$1 pi=$2 pt=$3 rc w edur_us
  shift 3
  mkdir -p "$CONF_DIR" 2>/dev/null
  detect_ff_caps
  if (( SIMPLE )); then
    ffmpeg -nostdin -hide_banner -loglevel error -y "$@" 2>>"${LOGF:-$LOG}"
    return $?
  fi
  [[ -n $TERM_COLS ]] || refresh_cols
  w=$(( TERM_COLS - 34 )); (( w < 8 )) && w=8; (( w > 28 )) && w=28
  secs_us "${EDUR:-0}"; edur_us=$SECS_US; (( edur_us < 1 )) && edur_us=1
  ffmpeg -nostdin -hide_banner -loglevel error -progress pipe:1 -nostats "${STATS_OPT[@]}" -y "$@" 2>>"${LOGF:-$LOG}" |
  {
    # pure-bash progress: no awk / sub-shell is started for any update
    local cur=0 spd=0 key val pct eta fr tot rem es sp="" filled b1 b2 f3
    while IFS='=' read -r key val; do
      case $key in
        out_time_us|out_time_ms) [[ $val =~ ^[0-9]+$ ]] && cur=$val;;
        speed)
          val=${val//[x ]/}
          if [[ $val =~ ^([0-9]+)(\.([0-9]+))?$ ]]; then
            f3=${BASH_REMATCH[3]}000; spd=$(( 10#${BASH_REMATCH[1]} * 1000 + 10#${f3:0:3} )); sp="${val}x"
          else spd=0; sp=""; fi;;
        progress)
          (( cur > edur_us )) && cur=$edur_us
          tot=$(( pt * edur_us ))
          pct=$(( ((pi - 1) * edur_us + cur) * 100 / tot ))
          if (( spd > 0 )); then
            rem=$(( (pt - pi) * edur_us + edur_us - cur ))
            es=$(( rem / (spd * 1000) ))
            printf -v eta '%02d:%02d:%02d' $(( es / 3600 )) $(( es % 3600 / 60 )) $(( es % 60 ))
          else eta='--:--:--'; fi
          filled=$(( pct * w / 100 ))
          printf -v b1 '%*s' "$filled" ''; printf -v b2 '%*s' "$(( w - filled ))" ''
          printf '\r\033[K%s[%s%s] %3d%% %s ETA %s' "${label:+$label }" "${b1// /#}" "${b2// /.}" "$pct" "${sp:---}" "$eta"
          ;;
      esac
    done
  }
  rc=${PIPESTATUS[0]}
  printf '\r\033[K'
  return "$rc"
}

# -------------------------------------------------------------- file naming ---
unique_file() {   # dir base ext -> unique path
  local dir=$1 base=$2 ext=$3 out n=0
  mkdir -p -- "$dir" 2>/dev/null
  out="$dir/$base.$ext"
  while [[ -e $out ]]; do n=$(( n + 1 )); out="$dir/${base}_$n.$ext"; done
  printf '%s' "$out"
}
unique_out() {
  local src=$1 dir base
  dir=${OUTDIR:-$(dirname -- "$src")}
  base=$(basename -- "$src"); base=${base%.*}
  unique_file "$dir" "${base}${SUFFIX}" "$OUT_EXT"
}
add_result() {   # name in out saved time status src dst
  local line
  line=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' "$@")
  RESULTS+=("$line")
  [[ -n $RESULT_FILE ]] && printf '%s\n' "$line" >> "$RESULT_FILE"
}
tally() {   # ok|fail|skip  in_sz  out_sz   (parallel-safe via STATS file)
  case $1 in
    ok)   N_OK=$(( N_OK + 1 )); TOTAL_IN=$(( TOTAL_IN + ${2:-0} )); TOTAL_OUT=$(( TOTAL_OUT + ${3:-0} ));;
    fail) N_FAIL=$(( N_FAIL + 1 ));;
  esac
  [[ -n $STATS ]] && printf '%s %s %s\n' "$1" "${2:-0}" "${3:-0}" >> "$STATS"
}

# --------------------------------------------------------- output staging ---
# Android shared storage (/storage/emulated/0) is a FUSE mount: ffmpeg's
# +faststart trailer step re-opens the finished file to move the MP4 index
# to the front, and on that bridge it dies with "Unable to re-open ... output
# file for shifting data" after long encodes - hours of work lost at the very
# last second. So every MP4 is BUILT on fast local storage first and moved to
# the destination in one sequential pass: faststart always works, encoding
# writes stay on the fast filesystem, and no half-written files (or .part
# leftovers that download managers love to grab) ever appear in your folders.
stage_root() {   # pick a local-fast build directory (once per run)
  [[ -n $STAGE_ROOT && -d $STAGE_ROOT ]] && return 0
  local -a try=()
  [[ -n $TMPDIR && -d $TMPDIR ]] && try+=("$TMPDIR")
  [[ -n $PREFIX && -d $PREFIX/tmp ]] && try+=("$PREFIX/tmp")
  [[ -d /data/data/com.termux/files/usr/tmp ]] && try+=("/data/data/com.termux/files/usr/tmp")
  [[ -d /tmp && -w /tmp ]] && try+=("/tmp")
  try+=("$HOME/.vc-tmp")
  local d
  STAGE_ROOT=""
  for d in "${try[@]}"; do
    [[ -d $d && -w $d ]] || continue
    STAGE_ROOT=$(mktemp -d "$d/vc.XXXXXX" 2>/dev/null) && return 0
  done
  return 1
}
stage_free() {   # bytes free on the staging filesystem (0 = unknown)
  [[ -n $STAGE_ROOT ]] || { echo 0; return; }
  df -Pk "$STAGE_ROOT" 2>/dev/null | awk 'NR==2{printf "%d", $4*1024}'
}
out_tmp() {   # $1 final path, $2 approx bytes needed -> sets OT_TMP, OT_DIRECT
  OT_TMP=""; OT_DIRECT=0
  local fin=$1 need=${2:-0} free
  [[ $fin == /* ]] || fin="$PWD/$fin"
  if [[ -z $VC_NOSTAGE ]] && stage_root; then
    free=$(stage_free)
    if (( need <= 0 )) || (( free > need + 52428800 )) || (( free > 268435456 )); then
      OT_TMP=$(mktemp "${STAGE_ROOT%/}/$(basename -- "$fin").XXXXXX" 2>/dev/null) && return 0
    fi
  fi
  # last resort: build right next to the destination, without faststart
  OT_DIRECT=1; OT_TMP="$fin.vcpart"
  if (( STAGE_WARNED++ == 0 )); then
    warn "No local staging space - writing next to the destination without faststart."
    warn "Free some space inside Termux (\$HOME) to switch the safe fast path on."
  fi
}
commit_out() {   # $1 built tmp, $2 final path -> 0 = the file is in place
  local src=$1 dst=$2 sz dev1 dev2 copid p rc
  [[ -s $src ]] || return 1
  sz=$(fsize "$src")
  mkdir -p -- "$(dirname -- "$dst")" 2>/dev/null
  dev1=$(stat -c %d -- "$src" 2>/dev/null) || dev1=??
  dev2=$(stat -c %d -- "$(dirname -- "$dst")" 2>/dev/null) || dev2=??
  if [[ $dev1 == "$dev2" ]] || (( sz < 52428800 )); then
    if mv -f -- "$src" "$dst" 2>/dev/null && [[ -s $dst ]]; then return 0; fi
    rm -f -- "$dst" 2>/dev/null
  fi
  # big file onto a different filesystem (e.g. Termux -> /storage/emulated):
  # copy with a progress display, then drop the staged original
  if (( SIMPLE )); then
    if cp -f -- "$src" "$dst" && rm -f -- "$src" && [[ -s $dst ]]; then return 0; fi
    rm -f -- "$dst" 2>/dev/null; return 1
  fi
  printf '\n'
  info "Moving $(human "$sz") to $(pretty "$(dirname -- "$dst")") ..."
  cp -f -- "$src" "$dst.vcmove" & copid=$!
  while kill -0 "$copid" 2>/dev/null; do
    p=$(fsize "$dst.vcmove"); (( sz > 0 )) && p=$(( p * 100 / sz )) || p=0
    (( p > 100 )) && p=100
    printf '\r  %3d%%' "$p"
    sleep 0.4
  done
  wait "$copid"; rc=$?
  printf '\r\033[K'
  if (( rc != 0 )) || ! mv -f -- "$dst.vcmove" "$dst" 2>/dev/null; then
    rm -f -- "$dst.vcmove" 2>/dev/null; return 1
  fi
  rm -f -- "$src"
  [[ -s $dst ]] && return 0
  return 1
}

# ------------------------------------------------------- compress one file ---

container_rules() {   # sets CT_* for OUT_EXT and nudges CODEC/OUT_EXT when they cannot go together (call inside compress_file: CODEC/OUT_EXT are local there)
  AENC_NAME=aac; CT_SUBS=mov_text; CT_FMT=mp4; CT_FAST=1; CT_STAGE=1; CT_HVC=1
  if [[ $CODEC == vp9 ]] && [[ $OUT_EXT == mp4 || $OUT_EXT == mov || $OUT_EXT == avi || $OUT_EXT == ts ]]; then
    [[ $PRESET_NAME == web ]] || warn "VP9 belongs in WebM (or MKV) - writing WebM for this file."; OUT_EXT=webm
  fi
  case $OUT_EXT in
    mp4) ;;
    mov) CT_FMT=mov;;
    mkv) CT_FMT=matroska; CT_SUBS=srt; CT_FAST=0; CT_STAGE=0; CT_HVC=0;;
    webm)
      CT_FMT=webm; CT_SUBS=webvtt; CT_FAST=0; CT_STAGE=0; CT_HVC=0; AENC_NAME=libopus
      case $CODEC in
        vp9|av1) ;;
        x265) warn "WebM holds VP9/AV1 only - using VP9 for this file."; CODEC=vp9; CRF=$(( CRF + 7 )); SPEED=${SPEED/ultrafast/veryfast};;
        x264) warn "WebM holds VP9/AV1 only - using VP9 for this file."; CODEC=vp9; CRF=$(( CRF + 8 ));;
        *)    warn "WebM holds VP9/AV1 only - using VP9 for this file."; CODEC=vp9; CRF=34;;
      esac
      (( CRF > 63 )) && CRF=63
      have_enc libopus || AENC_NAME=libvorbis;;
    avi)
      CT_FMT=avi; CT_SUBS=""; CT_FAST=0; CT_STAGE=0; CT_HVC=0
      have_enc libmp3lame && AENC_NAME=libmp3lame
      case $CODEC in
        x264) ;;
        x265|av1|hw265|hw264|vp9) warn "AVI works best with H.264 - using x264 for this file."
              case $CODEC in x265) CRF=$(( CRF > 5 ? CRF - 5 : 18 ));; vp9) CRF=$(( CRF > 12 ? CRF - 12 : 20 ));; av1) CRF=$(( CRF > 13 ? CRF - 13 : 20 ));; esac
              CODEC=x264;;
      esac;;
    ts)
      CT_FMT=mpegts; CT_SUBS=""; CT_FAST=0; CT_STAGE=0; CT_HVC=0
      case $CODEC in
        vp9|av1) warn "MPEG-TS needs H.264/H.265 - using x264 for this file."; CODEC=x264; CRF=$(( CRF > 13 ? CRF - 13 : 20 ));;
      esac;;
  esac
  return 0
}

autocrop_find() {   # $1 src -> CROP_VF ("crop=W:H:X:Y" or ""): black bars measured at 3 points, applied only when they agree
  local src=$1 st pos t out crop fw="" fh="" n=0 ux0=99999 uy0=99999 ux1=0 uy1=0 i dx
  local -a CX=() CY=() CR=() CB=()
  local w h x y W H
  CROP_VF=""
  st=${TRIM_START:-0}
  for pos in 0.2 0.5 0.8; do
    t=$(awk -v s="$st" -v d="${EDUR:-$DUR}" -v p="$pos" 'BEGIN{ printf "%.2f", s + d * p }')
    out=$(ffmpeg -nostdin -hide_banner -v info -ss "$t" -t 2 -i "$src" -map 0:v:0 -an \
          -vf "cropdetect=24:2:0,showinfo" -f null - 2>&1)
    if [[ -z $fw && $out =~ \ s:([0-9]+)x([0-9]+) ]]; then fw=${BASH_REMATCH[1]}; fh=${BASH_REMATCH[2]}; fi
    crop=$(grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' <<<"$out" | tail -n1)
    [[ $crop =~ crop=([0-9]+):([0-9]+):([0-9]+):([0-9]+) ]] || return 1
    w=${BASH_REMATCH[1]}; h=${BASH_REMATCH[2]}; x=${BASH_REMATCH[3]}; y=${BASH_REMATCH[4]}
    CX+=("$x"); CY+=("$y"); CR+=("$(( x + w ))"); CB+=("$(( y + h ))")
    (( x < ux0 )) && ux0=$x; (( y < uy0 )) && uy0=$y
    (( x + w > ux1 )) && ux1=$(( x + w )); (( y + h > uy1 )) && uy1=$(( y + h ))
    n=$(( n + 1 ))
  done
  [[ -n $fw && $n -eq 3 ]] || return 1
  for (( i = 0; i < 3; i++ )); do          # all three scenes must agree within 8 px, or the bars are not reliable
    for dx in $(( CX[i] - ux0 )) $(( CY[i] - uy0 )) $(( ux1 - CR[i] )) $(( uy1 - CB[i] )); do
      if (( dx > 8 )); then info "  Black bars differ between scenes - not cropping."; return 1; fi
    done
  done
  ux0=$(( ux0 / 2 * 2 )); uy0=$(( uy0 / 2 * 2 ))
  W=$(( (ux1 - ux0) / 2 * 2 )); H=$(( (uy1 - uy0) / 2 * 2 ))
  (( W > 0 && H > 0 )) || return 1
  (( W * H * 100 <= fw * fh * 97 )) || return 1                 # less than 3% saved: not worth it
  (( W * H * 100 >= fw * fh * 55 )) || { info "  Crop would remove over 45% of the picture - ignored (dark scenes?)."; return 1; }
  CROP_VF="crop=$W:$H:$ux0:$uy0"
  info "  Black bars found: ${fw}x${fh} -> ${W}x${H}"
  return 0
}
compress_file() {
  local CODEC=$CODEC CRF=$CRF SPEED=$SPEED OUT_EXT=$OUT_EXT      # container rules may adjust these for THIS file only
  local src=$1 fidx=${2:-0} fn=${3:-0} tag=""
  local name dst tmp in_sz out_sz saved passes=1 br="" vf rc=0 odur status t0=$SECONDS
  local extarg=() maps=() scodec=() submeta=() fmt fast subfilter="" srt="" keepsubs subn ex_nsubs ex_bad prev
  (( fidx > 0 )) && tag="[$fidx/$fn] "
  name=$(basename -- "$src")
  if ! probe "$src"; then
    add_result "$name" "-" "-" "-" "-" "FAILED (unreadable)" "$src" ""
    tally fail; return 1
  fi
  ex_nsubs=$SRC_NSUBS; ex_bad=$SRC_SUBBAD     # one probe call gave us everything
  container_rules
  in_sz=$(fsize "$src")
  if ! calc_edur; then
    err "Trim range is outside the video."
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (trim)" "$src" ""
    tally fail; return 1
  fi
  printf '  %s%s%dx%d %s %s fps | %s | %s%s\n' "$tag" "$C_D" "$SRC_W" "$SRC_H" "$SRC_VCODEC" "$SRC_FPS" \
    "$(fmt_time "$EDUR")" "$(human "$in_sz")" "$C_0"
  case $SRC_TRC in
    smpte2084|arib-std-b67)
      [[ $CODEC == hw* ]] || warn "HDR video detected: 8-bit SDR output can look washed out. Keep the original if colours matter.";;
  esac

  if (( SKIP_DONE )) && prev=$(done_output "$src"); then
    ok "${tag}Already done - skipped: $(basename -- "$prev")"
    add_result "$name" "$(human "$in_sz")" "$(human "$(fsize "$prev")")" "-" "-" "SKIPPED (already done)" "$src" "$prev"
    return 0
  fi

  if (( TARGET_MB > 0 )); then
    if (( in_sz <= TARGET_MB * 1000000 )) && [[ -z $TRIM_START$TRIM_END ]]; then
      warn "Already under ${TARGET_MB} MB - skipped."
      add_result "$name" "$(human "$in_sz")" "-" "-" "-" "SKIPPED (under target)" "$src" ""
      return 0
    fi
    if ! br=$(calc_bitrate); then
      err "Target ${TARGET_MB} MB is too small for a video this long."
      add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (target too small)" "$src" ""
      tally fail; return 1
    fi
    echo "  Video bitrate: ${br} kbps"
  elif [[ $CODEC == hw* ]]; then
    br=$VBR
  fi
  [[ $CODEC == av1 ]] && passes=1
  [[ -n $br && $CODEC == x* ]] && passes=2
  audio_plan
  (( AUD_COPY )) && printf '  %sAudio: AAC %s kbps is already at/below the target - copied, no re-encode%s\n' "$C_D" "$SRC_ABR" "$C_0"

  TMPD=$(mktemp -d) || { err "Cannot create temp dir."; return 1; }
  dst=$(unique_out "$src")
  if (( CT_STAGE )); then
    out_tmp "$dst" "$in_sz"; tmp=$OT_TMP          # built locally, moved at the end
  else
    tmp="$dst.part"; OT_DIRECT=0                   # MKV needs no faststart pass
  fi
  CUR_TMP=$tmp
  [[ -n $BATCH_TMP && $fidx -gt 0 ]] && printf '%s\n' "$tmp" > "$BATCH_TMP/part_$fidx"

  # ---- subtitle handling (v2.0)
  if [[ $SUB_MODE == soft ]]; then
    if [[ -n $SUB_FILE && -f $SUB_FILE ]]; then srt=$SUB_FILE
    else srt=$(find_srt "$src" 2>/dev/null) || srt=""; fi
    if [[ -z $srt ]]; then
      warn "No matching .srt found - nothing embedded."
    else
      [[ -n $CT_SUBS ]] && info "Embedding subtitles: $(basename -- "$srt")"
      cp -f -- "$srt" "$TMPD/sub.srt"
      if awk -v s="${TRIM_START:-0}" 'BEGIN{ exit !(s+0 > 0) }'; then
        shift_srt "$TMPD/sub.srt" "$TMPD/sub2.srt" "${TRIM_START:-0}" && mv -f "$TMPD/sub2.srt" "$TMPD/sub.srt" \
          && info "Subtitles re-timed to match the trim start."
      fi
      srt="$TMPD/sub.srt"
    fi
  fi
  setup_burn "$src" && subfilter=$SUBFILTER

  keepsubs=$KEEP_SUBS
  if [[ -z $CT_SUBS ]]; then
    (( ex_nsubs > 0 || ${#srt} > 0 )) && warn "${OUT_EXT^^} cannot hold subtitles - they are left out (use MKV/MP4 to keep them)."
    keepsubs=0; srt=""
  fi
  if (( keepsubs )) && (( ex_nsubs > 0 )) && (( ex_bad )); then
    warn "Bitmap subtitles (PGS/DVD) cannot be copied to this container - dropping them."
    keepsubs=0
  fi
  [[ -n $subfilter ]] && keepsubs=0   # burned subtitles replace tracks

  maps=(-map 0:v:0 -map '0:a?')
  (( keepsubs )) && maps+=(-map '0:s?')
  [[ -z $CT_SUBS ]] && maps+=(-sn)
  if [[ -n $srt ]]; then
    extarg=(-i "$srt")
    maps+=(-map 1:0)
  fi
  [[ -n $CT_SUBS ]] && scodec=(-c:s "$CT_SUBS")
  if [[ -n $srt ]]; then
    subn=0; (( keepsubs )) && subn=$ex_nsubs      # index of the NEW track among kept subtitle tracks
    local sublang=$SUB_LANG
    [[ $OUT_EXT == mp4 || $OUT_EXT == mov ]] && sublang=$(lang3 "$sublang")
    submeta=(-metadata:s:s:$subn language="$sublang")
  fi

  fmt=(-f "$CT_FMT"); fast=()
  (( CT_FAST )) && fast=(-movflags +faststart)
  (( OT_DIRECT )) && fast=()

  CROP_VF=""; (( AUTOCROP )) && autocrop_find "$src"
  case $SRC_FIELD in tt|bb|tb|bt) (( DEINT )) && printf '  %sInterlaced picture - deinterlacing%s\n' "$C_D" "$C_0";; esac
  vf=$(build_vf)
  [[ -n $subfilter ]] && vf="${vf:+$vf,}$subfilter"
  VFARG=(); [[ -n $vf ]] && VFARG=(-vf "$vf")
  build_aenc
  META=(); (( STRIP_META )) && META=(-map_metadata -1 -map_chapters -1)

  if (( passes == 2 )); then
    build_venc p1 "$br"
    ( cd "$TMPD" && run_ffmpeg "pass 1/2" 1 2 "${IN_OPTS[@]}" -i "$src" -map 0:v:0 "${VFARG[@]}" "${VENC[@]}" -an -f null /dev/null )
    rc=$?
    if (( rc == 0 )); then
      build_venc p2 "$br"
      ( cd "$TMPD" && run_ffmpeg "pass 2/2" 2 2 "${IN_OPTS[@]}" -i "$src" "${extarg[@]}" "${maps[@]}" "${VFARG[@]}" "${VENC[@]}" \
        "${AENC[@]}" "${scodec[@]}" "${submeta[@]}" "${META[@]}" "${fast[@]}" "${fmt[@]}" -max_muxing_queue_size 2048 "$tmp" )
      rc=$?
    fi
  else
    build_venc single "$br"
    ( cd "$TMPD" && run_ffmpeg "" 1 1 "${IN_OPTS[@]}" -i "$src" "${extarg[@]}" "${maps[@]}" "${VFARG[@]}" "${VENC[@]}" \
      "${AENC[@]}" "${scodec[@]}" "${submeta[@]}" "${META[@]}" "${fast[@]}" "${fmt[@]}" -max_muxing_queue_size 2048 "$tmp" )
    rc=$?
  fi
  rm -rf "$TMPD"; TMPD=""

  if (( rc != 0 )) || [[ ! -s $tmp ]]; then
    err "ffmpeg failed (exit $rc). Last log lines:"
    tail -n 6 "${LOGF:-$LOG}" | sed 's/^/    /' >&2
    rm -f -- "$tmp"; CUR_TMP=""
    [[ -n $BATCH_TMP && -f $BATCH_TMP/part_$fidx ]] && rm -f -- "$BATCH_TMP/part_$fidx"
    add_result "$name" "$(human "$in_sz")" "-" "-" "$(fmt_time $(( SECONDS - t0 )))" "FAILED" "$src" ""
    tally fail; return 1
  fi
  if ! commit_out "$tmp" "$dst"; then
    err "Could not move the output into place (destination writable? enough space?)."
    rm -f -- "$tmp" 2>/dev/null; CUR_TMP=""
    [[ -n $BATCH_TMP && -f $BATCH_TMP/part_$fidx ]] && rm -f -- "$BATCH_TMP/part_$fidx"
    add_result "$name" "$(human "$in_sz")" "-" "-" "$(fmt_time $(( SECONDS - t0 )))" "FAILED (move)" "$src" ""
    tally fail; return 1
  fi
  CUR_TMP=""
  [[ -n $BATCH_TMP && -f $BATCH_TMP/part_$fidx ]] && rm -f -- "$BATCH_TMP/part_$fidx"

  out_sz=$(fsize "$dst"); LAST_OUT=$dst
  saved=$(awk -v a="$in_sz" -v b="$out_sz" 'BEGIN{ d=(1-b/a)*100; printf "%s%.0f%%", (d>=0 ? "-" : "+"), (d>=0 ? d : -d) }')
  status="OK"
  odur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$dst" 2>/dev/null | head -n1)
  if ! awk -v a="${odur:-0}" -v b="$EDUR" 'BEGIN{ d=a-b; if (d<0) d=-d; exit !(d<=2.5) }'; then
    status="CHECK (duration differs)"; warn "Output duration differs from expected - please check the file."
  fi
  if (( out_sz >= in_sz )); then
    status="OK (not smaller)"; warn "Output is not smaller than the original. Try a higher CRF or lower resolution."
  fi
  if (( TARGET_MB > 0 && out_sz > TARGET_MB * 1000000 )); then
    warn "Output is slightly over the ${TARGET_MB} MB target. Re-run with a smaller target."
  fi
  ok "$(basename -- "$dst")  $(human "$in_sz") -> $(human "$out_sz")  (${saved})"
  if (( DELETE_ORIG )) && [[ $status == "OK" && -z $TRIM_START$TRIM_END ]]; then
    rm -f -- "$src" && ok "Original deleted."
  fi
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$dst" >/dev/null 2>&1 & }
  tally ok "$in_sz" "$out_sz"
  add_result "$name" "$(human "$in_sz")" "$(human "$out_sz")" "${saved}" "$(fmt_time $(( SECONDS - t0 )))" "$status" "$src" "$dst"
  return 0
}
done_output() {   # $1 src -> echo the finished output of an earlier run (needs EDUR); 1 = none
  local src=$1 dir base out od
  dir=${OUTDIR:-$(dirname -- "$src")}
  base=$(basename -- "$src"); base=${base%.*}
  out="$dir/${base}${SUFFIX}.$OUT_EXT"
  [[ -s $out ]] || return 1
  od=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out" 2>/dev/null | head -n1)
  awk -v a="${od:-0}" -v b="$EDUR" 'BEGIN{ d=a-b; if (d<0) d=-d; exit !(d<=2.5) }' || return 1
  printf '%s' "$out"
}
is_vc_output() {   # 0 = this file name looks like something vc itself produced
  local b=${1##*/}; b=${b%.*}
  [[ -n $SUFFIX && $b == *"$SUFFIX" ]] && return 0
  case $b in *_repaired|*_fixed|*_shifted|*_subbed|*_burned|*_nosub|*_compare|*_compressed) return 0;; esac
  return 1
}

# ---------------------------------------------------------------- batch run ---
wake_lock()   { if command -v termux-wake-lock >/dev/null 2>&1; then termux-wake-lock; WAKE=1; fi; }
wake_unlock() { if (( WAKE )) && command -v termux-wake-unlock >/dev/null 2>&1; then termux-wake-unlock; WAKE=0; fi; }
notify() {
  if command -v termux-notification >/dev/null 2>&1; then
    ( timeout 8 termux-notification --title "VidCompress" --content "$1" >/dev/null 2>&1 & )
  fi
}

run_batch() {
  (( ${#SELECTED[@]} )) || { err "No videos selected."; return 1; }
  case $CODEC in
    hw265|hw264)
      have_enc "$(hw_encoder_name)" || { err "Hardware encoder '$(hw_encoder_name)' is not available in this ffmpeg build."
        err "Pick x265, x264 or av1 instead (Settings > 1)."; return 1; };;
    av1)
      have_enc libsvtav1 || { err "This ffmpeg build has no libsvtav1 (AV1) encoder."
        err "Update ffmpeg or pick x265/x264 (Settings > 1)."; return 1; };;
  esac
  # hardware encoders are light on CPU - use 2 parallel jobs automatically
  if (( PARALLEL_JOBS <= 1 )) && [[ $CODEC == hw* ]] && (( $(nproc 2>/dev/null || echo 4) >= 6 )); then
    PARALLEL_JOBS=2; info "Hardware encoder detected: using 2 parallel jobs automatically."
  fi
  mkdir -p "$CONF_DIR"; : > "$LOG"
  RESULTS=(); N_OK=0; N_FAIL=0; TOTAL_IN=0; TOTAL_OUT=0; BATCH_T0=$SECONDS
  BATCH_TMP=$(mktemp -d) || { err "Cannot create temp dir."; return 1; }
  wake_lock
  [[ -z $VC_NOSTAGE ]] && stage_root   # one shared build area: parallel children inherit it
  detect_ff_caps
  calc_threads "$PARALLEL_JOBS"        # parallel jobs split the CPU instead of fighting for it
  (( PIN_N > 0 )) && info "CPU: $PIN_NOTE, ${THREADS_PER_JOB} thread(s) per job"
  local i=0 n=${#SELECTED[@]} f st a b running=0
  if (( PARALLEL_JOBS > 1 )); then
    info "Parallel mode: up to $PARALLEL_JOBS files at once ($n total, $THREADS_PER_JOB threads each)"
    for f in "${SELECTED[@]}"; do
      i=$(( i + 1 ))
      while (( running >= PARALLEL_JOBS )); do wait -n || true; running=$(( running - 1 )); done
      printf '%s[%d/%d] %s%s\n' "$C_B" "$i" "$n" "$(trunc "$(basename -- "$f")")" "$C_0"
      (
        SIMPLE=1 LOGF="$BATCH_TMP/log_$i" STATS="$BATCH_TMP/stats" RESULT_FILE="$BATCH_TMP/results"
        compress_file "$f" "$i" "$n"
      ) &
      running=$(( running + 1 ))
    done
    wait
    [[ -f $BATCH_TMP/results ]] && mapfile -t RESULTS < "$BATCH_TMP/results"
    if [[ -f $BATCH_TMP/stats ]]; then
      while read -r st a b; do
        case $st in
          ok)   N_OK=$(( N_OK + 1 )); TOTAL_IN=$(( TOTAL_IN + a )); TOTAL_OUT=$(( TOTAL_OUT + b ));;
          fail) N_FAIL=$(( N_FAIL + 1 ));;
        esac
      done < "$BATCH_TMP/stats"
    fi
    cat "$BATCH_TMP"/log_* >> "$LOG" 2>/dev/null
  else
    for f in "${SELECTED[@]}"; do
      i=$(( i + 1 ))
      printf '\n%s[%d/%d] %s%s\n' "$C_B" "$i" "$n" "$(trunc "$(basename -- "$f")")" "$C_0"
      compress_file "$f" "$i" "$n"
    done
  fi
  rm -rf "$BATCH_TMP"; BATCH_TMP=""
  wake_unlock
  print_summary
  notify "Finished: $N_OK ok, $N_FAIL failed"
  (( N_FAIL == 0 ))
}

print_summary() {
  local r name old new pct tm st src dst
  printf '\n%s== Summary ==%s\n' "$C_B" "$C_0"
  for r in "${RESULTS[@]}"; do
    IFS=$'\t' read -r name old new pct tm st src dst <<<"$r"
    printf '%s\n    %s -> %s  %s  [%s]  %s\n' "$(trunc "$name")" "$old" "$new" "$pct" "$tm" "$st"
  done
  if (( N_OK > 0 )); then
    printf '\n%sTotal:%s %s -> %s  (saved %s)\n' "$C_B" "$C_0" "$(human "$TOTAL_IN")" "$(human "$TOTAL_OUT")" \
      "$(human $(( TOTAL_IN - TOTAL_OUT )))"
  fi
  (( BATCH_T0 > 0 )) && printf '%sTime :%s %s\n' "$C_B" "$C_0" "$(fmt_time $(( SECONDS - BATCH_T0 )))"
  printf 'Done: %d ok, %d failed.  Log: %s\n' "$N_OK" "$N_FAIL" "$(pretty "$LOG")"
}

# ------------------------------------------------------ size estimate (test) ---
estimate_size() {
  (( ${#SELECTED[@]} )) || { warn "Select a video first."; return; }
  local src=${SELECTED[0]} slen sstart full tmp sz est br="" vf subfilter=""
  probe "$src" || return
  calc_edur || { err "Trim range is outside the video."; return; }
  full=$EDUR
  if (( TARGET_MB > 0 )); then info "Target-size mode: output will be about ${TARGET_MB} MB."; return; fi
  [[ $CODEC == hw* ]] && br=$VBR
  slen=$(awk -v d="$full" 'BEGIN{ printf "%.1f", (d > 25) ? 20 : d }')
  sstart=$(awk -v d="$full" -v t="${TRIM_START:-0}" 'BEGIN{ s=d/2-10; if (s<0) s=0; printf "%.1f", t+s }')
  info "Encoding a ${slen}s test sample from the middle of: $(basename -- "$src")"
  TMPD=$(mktemp -d) || return
  mkdir -p "$CONF_DIR"; : > "$LOG"
  EDUR=$slen; tmp="$TMPD/sample.mp4"
  setup_burn "$src" && subfilter=$SUBFILTER
  vf=$(build_vf)
  [[ -n $subfilter ]] && vf="${vf:+$vf,}$subfilter"
  VFARG=(); [[ -n $vf ]] && VFARG=(-vf "$vf")
  build_aenc; build_venc single "$br"
  ( cd "$TMPD" && run_ffmpeg "" 1 1 -ss "$sstart" -t "$slen" -i "$src" -map 0:v:0 -map '0:a?' "${VFARG[@]}" "${VENC[@]}" "${AENC[@]}" -f mp4 "$tmp" )
  if [[ -s $tmp ]]; then
    sz=$(fsize "$tmp")
    est=$(awk -v s="$sz" -v f="$full" -v l="$slen" 'BEGIN{ printf "%d", s*f/l }')
    ok "Estimated output: ~$(human "$est")  (original: $(human "$(fsize "$src")"))  - rough, about +/-20%"
  else
    err "Test encode failed."; tail -n 5 "$LOG" >&2
  fi
  rm -rf "$TMPD"; TMPD=""
}

# ---------------------------------------------------------- file selection ---
list_videos() {
  find -H "$1" -maxdepth 1 -type f -regextype posix-extended -iregex ".*\.($VIDEO_EXT)" \
    -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-
}
list_videos_sz() {   # "size<TAB>path" lines, newest first (one find, no per-file stat)
  find -H "$1" -maxdepth 1 -type f -regextype posix-extended -iregex ".*\.($VIDEO_EXT)" \
    -printf '%T@\t%s\t%p\n' 2>/dev/null | sort -rn | cut -f2-
}
add_sel() {
  local f x; f=$(readlink -f -- "$1")
  for x in "${SELECTED[@]}"; do [[ $x == "$f" ]] && return 0; done
  SELECTED+=("$f")
}
add_path() {
  local p=$1
  p=${p#[\'\"]}; p=${p%[\'\"]}; p=${p/#\~/$HOME}
  if [[ -d $p ]]; then pick_from_dir "$p"
  elif [[ -f $p ]]; then add_sel "$p"; ok "Added: $(basename -- "$p")"
  else err "Not found: $p"; fi
}
pick_from_dir() {
  local dir=$1 files=() sizes=() ans toks tok lo hi n added f i line
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    sizes+=("${line%%$'\t'*}"); files+=("${line#*$'\t'}"); SZC[${line#*$'\t'}]=${line%%$'\t'*}
  done < <(list_videos_sz "$dir" | head -n 60)
  if (( ${#files[@]} == 0 )); then warn "No videos in $(pretty "$dir")"; return 1; fi
  while true; do
    printf '\n%s%s%s  (newest first)\n' "$C_B" "$(pretty "$dir")" "$C_0"
    for i in "${!files[@]}"; do
      printf ' %2d) %8s  %s\n' $(( i + 1 )) "$(human "${sizes[i]}")" "$(trunc "${files[i]##*/}")"
    done
    echo "Numbers (e.g. 1 3 5-7), a = all, b = back"
    read -r -p "> " ans || return 1
    case ${ans,,} in
      b|"") return 1;;
      a) for f in "${files[@]}"; do add_sel "$f"; done; ok "Added ${#files[@]} video(s)."; return 0;;
    esac
    read -ra toks <<<"$ans"; added=0
    for tok in "${toks[@]}"; do
      if [[ $tok =~ ^[0-9]+$ ]]; then lo=$tok; hi=$tok
      elif [[ $tok =~ ^([0-9]+)-([0-9]+)$ ]]; then lo=${BASH_REMATCH[1]}; hi=${BASH_REMATCH[2]}
      else continue; fi
      for (( n = lo; n <= hi; n++ )); do
        if (( n >= 1 && n <= ${#files[@]} )); then add_sel "${files[n-1]}"; added=$(( added + 1 )); fi
      done
    done
    if (( added > 0 )); then ok "Added $added video(s)."; return 0; else warn "Nothing matched."; fi
  done
}

# --- v2.0: real folder browser -----------------------------------------------
browse_folders() {
  local cur ans i rel v root line rest p child n showall=0 hid pc
  local -a vids=() vsz=() dirs=() order=() alld=()
  local -A cnt=()
  fv_root; root=$FV_ROOT; cur=$root
  (( ${#FV_ALL[@]} )) || fv_scan
  while true; do
    # video counts per sub-folder come from the scan (no extra work); folders are fresh from disk
    cnt=(); order=()
    for line in "${FV_ALL[@]}"; do
      rest=${line#*$'\t'}; p=${rest#*$'\t'}
      [[ $p == "$cur"/* ]] || continue
      child=${p#"$cur"/}; [[ $child == */* ]] || continue
      child=${child%%/*}
      if [[ -z ${cnt[$child]+x} ]]; then order+=("$child"); cnt[$child]=0; fi
      cnt[$child]=$(( cnt[$child] + 1 ))
    done
    mapfile -t alld < <(find -H "$cur" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' 2>/dev/null | LC_ALL=C sort)
    dirs=(); hid=0
    for child in "${order[@]}"; do
      for p in "${alld[@]}"; do [[ $p == "$child" ]] && { dirs+=("$child"); break; }; done
    done
    for p in "${alld[@]}"; do
      [[ -n ${cnt[$p]+x} ]] && continue
      if (( showall || ${#FV_ALL[@]} == 0 )); then dirs+=("$p"); else hid=$(( hid + 1 )); fi
    done
    vids=(); vsz=()
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      vsz+=("${line%%$'\t'*}"); vids+=("${line#*$'\t'}"); SZC[${line#*$'\t'}]=${line%%$'\t'*}
    done < <(list_videos_sz "$cur" | head -n 40)
    clear_screen
    printf '%s== Browse folders ==%s\n\n' "$C_B" "$C_0"
    printf ' %s\n\n' "$(pretty "$cur")"
    for (( i = 0; i < ${#dirs[@]} && i < 30; i++ )); do
      pc=${cnt[${dirs[i]}]-0}
      if (( pc > 0 )); then printf ' %-4s %s/   %s%d video%s%s\n' "d$(( i + 1 ))" "$(trunc "${dirs[i]}")" "$C_D" "$pc" "$( (( pc == 1 )) || echo s )" "$C_0"
      else printf ' %-4s %s/\n' "d$(( i + 1 ))" "$(trunc "${dirs[i]}")"; fi
    done
    (( ${#dirs[@]} > 30 )) && printf '  %s... %d more folders%s\n' "$C_D" $(( ${#dirs[@]} - 30 )) "$C_0"
    (( hid > 0 )) && printf '  %s(%d folder(s) without videos hidden - x shows them)%s\n' "$C_D" "$hid" "$C_0"
    (( ${#dirs[@]} > 0 || hid > 0 )) && echo
    for i in "${!vids[@]}"; do
      printf ' %3d) %8s  %s\n' $(( i + 1 )) "$(human "${vsz[i]}")" "$(trunc "${vids[i]##*/}")"
    done
    (( ${#vids[@]} == 0 )) && echo "  (no videos directly in this folder)"
    echo
    echo " number = pick video     d<n> = open folder"
    echo " a = add all videos here  aa = add ALL inside (sub-folders too)"
    echo " u = up   x = empty folders on/off   r = rescan"
    echo " p = type a path   b = back"
    read -r -p "> " ans || return
    case ${ans,,} in
      b|"") return;;
      u) if [[ $cur == "$root" ]]; then warn "This is the top of your phone storage."; sleep 1; else cur=$(dirname -- "$cur"); fi;;
      x) showall=$(( 1 - showall ));;
      r) fv_scan;;
      p) ans=$(ask "Path (file or folder)" "")
         [[ -n $ans ]] && { add_path "$ans"; return; };;
      a) if (( ${#vids[@]} > 0 )); then
           for v in "${vids[@]}"; do add_sel "$v"; done
           ok "Added ${#vids[@]} video(s) from this folder."
           return
         else warn "No videos directly here - try aa (everything inside)."; sleep 1; fi;;
      aa) n=0
          for line in "${FV_ALL[@]}"; do
            rest=${line#*$'\t'}; p=${rest#*$'\t'}
            [[ $p == "$cur"/* ]] || continue
            add_sel "$p"; n=$(( n + 1 ))
          done
          if (( n > 0 )); then ok "Added $n video(s) from this folder and its sub-folders."; return
          else warn "No videos found inside (press r to rescan)."; sleep 1; fi;;
      d*)
        rel=${ans#d}; rel=${rel#D}
        if [[ $rel =~ ^[0-9]+$ ]] && (( rel >= 1 && rel <= ${#dirs[@]} )); then
          cur="$cur/${dirs[rel-1]}"
        fi;;
      *)
        if [[ $ans =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= ${#vids[@]} )); then
          add_sel "${vids[ans-1]}"
          ok "Added: $(basename -- "${vids[ans-1]}")  (${#SELECTED[@]} in queue)"
        fi;;
    esac
  done
}

# ================================================== EASY VIDEO FINDER (v2.5)
fv_root() {   # top of the phone's shared storage -> FV_ROOT (as typed) and FV_REAL (links resolved)
  if   [[ -d $HOME/storage/shared ]]; then FV_ROOT="$HOME/storage/shared"
  elif [[ -d /sdcard ]];              then FV_ROOT=/sdcard
  elif [[ -d /storage/emulated/0 ]];  then FV_ROOT=/storage/emulated/0
  else FV_ROOT=$HOME; fi
  FV_REAL=$(readlink -f -- "$FV_ROOT" 2>/dev/null) || FV_REAL=$FV_ROOT
  [[ -n $FV_REAL ]] || FV_REAL=$FV_ROOT
}
fv_scan() {   # one pass over the phone's shared storage -> FV_ALL ("epoch<TAB>size<TAB>path", newest first)
  local -a roots=()
  local line
  fv_root; roots=("$FV_ROOT")
  FV_ALL=()
  printf '  %sLooking for videos on your phone...%s' "$C_D" "$C_0"
  while IFS= read -r line; do
    [[ -n $line ]] && FV_ALL+=("$line")
  done < <(timeout 120 find -H "${roots[@]}" -maxdepth 9 \
      \( -name '.*' -o -iname cache -o -iname thumbnails -o -path '*/Android/data' -o -path '*/Android/obb' \) -prune -o \
      -type f -regextype posix-extended -iregex ".*\.($VIDEO_EXT)" -size +100k -printf '%T@\t%s\t%p\n' 2>/dev/null | sort -rn)
  printf '\r\033[K'
}
fv_age() {   # epoch -> AGE_TXT
  local t=${1%%.*} now=${EPOCHSECONDS:-0} d
  if (( now == 0 )); then printf -v AGE_TXT '%(%Y-%m-%d)T' "$t"; return 0; fi
  d=$(( (now - t) / 86400 ))
  if   (( d <= 0 )); then AGE_TXT="today"
  elif (( d == 1 )); then AGE_TXT="yesterday"
  elif (( d < 7 ));  then AGE_TXT="$d days ago"
  else printf -v AGE_TXT '%(%Y-%m-%d)T' "$t"; fi
}
find_videos() {   # $1 = multi (default: add to the queue) | one (sets PICK_RESULT)
  local mode=${1:-multi} page=0 per=8 q="" ans i n tot line path size mt rest dir lbl mark hidden tok lo hi added sel first last real
  local -a view=() toks=()
  PICK_RESULT=""
  (( ${#FV_ALL[@]} )) || fv_scan
  while true; do
    view=(); hidden=0
    for line in "${FV_ALL[@]}"; do
      rest=${line#*$'\t'}; path=${rest#*$'\t'}
      if [[ -n $q ]]; then
        [[ ${path,,} == *"${q,,}"* ]] || continue
      elif is_vc_output "$path"; then hidden=$(( hidden + 1 )); continue; fi
      view+=("$line")
    done
    tot=${#view[@]}
    (( page * per >= tot )) && page=0
    first=$(( page * per )); last=$(( first + per )); (( last > tot )) && last=$tot
    clear_screen
    if [[ $mode == one ]]; then printf '%sPick ONE video%s' "$C_B" "$C_0"; else printf '%sYour videos%s  (newest first)' "$C_B" "$C_0"; fi
    printf '\n %d found%s' "$tot" "${q:+ for \"$q\"}"
    (( ${#SELECTED[@]} )) && [[ $mode != one ]] && printf '   |   in queue: %d' "${#SELECTED[@]}"
    printf '\n'
    (( hidden )) && printf ' %s%d already-compressed file(s) hidden%s\n' "$C_D" "$hidden" "$C_0"
    echo
    if (( tot == 0 )); then
      echo "  Nothing found. Try another word, or: r = scan again,"
      echo "  f = browse folders, p = type a path."
    fi
    for (( i = first; i < last; i++ )); do
      line=${view[i]}; mt=${line%%$'\t'*}; rest=${line#*$'\t'}; size=${rest%%$'\t'*}; path=${rest#*$'\t'}
      SZC[$path]=$size
      fv_age "$mt"
      dir=${path%/*}; lbl=${dir##*/}; dir=${dir%/*}
      case ${dir##*/} in shared|0|emulated|storage|sdcard|"") ;; *) lbl="${dir##*/}/$lbl";; esac
      real=$path; [[ $path == "$FV_ROOT"/* ]] && real=$FV_REAL${path#"$FV_ROOT"}
      mark=" "; for sel in "${SELECTED[@]}"; do [[ $sel == "$real" || $sel == "$path" ]] && mark="✔"; done
      printf ' %s%2d) %8s  %s  %s\n' "$mark" $(( i + 1 )) "$(human "$size")" "$AGE_TXT" "$(trunc "$lbl")"
      printf '        %s\n' "$(trunc "${path##*/}")"
    done
    (( tot > last )) && printf '\n  %s...%d more: type m%s\n' "$C_D" $(( tot - last )) "$C_0"
    echo
    if [[ $mode == one ]]; then
      echo " number = pick     word = search     m = more"
      echo " f = folders   p = type a path   b = cancel"
    else
      echo " numbers = pick (1 3 5-7)   word = search"
      printf ' m = more   a = pick ALL %d   s = START now\n' "$tot"
      echo " f = folders   p = type a path   d = done"
    fi
    read -r -p "> " ans || return 1
    case ${ans,,} in
      b|d|"") if [[ $mode == one ]]; then return 1; else return 0; fi;;
      m) page=$(( page + 1 ));;
      r) fv_scan; q=""; page=0;;
      f) if [[ $mode == one ]]; then warn "Use p to type a path, or pick a number."; sleep 1
         else browse_folders; fi;;
      p) ans=$(ask "Path (file or folder)" "")
         ans=${ans#[\'\"]}; ans=${ans%[\'\"]}; ans=${ans/#\~/$HOME}
         if [[ $mode == one ]]; then
           if [[ -f $ans ]]; then PICK_RESULT=$(readlink -f -- "$ans"); return 0; fi
           [[ -n $ans ]] && { warn "Not found: $ans"; sleep 1; }
         else [[ -n $ans ]] && add_path "$ans"; fi;;
      a) if [[ $mode != one ]]; then
           if (( tot == 0 )); then warn "Nothing to add."; sleep 1
           elif (( tot > 40 )) && ! yesno "Add all $tot videos to the queue?" y; then :
           else
             for (( i = 0; i < tot; i++ )); do line=${view[i]}; add_sel "${line#*$'\t'*$'\t'}"; done
             ok "Added all $tot video(s) - ${#SELECTED[@]} in the queue."; sleep 1
           fi
         fi;;
      s) if [[ $mode != one ]]; then
           if (( ${#SELECTED[@]} )); then start_flow; return 0; else warn "Pick at least one video first."; sleep 1; fi
         fi;;
      /*) q=${ans#/}; page=0;;
      *)
        if [[ $ans =~ ^[0-9][0-9\ ,-]*$ ]]; then
          read -ra toks <<<"${ans//,/ }"; added=0
          for tok in "${toks[@]}"; do
            if [[ $tok =~ ^[0-9]+$ ]]; then lo=$tok; hi=$tok
            elif [[ $tok =~ ^([0-9]+)-([0-9]+)$ ]]; then lo=${BASH_REMATCH[1]}; hi=${BASH_REMATCH[2]}
            else continue; fi
            for (( n = lo; n <= hi; n++ )); do
              if (( n >= 1 && n <= tot )); then
                line=${view[n-1]}; path=${line#*$'\t'*$'\t'}
                if [[ $mode == one ]]; then PICK_RESULT=$path; return 0; fi
                add_sel "$path"; added=$(( added + 1 ))
              fi
            done
          done
          (( added > 0 )) && { ok "Added $added video(s) - ${#SELECTED[@]} in the queue."; sleep 1; }
        else
          q=$ans; page=0
        fi;;
    esac
  done
}
quick_locations() {
  local cands=() d ans s="$HOME/storage/shared"
  if [[ ! -d $HOME/storage ]]; then warn "No storage access yet. Run: termux-setup-storage  (or: vc --setup)"; fi
  for d in "$s/DCIM/Camera" "$s/Download" "$s/Movies" "$s/DCIM" "$s/Pictures/Screenshots" \
           "$s/Telegram/Telegram Video" "$s/Android/media/org.telegram.messenger/Telegram/Telegram Video" \
           "$s/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video" "$s" "$PWD"; do
    [[ -d $d ]] && cands+=("$d")
  done
  while true; do
    printf '\n%sQuick locations%s\n' "$C_B" "$C_0"
    local i
    for i in "${!cands[@]}"; do printf ' %2d) %s\n' $(( i + 1 )) "$(trunc "$(pretty "${cands[i]}")")"; done
    echo "  p) type/paste a path (file or folder)     b) back"
    read -r -p "> " ans || return 1
    case $ans in
      b|B|"") return 1;;
      p|P) ans=$(ask "Path" ""); [[ -n $ans ]] && add_path "$ans"; return;;
      *[!0-9]*) add_path "$ans"; return;;
      *) if (( ans >= 1 && ans <= ${#cands[@]} )); then pick_from_dir "${cands[ans-1]}" && return; fi;;
    esac
  done
}
choose_videos() {
  find_videos multi
}

# --- v2.0: queue management ---------------------------------------------------
queue_menu() {
  local c i n
  while true; do
    clear_screen
    n=${#SELECTED[@]}
    sum_sizes
    printf '%s== Queue ==%s  (%d file(s), %s)\n\n' "$C_B" "$C_0" "$n" "$(human "$SEL_BYTES")"
    if (( n == 0 )); then
      echo "  (empty - choose videos first)"
    else
      for i in "${!SELECTED[@]}"; do
        fsize_v "${SELECTED[i]}"
        printf ' %2d) %8s  %s\n' $(( i + 1 )) "$(human "$FSZ")" "$(trunc "$(pretty "${SELECTED[i]}")")"
      done
    fi
    printf '\n  r) remove one   c) clear   b) back\n'
    read -r -p "> " c || return
    case $c in
      r|R) c=$(ask "Number to remove" "")
           if [[ $c =~ ^[0-9]+$ ]] && (( c >= 1 && c <= n )); then
             ok "Removed: $(basename -- "${SELECTED[c-1]}")"
             SELECTED=("${SELECTED[@]:0:c-1}" "${SELECTED[@]:c}")
           else
             warn "Bad number."
           fi;;
      c|C) SELECTED=(); ok "Queue cleared.";;
      b|B|"") return;;
    esac
  done
}

# ---------------------------------------------- v2.0: open / compare / results
open_file() {
  local f=$1
  [[ -f $f ]] || { warn "File not found."; return 1; }
  if command -v termux-open >/dev/null 2>&1 && termux-open "$f" >/dev/null 2>&1; then
    return 0
  fi
  if command -v xdg-open >/dev/null 2>&1 && xdg-open "$f" >/dev/null 2>&1; then
    return 0
  fi
  if [[ -x /system/bin/am ]]; then
    /system/bin/am start -a android.intent.action.VIEW -t "video/*" -d "file://$f" >/dev/null 2>&1 && return 0
  fi
  warn "Could not open automatically: $(pretty "$f")"
  return 1
}

compare_info() {   # $1 original  $2 output -> side-by-side info table
  local f1=$1 f2=$2
  local a_sz a_dur a_res a_fps a_br a_ac a_sub b_sz b_dur b_res b_fps b_br b_ac b_sub
  probe "$f1" || return 1
  a_sz=$(fsize "$f1"); a_dur=$DUR
  a_res="${SRC_W}x${SRC_H} ${SRC_VCODEC}"; a_fps=$SRC_FPS
  a_br=${SRC_VBR:-$(awk -v s="$a_sz" -v d="$DUR" 'BEGIN{ if (d+0>0) printf "%d", s*8/d/1000; else print "?" }')}
  a_ac="${SRC_ACODEC:-none}${SRC_ABR:+, ${SRC_ABR} kbps}"
  a_sub=$SRC_NSUBS
  probe "$f2" || return 1
  b_sz=$(fsize "$f2"); b_dur=$DUR
  b_res="${SRC_W}x${SRC_H} ${SRC_VCODEC}"; b_fps=$SRC_FPS
  b_br=${SRC_VBR:-$(awk -v s="$b_sz" -v d="$DUR" 'BEGIN{ if (d+0>0) printf "%d", s*8/d/1000; else print "?" }')}
  b_ac="${SRC_ACODEC:-none}${SRC_ABR:+, ${SRC_ABR} kbps}"
  b_sub=$SRC_NSUBS
  printf '\n%s== Comparison ==%s\n' "$C_B" "$C_0"
  printf ' %-11s %-28s %s\n' "" "ORIGINAL" "OUTPUT"
  printf ' %-11s %-28s %s\n' "Size"      "$(human "$a_sz")" "$(human "$b_sz")"
  printf ' %-11s %-28s %s\n' "Duration"  "$(fmt_time "$a_dur")" "$(fmt_time "$b_dur")"
  printf ' %-11s %-28s %s\n' "Video"     "$a_res" "$b_res"
  printf ' %-11s %-28s %s\n' "Bitrate"   "${a_br} kbps" "${b_br} kbps"
  printf ' %-11s %-28s %s\n' "Frame rate" "${a_fps} fps" "${b_fps} fps"
  printf ' %-11s %-28s %s\n' "Audio"     "$a_ac" "$b_ac"
  printf ' %-11s %-28s %s\n' "Subtitles" "$a_sub track(s)" "$b_sub track(s)"
  printf ' %-11s %-28s %s\n' "Saved"     "" \
    "$(awk -v a="$a_sz" -v b="$b_sz" 'BEGIN{ if (a+0>0) printf "%.1f%%", (1-b/a)*100 }')"
}

compare_video() {   # $1 original  $2 output -> side-by-side sample with labels
  local f1=$1 f2=$2 dur start len out dir base tmp fc lblfont rc
  local -a cfast=()
  probe "$f1" || return 1; dur=$DUR
  len=$(awk -v d="$dur" 'BEGIN{ l=(d<20)?d/2:20; printf "%.1f", l }')
  start=$(awk -v d="$dur" -v l="$len" 'BEGIN{ s=(d-l)/2; if (s<0) s=0; printf "%.1f", s }')
  dir=$(dirname -- "$f2"); base=$(basename -- "$f2"); base=${base%.*}
  out=$(unique_file "$dir" "${base}_compare" "mp4")
  out_tmp "$out" 0; tmp=$OT_TMP; CUR_TMP=$tmp
  cfast=(-movflags +faststart); (( OT_DIRECT )) && cfast=()
  lblfont=$(label_font)
  if [[ -n $lblfont ]]; then
    fc="[0:v]scale=-2:360,setsar=1,drawtext=fontfile=${lblfont}:text='ORIGINAL':x=10:y=8:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.45[l];[1:v]scale=-2:360,setsar=1,drawtext=fontfile=${lblfont}:text='COMPRESSED':x=10:y=8:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.45[r];[l][r]hstack[v]"
  else
    fc="[0:v]scale=-2:360,setsar=1[l];[1:v]scale=-2:360,setsar=1[r];[l][r]hstack[v]"
  fi
  EDUR=$len
  mkdir -p "$CONF_DIR" 2>/dev/null
  info "Creating ${len}s side-by-side comparison (original left, output right)..."
  run_ffmpeg "compare" 1 1 -ss "$start" -t "$len" -i "$f1" -ss "$start" -t "$len" -i "$f2" \
    -filter_complex "$fc" -map "[v]" -an -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p \
    "${cfast[@]}" -f mp4 "$tmp"
  rc=$?
  CUR_TMP=""
  if (( rc == 0 )) && [[ -s $tmp ]] && commit_out "$tmp" "$out"; then
    COMPARE_OUT=$out
    ok "Comparison video: $(pretty "$out")"
    command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
    return 0
  fi
  rm -f -- "$tmp"
  err "Could not create the comparison video."
  tail -n 4 "$LOG" >&2
  return 1
}

results_menu() {
  (( ${#RESULTS[@]} )) || { warn "No results yet - compress something first."; pause; return; }
  local c num i r_name r_in r_out r_saved r_time r_status r_src r_dst
  while true; do
    clear_screen
    printf '%s== Results & Compare ==%s\n\n' "$C_B" "$C_0"
    for i in "${!RESULTS[@]}"; do
      IFS=$'\t' read -r r_name r_in r_out r_saved r_time r_status r_src r_dst <<<"${RESULTS[i]}"
      printf ' %2d) %-7s %s -> %s  %s  %s\n' $(( i + 1 )) "${r_status%% (*}" "$(trunc "$r_name")" "$r_in" "$r_out" "$r_saved"
    done
    printf '\n 1) Open output in player\n 2) Open original in player\n 3) Compare info (table)\n 4) Make side-by-side comparison video\n 5) Show last log\n b) back\n'
    read -r -p "> " c || return
    case $c in
      1|2|3|4)
        num=$(ask "Which number" "1")
        if [[ $num =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#RESULTS[@]} )); then
          IFS=$'\t' read -r r_name r_in r_out r_saved r_time r_status r_src r_dst <<<"${RESULTS[num-1]}"
          case $c in
            1) if [[ -n $r_dst && -f $r_dst ]]; then open_file "$r_dst"; else warn "Output file not found."; fi;;
            2) if [[ -n $r_src && -f $r_src ]]; then open_file "$r_src"; else warn "Original not found (deleted?)."; fi;;
            3) if [[ -n $r_src && -n $r_dst && -f $r_src && -f $r_dst ]]; then compare_info "$r_src" "$r_dst"; else warn "Original or output is missing."; fi;;
            4) if [[ -n $r_src && -n $r_dst && -f $r_src && -f $r_dst ]]; then
                 compare_video "$r_src" "$r_dst" && { yesno "Open the comparison video?" y && open_file "$COMPARE_OUT"; }
               else warn "Original or output is missing."; fi;;
          esac
        else
          warn "Bad number."
        fi
        pause;;
      5) if [[ -s $LOG ]]; then tail -n 40 "$LOG"; else echo "(log is empty)"; fi; pause;;
      b|B|"") return;;
    esac
  done
}

finish_flow() {   # what to do after a batch (configurable: Settings > 20)
  local r r_name r_in r_out r_sv r_tm r_st r_src r_dst
  case $FINISH_ACTION in
    open)
      for r in "${RESULTS[@]}"; do
        IFS=$'\t' read -r r_name r_in r_out r_sv r_tm r_st r_src r_dst <<<"$r"
        if [[ $r_st == OK* && -n $r_dst && -f $r_dst ]]; then open_file "$r_dst"; break; fi
      done;;
    summary) ;;
    *)
      (( NONINTERACTIVE )) && return
      results_menu;;
  esac
}

# ---------------------------------------------------- pick a working target ---
pick_target() {   # sets PICK_RESULT (prints prompts to stdout, not the result)
  PICK_RESULT=""
  local i c p
  if [[ -n $FORCE_TARGET ]]; then PICK_RESULT=$FORCE_TARGET; return 0; fi     # queue runner decides the file
  if (( ${#SELECTED[@]} )); then
    if (( ${#SELECTED[@]} == 1 )); then PICK_RESULT=${SELECTED[0]}; return 0; fi
    echo "Pick a video:"
    for i in "${!SELECTED[@]}"; do printf ' %2d) %s\n' $(( i + 1 )) "$(basename -- "${SELECTED[i]}")"; done
    c=$(ask "Number" "1")
    if [[ $c =~ ^[0-9]+$ ]] && (( c >= 1 && c <= ${#SELECTED[@]} )); then
      PICK_RESULT=${SELECTED[c-1]}; return 0
    fi
    return 1
  fi
  if [[ -t 0 && -t 1 ]]; then
    find_videos one && [[ -n $PICK_RESULT ]] && return 0
    return 1
  fi
  p=$(ask "Path to video" "")
  if [[ -n $p && -f $p ]]; then PICK_RESULT=$(readlink -f -- "$p"); return 0; fi
  warn "Not found: $p"
  return 1
}

# =========================================================== SUBTITLE STUDIO
sub_embed_soft() {   # $1 video -> embed SRT as a selectable track (no re-encode)
  local vid=$(readlink -f -- "$1") srt lang ext scodec fmt existing keepmaps subidx out rc base aenc tmp
  srt=$(resolve_srt "$vid") || { warn "Cancelled."; return 1; }
  lang=$(ask "Language code (fa, en, ar, ...)" "$SUB_LANG")
  ext="mp4"; scodec=(-c:s mov_text)
  case ${vid##*.} in mkv|MKV) ext="mkv"; scodec=(-c:s srt);; esac
  [[ $ext == mp4 ]] && lang=$(lang3 "$lang")
  probe "$vid" || return 1
  EDUR=$DUR
  aenc=(-c:a copy)
  case $SRC_ACODEC in ""|none) aenc=(-an);; aac|mp3|ac3|eac3) ;; *) aenc=(-c:a aac -b:a 128k);; esac
  existing=$(count_subs "$vid")
  keepmaps=(-map '0:s?')
  subidx=$existing
  if (( existing > 0 )) && ! sub_codecs_ok "$vid"; then
    warn "Existing bitmap subtitles cannot be copied - only the new SRT is embedded."
    keepmaps=(); subidx=0
  fi
  base=$(basename -- "$vid"); base=${base%.*}
  out=$(unique_file "$(dirname -- "$vid")" "${base}_subbed" "$ext")
  mkdir -p "$CONF_DIR" 2>/dev/null
  if [[ $ext == mp4 ]]; then
    out_tmp "$out" "$(fsize "$vid")"; tmp=$OT_TMP
    fmt=(-f mp4); (( OT_DIRECT )) || fmt+=(-movflags +faststart)
  else
    tmp="$out.part"; OT_DIRECT=0
    fmt=(-f matroska)
  fi
  CUR_TMP=$tmp
  run_ffmpeg "subs" 1 1 -i "$vid" -i "$srt" -map 0:v:0 -map '0:a?' "${keepmaps[@]}" -map 1:0 \
    -c:v copy "${aenc[@]}" "${scodec[@]}" -metadata:s:s:$subidx language="$lang" \
    "${fmt[@]}" -max_muxing_queue_size 2048 "$tmp"
  rc=$?; CUR_TMP=""
  if (( rc == 0 )) && [[ -s $tmp ]] && commit_out "$tmp" "$out"; then
    ok "Subtitled file: $(pretty "$out")"
    command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
    yesno "Open it now?" n && open_file "$out"
    return 0
  fi
  rm -f -- "$tmp" 2>/dev/null
  err "Embedding failed."
  tail -n 5 "$LOG" >&2
  return 1
}

sub_burn() {   # $1 video -> burn SRT permanently into the picture (re-encode)
  local vid=$(readlink -f -- "$1") srt style mode sz col out base venc aenc tmp rc
  local -a bfast=()
  srt=$(resolve_srt "$vid") || { warn "Cancelled."; return 1; }
  echo " 1) Small white    2) Medium white (default)   3) Medium yellow   4) Large white"
  style=$(ask "Style" "2")
  case $style in
    1) sz=18; col="&H00FFFFFF";;
    3) sz=24; col="&H0000FFFF";;
    4) sz=32; col="&H00FFFFFF";;
    *) sz=24; col="&H00FFFFFF";;
  esac
  echo " 1) Fast (H.264 veryfast - quickest)"
  echo " 2) High quality (H.265 - recommended)"
  mode=$(ask "Encode mode" "2")
  probe "$vid" || return 1
  EDUR=$DUR
  aenc=(-c:a copy)
  case $SRC_ACODEC in ""|none) aenc=(-an);; aac|mp3|ac3|eac3) ;; *) aenc=(-c:a aac -b:a 128k);; esac
  base=$(basename -- "$vid"); base=${base%.*}
  out=$(unique_file "$(dirname -- "$vid")" "${base}_burned" "mp4")
  out_tmp "$out" "$(fsize "$vid")"; tmp=$OT_TMP; CUR_TMP=$tmp
  bfast=(-movflags +faststart); (( OT_DIRECT )) && bfast=()
  if [[ $mode == 1 ]]; then
    venc=(-c:v libx264 -preset veryfast -crf 21 -pix_fmt yuv420p)
  else
    venc=(-c:v libx265 -preset fast -crf 20 -tag:v hvc1 -pix_fmt yuv420p -x265-params log-level=error)
  fi
  TMPD=$(mktemp -d) || return 1
  cp -f -- "$srt" "$TMPD/sub.srt"
  mkdir -p "$CONF_DIR" 2>/dev/null
  info "Burning subtitles (this re-encodes the video)..."
  ( cd "$TMPD" && run_ffmpeg "burn" 1 1 -i "$vid" -map 0:v:0 -map '0:a?' \
      -vf "$(make_sub_filter "$sz" "$col")" "${venc[@]}" "${aenc[@]}" "${bfast[@]}" -f mp4 "$tmp" )
  rc=$?
  rm -rf "$TMPD"; TMPD=""
  CUR_TMP=""
  if (( rc == 0 )) && [[ -s $tmp ]] && commit_out "$tmp" "$out"; then
    ok "Burned file: $(pretty "$out")"
    command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
    yesno "Open it now?" n && open_file "$out"
    return 0
  fi
  rm -f -- "$tmp" 2>/dev/null
  err "Burn failed."
  tail -n 5 "$LOG" >&2
  return 1
}

sub_extract() {   # $1 video -> dump subtitle streams to .srt files
  local vid=$(readlink -f -- "$1") subs=() i c codec lang base dir out k sel=() suffix
  mapfile -t subs < <(ffprobe -v error -select_streams s -show_entries stream=codec_name:stream_tags=language -of csv=p=0 -- "$vid" 2>/dev/null)
  (( ${#subs[@]} == 0 )) && { warn "No subtitle streams in this file."; return 1; }
  echo "  Subtitle streams:"
  for i in "${!subs[@]}"; do
    IFS=, read -r codec lang <<<"${subs[i]}"
    printf ' %2d) %-12s lang: %s\n' $(( i + 1 )) "${codec:-?}" "${lang:--}"
  done
  c=$(ask "Number (a = extract all)" "1")
  base=$(basename -- "$vid"); base=${base%.*}
  dir=$(dirname -- "$vid")
  if [[ ${c,,} == a ]]; then sel=("${!subs[@]}")
  elif [[ $c =~ ^[0-9]+$ ]] && (( c >= 1 && c <= ${#subs[@]} )); then sel=( $(( c - 1 )) )
  else return 1; fi
  mkdir -p "$CONF_DIR" 2>/dev/null
  for k in "${sel[@]}"; do
    IFS=, read -r codec lang <<<"${subs[k]}"
    suffix=${lang:-track$(( k + 1 ))}
    out=$(unique_file "$dir" "${base}_${suffix}" "srt")
    if ffmpeg -nostdin -hide_banner -loglevel error -y -i "$vid" -map "0:s:$k" -c:s srt "$out" 2>>"$LOG"; then
      ok "Extracted: $(pretty "$out")"
    else
      err "Failed to extract stream $(( k + 1 ))."
    fi
  done
}

sub_remove() {   # $1 video -> drop all subtitle tracks (instant, no re-encode)
  local vid=$(readlink -f -- "$1") ext fmt out rc base tmp
  (( $(count_subs "$vid") > 0 )) || { warn "No subtitle streams in this file."; return 1; }
  ext="mp4"
  case ${vid##*.} in mkv|MKV) ext="mkv";; esac
  probe "$vid" || return 1
  EDUR=$DUR
  base=$(basename -- "$vid"); base=${base%.*}
  out=$(unique_file "$(dirname -- "$vid")" "${base}_nosub" "$ext")
  mkdir -p "$CONF_DIR" 2>/dev/null
  if [[ $ext == mp4 ]]; then
    out_tmp "$out" "$(fsize "$vid")"; tmp=$OT_TMP
    fmt=(-f mp4); (( OT_DIRECT )) || fmt+=(-movflags +faststart)
  else
    tmp="$out.part"; OT_DIRECT=0; fmt=(-f matroska)
  fi
  CUR_TMP=$tmp
  run_ffmpeg "subs" 1 1 -i "$vid" -map 0:v:0 -map '0:a?' -map '-0:s' -c:v copy -c:a copy "${fmt[@]}" "$tmp"
  rc=$?; CUR_TMP=""
  if (( rc == 0 )) && [[ -s $tmp ]] && commit_out "$tmp" "$out"; then
    ok "Clean file: $(pretty "$out")"
    command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
    yesno "Open it now?" n && open_file "$out"
    return 0
  fi
  rm -f -- "$tmp" 2>/dev/null
  err "Removing subtitles failed."
  tail -n 5 "$LOG" >&2
  return 1
}

sub_list() {   # $1 video -> show subtitle streams
  local vid=$(readlink -f -- "$1") i=0 codec lang
  while IFS=, read -r codec lang; do
    i=$(( i + 1 ))
    printf '  %d) %-12s lang: %s\n' "$i" "${codec:-?}" "${lang:--}"
  done < <(ffprobe -v error -select_streams s -show_entries stream=codec_name:stream_tags=language -of csv=p=0 -- "$vid" 2>/dev/null)
  (( i == 0 )) && warn "No subtitle streams."
  return 0
}

sub_studio() {
  local vid="" c
  while true; do
    clear_screen
    printf '%s== Subtitle Studio ==%s\n\n' "$C_B" "$C_0"
    if [[ -n $vid ]]; then printf ' Target: %s\n\n' "$(trunc "$(pretty "$vid")")"
    else printf ' Target: (none selected)\n\n'; fi
    echo " 1) Select target video"
    echo " 2) Embed SRT (soft subtitle - selectable, instant)"
    echo " 3) Burn SRT into video (permanent, re-encodes)"
    echo " 4) Extract subtitles to .srt files"
    echo " 5) Remove subtitle tracks (instant)"
    echo " 6) List subtitle streams"
    echo " b) back"
    read -r -p "> " c || return
    case $c in
      1) if pick_target; then vid=$PICK_RESULT; ok "Target: $(basename -- "$vid")"; fi;;
      2) [[ -n $vid ]] && sub_embed_soft "$vid"; pause;;
      3) [[ -n $vid ]] && sub_burn "$vid"; pause;;
      4) [[ -n $vid ]] && sub_extract "$vid"; pause;;
      5) [[ -n $vid ]] && sub_remove "$vid"; pause;;
      6) [[ -n $vid ]] && sub_list "$vid"; pause;;
      b|B|"") return;;
    esac
  done
}

# ================================================== REPAIR & SYNC (v2.1)
# For videos that play fine in VLC/MX Player but drift out of sync (or refuse
# to play) on TVs and USB players. Typical causes: variable frame rate, odd
# audio sample rates, TV-unsafe codecs, broken start timestamps, no faststart.

extract_subs_silent() {   # $1 video  $2 output path without extension
  local vid=$1 obase=$2 i=0 n=0 codec lang out skipped
  while IFS=, read -r codec lang; do
    i=$(( i + 1 ))
    case $codec in
      subrip|srt|ass|ssa|mov_text|webvtt|text|stl) ;;
      *) continue;;
    esac
    if (( n == 0 )); then out="$obase.srt"; else out="${obase}.${i}.srt"; fi
    if ffmpeg -nostdin -hide_banner -loglevel error -y -i "$vid" -map "0:s:$(( i - 1 ))" \
        -c:s srt "$out" 2>>"$LOG"; then
      n=$(( n + 1 )); ok "Subtitle extracted: $(basename -- "$out")${lang:+ ($lang)}"
    fi
  done < <(ffprobe -v error -select_streams s -show_entries stream=codec_name:stream_tags=language \
           -of csv=p=0 -- "$vid" 2>/dev/null)
  skipped=$(( $(count_subs "$vid") - n ))
  (( skipped > 0 )) && warn "$skipped bitmap subtitle track(s) cannot become .srt - skipped."
  (( n > 0 )) && info "Tip: keep the .srt next to the video - most TV players auto-load it."
  return 0
}


# ----------------------------------------------- repair helpers (v2.6) ------
keep_dates() { touch -r "$1" "$2" 2>/dev/null; return 0; }   # output keeps the original file time (gallery order)
space_check() {   # $1 destination dir  $2 bytes needed -> 0 = enough room (checked BEFORE a long job)
  local free
  free=$(free_bytes "$1")
  if [[ $free =~ ^[0-9]+$ ]] && (( free > 0 && free < $2 )); then
    err "Not enough free space in $(pretty "$1"): need about $(human "$2"), only $(human "$free") free."
    return 1
  fi
  return 0
}
repair_verify() {   # $1 output  $2 expected duration  $3 slack seconds  (needs diag_probe of the OUTPUT just done)
  local out=$1 exp=$2 slack=${3:-0} dd gap te
  local -a issues=()
  VERIFY_OK=1; VERIFY_NOTE=""
  dd=$(awk -v a="$D_DUR" -v b="$exp" 'BEGIN{ d = a - b; if (d < 0) d = -d; printf "%.2f", d }')
  if awk -v d="$dd" -v s="$slack" 'BEGIN{ exit !(d > 1.0 + s) }'; then issues+=("length differs from the original by ${dd}s"); fi
  if (( D_ANUM > 0 )) && [[ -n $D_VDUR && -n $D_ADUR ]]; then
    gap=$(awk -v a="$D_ADUR" -v v="$D_VDUR" 'BEGIN{ d = a - v; if (d < 0) d = -d; printf "%.2f", d }')
    if awk -v d="$gap" -v s="$slack" 'BEGIN{ exit !(d > 0.6 + s) }'; then issues+=("audio and video lengths differ by ${gap}s"); fi
  fi
  te=$(ffmpeg -nostdin -v error -sseof -4 -i "$out" -map 0:v:0 -an -f null - 2>&1 | head -n 2)
  [[ -n $te ]] && issues+=("the last seconds do not decode cleanly")
  if (( ${#issues[@]} )); then VERIFY_OK=0; VERIFY_NOTE=$(IFS=';'; printf '%s' "${issues[*]}"); fi
  return 0
}

repair_rescue_run() {   # called from repair_file: re-encode video + audio cleanly, skipping damaged data
  local -a rargs=()
  rargs=(-err_detect ignore_err -fflags +genpts+discardcorrupt+igndts -analyzeduration 200M -probesize 200M -i "$src" -map 0:v:0)
  (( has_audio > 0 )) && rargs+=(-map 0:a:0)
  rargs+=(-vf "$rvf" -c:v libx264 -preset "$REPAIR_PRESET" -crf "$REPAIR_CRF" -pix_fmt yuv420p -profile:v high)
  (( THREADS_PER_JOB > 0 )) && rargs+=(-threads "$THREADS_PER_JOB")
  (( has_audio > 0 )) && rargs+=(-af "aresample=48000:async=1" -c:a aac -b:a "${abr}k")
  rargs+=(-sn -map_metadata -1 -map_chapters -1 "${meta[@]}" -muxdelay 0 -avoid_negative_ts make_zero \
    "${fast[@]}" -max_muxing_queue_size 4096 -f mp4 "$tmp")
  run_ffmpeg "rescue" 1 1 "${rargs[@]}"
}
repair_file() {   # $1 src, $2 optional "[i/n] " tag -> TV-friendly MP4
  local src=$(readlink -f -- "$1") tag=${2:-}
  local name base dir out tmp rc t0=$SECONDS in_sz out_sz saved need tier
  local vfix=0 afix=0 vf="" fps_arg="" fps_show="" abr=192 vfps=0 stereo=""
  local vst ast b_timing b_ts b_vts b_vinfo b_ainfo b_fast b_gap n_vst n_ast n_gap negts=0 c
  local after_timing="?" after_ts="?" after_fast="?" nsubs extra_audio src_dur rescued=0 rstat rvf has_audio out2 vdone=0
  local -a vreasons=() areasons=() fargs=() venc=() aargs=() fast=() meta=()
  name=$(basename -- "$src"); in_sz=$(fsize "$src")
  if ! diag_probe "$src"; then
    err "${tag}Cannot read this video (damaged or not a video): $name"
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (unreadable)" "$src" ""
    tally fail; return 1
  fi
  diag_vfr_scan "$src"; diag_faststart "$src"
  src_dur=$D_DUR; has_audio=$D_ANUM
  [[ -n $D_CTIME ]] && meta=(-metadata "creation_time=$D_CTIME")
  case $D_TRC in smpte2084|arib-std-b67) warn "${tag}HDR video: converting to 8-bit SDR can look washed out. Keep the original if colours matter.";; esac
  vst=$(num_or0 "$D_VSTART"); ast=$(num_or0 "$D_ASTART")
  dir=$(dirname -- "$src"); base=${name%.*}
  printf '  %s%s%s %dx%d %s %s | %s fps, 1/%s | %s | %s%s\n' "$tag" "$C_D" "$(trunc "$name")" \
    "$D_W" "$D_H" "$D_VCODEC" "$D_PIX" "$(frac2dec "$D_AFPS")" \
    "$( (( D_VTS > 0 )) && echo "$D_VTS" || echo "?" )" "$(fmt_time "$D_DUR")" \
    "$(human "$in_sz")" "$C_0"

  # ---- decide what has to be fixed (re-encode ONLY what is broken)
  if (( D_ROUND )); then vfix=1; vreasons+=("rounded timestamps")
  elif (( D_VFR )); then vfix=1; vreasons+=("variable frame rate"); fi
  [[ $D_VCODEC != h264 ]] && { vfix=1; vreasons+=("codec $D_VCODEC"); }
  [[ $D_PIX != yuv420p ]] && { vfix=1; vreasons+=("pixel format $D_PIX"); }
  if (( D_W % 2 != 0 || D_H % 2 != 0 )); then vfix=1; vreasons+=("odd ${D_W}x${D_H} size"); fi
  if (( D_ANUM > 0 )); then
    case $D_ACODEC in aac|ac3|eac3) ;; *) afix=1; areasons+=("codec $D_ACODEC");; esac
    [[ $D_ARATE == 48000 ]] || { afix=1; areasons+=("${D_ARATE:-no} Hz sample rate"); }
    if (( REPAIR_STEREO && D_ACH > 2 )); then afix=1; areasons+=("${D_ACH}-channel audio"); fi
    (( D_ACH > 2 )) && abr=256
  fi
  [[ -n $REPAIR_FPS ]] && { vfix=1; vreasons+=("forced --fps"); }
  extra_audio=$(( D_ANUM > 1 ? D_ANUM - 1 : 0 ))
  nsubs=$D_NSUBS
  awk -v v="$vst" -v a="$ast" 'BEGIN{ if (v < -0.005 || a < -0.005) exit 1 }' || negts=1
  b_timing="CFR + exact ticks"
  (( D_ROUND )) && b_timing="CFR + rounded ticks"
  (( D_VFR && ! D_ROUND )) && b_timing="VFR (uneven)"
  b_ts="exact"; (( D_TSX == 0 )) && b_ts="uneven"; (( D_ROUND )) && b_ts="rounded"; (( D_TSX == -1 )) && b_ts="?"
  b_vts=$D_VTS
  b_vinfo="$D_VCODEC $D_PIX"
  b_ainfo="no audio"; (( D_ANUM > 0 )) && b_ainfo="$D_ACODEC ${D_ARATE} Hz"
  b_fast="faststart"; [[ $D_FAST == 0 ]] && b_fast="moov at end"
  [[ $D_FMT != mov ]] && b_fast="$D_FMT"
  b_gap=$(awk -v a="$ast" -v v="$vst" 'BEGIN{ d = a - v; if (d < 0) d = -d; printf "%d ms", d * 1000 }')

  if (( vfix == 0 && afix == 0 && D_FAST == 1 && negts == 0 )) && [[ $D_FMT == mov ]]; then
    ok "${tag}Already TV-friendly (H.264, constant rate, exact timestamps, safe audio, faststart) - nothing to do."
    add_result "$name" "$(human "$in_sz")" "-" "0%" "-" "NO FIX NEEDED" "$src" ""
    return 0
  fi

  # ---- speed tier: the cheapest fix that actually solves the problem
  tier="full rebuild (video + audio)"
  if   (( vfix == 0 && afix == 0 )); then tier="remux only - seconds, no re-encode"
  elif (( vfix == 0 && afix == 1 )); then tier="fast - audio rebuild only, video copied"
  elif (( D_ANUM == 0 || afix == 0 )); then tier="video rebuild, audio copied"
  fi

  # ---- constant frame rate target (snap to the nearest standard rate)
  if (( vfix )); then
    vfps=$D_FPSMED
    awk -v x="$vfps" 'BEGIN{ exit !(x + 0 > 1) }' || vfps=$(frac2dec "$D_AFPS")
    [[ -n $REPAIR_FPS ]] && vfps=$(frac2dec "$REPAIR_FPS")
    read -r fps_arg fps_show < <(snap_fps "$vfps")
    if (( REPAIR_OLDTV )) && awk -v x="$fps_show" 'BEGIN{ exit !(x > 30.5) }'; then
      fps_arg=30; fps_show="30.000"; info "Ultra-TV mode: frame rate capped at 30 fps."
    fi
    vf="fps=$fps_arg"
    if (( D_W % 2 != 0 || D_H % 2 != 0 )); then vf="scale=trunc(iw/2)*2:trunc(ih/2)*2,$vf"; fi
    case $D_FIELD in tt|bb|tb|bt) (( DEINT )) && { vf="yadif=mode=0:parity=-1:deint=1,$vf"; info "${tag}Interlaced picture - deinterlacing while re-encoding."; };; esac
  fi

  # ---- video filter RESCUE mode would need (target rate + even size), kept ready now
  rvf=$vf
  if [[ -z $rvf ]]; then
    vfps=$D_FPSMED
    awk -v x="$vfps" 'BEGIN{ exit !(x + 0 > 1) }' || vfps=$(frac2dec "$D_AFPS")
    read -r fps_arg fps_show < <(snap_fps "$vfps")
    rvf="fps=$fps_arg"
    if (( D_W % 2 != 0 || D_H % 2 != 0 )); then rvf="scale=trunc(iw/2)*2:trunc(ih/2)*2,$rvf"; fi
    case $D_FIELD in tt|bb|tb|bt) (( DEINT )) && rvf="yadif=mode=0:parity=-1:deint=1,$rvf";; esac
  fi

  # ---- plan + confirmation (interactive mode only)
  if (( REPAIR_AUTO == 0 )); then
    while true; do
      printf '\n%s== Repair plan ==%s\n' "$C_B" "$C_0"
      printf '  Mode  : %s\n' "$tier"
      if (( vfix )); then
        printf '  Video : %sre-encode%s H.264 %s profile, CRF %s @ %s, %s fps%s\n' "$C_Y" "$C_0" \
          "$( (( REPAIR_OLDTV )) && echo Main || echo High )" "$REPAIR_CRF" "$REPAIR_PRESET" "$fps_show" \
          "$( [[ $REPAIR_PRESET == veryfast && $REPAIR_CRF == 16 ]] && printf ' (turbo: = CRF 18 @ medium quality, ~2x faster)' )"
        printf '         fixes : %s\n' "$(IFS=', '; printf '%s' "${vreasons[*]}")"
      else
        printf '  Video : %sstream copy%s (already fine - no quality loss)\n' "$C_G" "$C_0"
      fi
      if (( D_ANUM == 0 )); then
        printf '  Audio : (file has no audio)\n'
      elif (( afix )); then
        (( REPAIR_STEREO && D_ACH > 2 )) && stereo=", stereo"
        printf '  Audio : %sre-encode%s AAC %s kbps, 48000 Hz%s\n' "$C_Y" "$C_0" "$abr" "$stereo"
        printf '         fixes : %s\n' "$(IFS=', '; printf '%s' "${areasons[*]}")"
      else
        printf '  Audio : %sstream copy%s (already fine - no quality loss)\n' "$C_G" "$C_0"
      fi
      printf '  Output: MP4 + faststart + exact frame timestamps\n'
      printf '          built on fast local storage, moved here when done\n'
      (( extra_audio > 0 )) && printf '          %d extra audio track(s) will be dropped\n' "$extra_audio"
      (( nsubs > 0 )) && printf '  Subs  : %d track(s) saved as .srt next to the video\n' "$nsubs"
      printf '  y) start    q) change quality    b) cancel\n'
      read -r -p "> " c || return 1
      case ${c,,} in
        y|"") break;;
        b) return 1;;
        q) REPAIR_CRF=$(ask_int "CRF quality (10-28; 16 turbo = 18 medium quality)" 10 28 "$REPAIR_CRF")
           REPAIR_PRESET=$(ask "Encoder speed (ultrafast..veryslow)" "$REPAIR_PRESET");;
      esac
    done
  else
    info "${tag}Plan: $tier$( (( vfix )) && printf ' - %s' "$(IFS=', '; printf '%s' "${vreasons[*]}")" )$( (( afix && D_ANUM > 0 )) && printf ' + audio fix' )$( (( extra_audio > 0 )) && printf ' (+%d extra audio track(s) dropped)' "$extra_audio" )"
  fi

  # ---- run the repair (output is BUILT on fast local storage first, so
  #      ffmpeg's faststart index shift can never fail on Android storage)
  out=$(unique_file "$dir" "${base}_repaired" "mp4")
  need=$(( in_sz + 65536 ))
  (( vfix )) && need=$(( in_sz * 3 / 4 + 1048576 ))
  if ! space_check "$dir" "$need"; then
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (no space)" "$src" ""
    tally fail; return 1
  fi
  out_tmp "$out" "$need"; tmp=$OT_TMP; CUR_TMP=$tmp
  fast=(-movflags +faststart); (( OT_DIRECT )) && fast=()
  mkdir -p "$CONF_DIR" 2>/dev/null
  EDUR=$D_DUR
  fargs=(-fflags +genpts -i "$src" -map 0:v:0)
  (( D_ANUM > 0 )) && fargs+=(-map 0:a:0)
  if (( vfix )); then
    if (( REPAIR_OLDTV )); then
      venc=(-c:v libx264 -preset "$REPAIR_PRESET" -crf "$REPAIR_CRF" -pix_fmt yuv420p -profile:v main -bf 0)
    else
      venc=(-c:v libx264 -preset "$REPAIR_PRESET" -crf "$REPAIR_CRF" -pix_fmt yuv420p -profile:v high)
    fi
    (( THREADS_PER_JOB > 0 )) && venc+=(-threads "$THREADS_PER_JOB")
    fargs+=(-vf "$vf" "${venc[@]}")
  else
    fargs+=(-c:v copy)
  fi
  if (( D_ANUM > 0 )); then
    if (( afix )); then
      aargs=(-af "aresample=48000:async=1" -c:a aac -b:a "${abr}k")
      (( REPAIR_STEREO && D_ACH > 2 )) && aargs+=(-ac 2)
    else
      aargs=(-c:a copy)
    fi
    fargs+=("${aargs[@]}")
  fi
  # no forced timescale: ffmpeg writes an exact 1/fps base (e.g. 1/24000 with
  # uniform 1001-tick frames) - the old forced 90000 planted rounding on
  # 23.976 fps films, which itself caused gradual drift on TVs
  fargs+=(-sn -map_metadata -1 -map_chapters -1 "${meta[@]}" -muxdelay 0 -avoid_negative_ts make_zero \
    "${fast[@]}" -max_muxing_queue_size 4096 -f mp4 "$tmp")
  run_ffmpeg "repair" 1 1 "${fargs[@]}"
  rc=$?
  if (( rc != 0 )) || [[ ! -s $tmp ]]; then
    # ---- RESCUE MODE: damaged data -> skip it and rebuild video + audio cleanly
    rm -f -- "$tmp"
    warn "${tag}First attempt failed - trying RESCUE mode (re-encodes everything, skips damaged data)."
    rescued=1
    repair_rescue_run
    rc=$?
  fi
  CUR_TMP=""
  if (( rc != 0 )) || [[ ! -s $tmp ]]; then
    err "${tag}Repair failed even in rescue mode (ffmpeg exit $rc). Last log lines:"
    tail -n 6 "${LOGF:-$LOG}" | sed 's/^/    /' >&2
    rm -f -- "$tmp"
    add_result "$name" "$(human "$in_sz")" "-" "-" "$(fmt_time $(( SECONDS - t0 )))" "FAILED" "$src" ""
    tally fail
    return 1
  fi
  if ! commit_out "$tmp" "$out"; then
    err "${tag}Could not move the repaired file into place - is the destination writable?"
    add_result "$name" "$(human "$in_sz")" "-" "-" "$(fmt_time $(( SECONDS - t0 )))" "FAILED (move)" "$src" ""
    tally fail
    return 1
  fi
  keep_dates "$src" "$out"
  # ---- pre-check: a stream-copied/remuxed file keeps any damage - escalate to RESCUE once
  if (( rescued == 0 )); then
    VERIFY_OK=0
    if diag_probe "$out"; then repair_verify "$out" "$src_dur"; fi
    (( VERIFY_OK )) && vdone=1
    if (( ! VERIFY_OK )); then
      warn "${tag}The result did not pass the check ($VERIFY_NOTE) - rebuilding in RESCUE mode."
      out2=$(unique_file "$dir" "${base}_repaired" "mp4")
      out_tmp "$out2" "$(( in_sz * 3 / 4 + 1048576 ))"; tmp=$OT_TMP; CUR_TMP=$tmp
      fast=(-movflags +faststart); (( OT_DIRECT )) && fast=()
      repair_rescue_run; rc=$?
      CUR_TMP=""
      if (( rc == 0 )) && [[ -s $tmp ]] && commit_out "$tmp" "$out2"; then
        rm -f -- "$out"; mv -f -- "$out2" "$out"; keep_dates "$src" "$out"; rescued=1
      else
        warn "${tag}Rescue mode could not improve it - keeping the first result."
        rm -f -- "$tmp" "$out2"
      fi
    fi
  fi
  (( nsubs > 0 )) && extract_subs_silent "$src" "${out%.*}"
  out_sz=$(fsize "$out")

  # ---- verify: show what changed, and check the result really is sound
  VERIFY_OK=0; VERIFY_NOTE="the repaired file cannot be read back"
  if diag_probe "$out" && diag_vfr_scan "$out" && diag_faststart "$out"; then
    if (( vdone )); then VERIFY_OK=1; VERIFY_NOTE=""; else repair_verify "$out" "$src_dur"; fi
    n_vst=$(num_or0 "$D_VSTART"); n_ast=$(num_or0 "$D_ASTART")
    n_gap=$(awk -v a="$n_ast" -v v="$n_vst" 'BEGIN{ d = a - v; if (d < 0) d = -d; printf "%d", d * 1000 }')
    after_timing="CFR + exact ticks"
    (( D_ROUND )) && after_timing="${C_R}still rounded!${C_0}"
    (( D_VFR && ! D_ROUND )) && after_timing="${C_R}still uneven!${C_0}"
    after_ts="exact (1/$D_VTS)"
    (( D_TSX == 0 )) && after_ts="uneven (1/$D_VTS)"
    (( D_TSX == -1 )) && after_ts="?"
    (( D_FAST == 1 )) && after_fast="faststart"
    printf '\n  %s-------------- before -> after --------------%s\n' "$C_D" "$C_0"
    printf '  %-14s %-24s -> %s\n' "Frame timing" "$b_timing" "$after_timing"
    printf '  %-14s %-24s -> %s\n' "Timestamps" "${b_ts} (1/$b_vts)" "$after_ts"
    printf '  %-14s %-24s -> %s\n' "Video" "$b_vinfo" "$D_VCODEC $D_PIX"
    printf '  %-14s %-24s -> %s\n' "Audio" "$b_ainfo" \
      "$( (( D_ANUM == 0 )) && echo "no audio" || echo "$D_ACODEC $D_ARATE Hz")"
    printf '  %-14s %-24s -> %s\n' "MP4 index" "$b_fast" "$after_fast"
    printf '  %-14s %-24s -> %s\n' "A/V start gap" "$b_gap" "${n_gap} ms"
    if (( n_gap > 150 )); then
      info "Audio starts $n_gap ms after the video - if lips look late, run:"
      info "  vc --sync-shift -$n_gap $(basename -- "$out")"
    fi
  fi
  saved=$(awk -v a="$in_sz" -v b="$out_sz" 'BEGIN{ if (a+0<=0) { print "0%"; exit }
    d=(1-b/a)*100; printf "%s%.0f%%", (d>=0 ? "-" : "+"), (d>=0 ? d : -d) }')
  rstat="REPAIRED"; (( rescued )) && rstat="REPAIRED (rescue)"
  if (( VERIFY_OK )); then
    ok "${tag}Repaired + verified: $(basename -- "$out")  $(human "$in_sz") -> $(human "$out_sz")  (${saved}, $(fmt_time $(( SECONDS - t0 ))))"
  else
    warn "${tag}Repaired, but please CHECK the result: $VERIFY_NOTE"
    rstat="REPAIRED (CHECK)"
  fi
  (( rescued )) && info "  Rescue mode skipped damaged data: a few frames may be missing - watch the result once."
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
  add_result "$name" "$(human "$in_sz")" "$(human "$out_sz")" "${saved}" "$(fmt_time $(( SECONDS - t0 )))" "$rstat" "$src" "$out"
  tally ok "$in_sz" "$out_sz"
  if (( REPAIR_AUTO == 0 )); then yesno "Open it now?" n && open_file "$out"; fi
  return 0
}

quickfix_file() {   # $1 src, $2 optional tag -> remux to a clean faststart MP4 (seconds)
  local src=$(readlink -f -- "$1") tag=${2:-}
  local name base dir out tmp rc t0=$SECONDS in_sz out_sz nsubs src_dur qstat
  local s_round s_vfr s_vcodec s_acodec s_arate s_anum
  local -a fargs=() fast=() meta=()
  name=$(basename -- "$src"); in_sz=$(fsize "$src")
  if ! diag_probe "$src"; then
    err "${tag}Cannot read this video (damaged or not a video): $name"
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (unreadable)" "$src" ""
    tally fail; return 1
  fi
  diag_vfr_scan "$src"
  src_dur=$D_DUR; nsubs=$D_NSUBS
  s_round=$D_ROUND; s_vfr=$D_VFR; s_vcodec=$D_VCODEC; s_acodec=$D_ACODEC; s_arate=$D_ARATE; s_anum=$D_ANUM
  [[ -n $D_CTIME ]] && meta=(-metadata "creation_time=$D_CTIME")
  dir=$(dirname -- "$src"); base=${name%.*}
  printf '  %s%s%s %dx%d %s %s | %s | %s%s\n' "$tag" "$C_D" "$(trunc "$name")" \
    "$D_W" "$D_H" "$D_VCODEC" "$D_PIX" "$(fmt_time "$D_DUR")" "$(human "$in_sz")" "$C_0"
  out=$(unique_file "$dir" "${base}_fixed" "mp4")
  if ! space_check "$dir" "$(( in_sz + 1048576 ))"; then
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (no space)" "$src" ""
    tally fail; return 1
  fi
  out_tmp "$out" "$(( in_sz + 65536 ))"; tmp=$OT_TMP; CUR_TMP=$tmp
  fast=(-movflags +faststart); (( OT_DIRECT )) && fast=()
  EDUR=$D_DUR
  mkdir -p "$CONF_DIR" 2>/dev/null
  fargs=(-fflags +genpts -i "$src" -map 0:v:0)
  (( s_anum > 0 )) && fargs+=(-map 0:a:0)
  fargs+=(-c copy -sn -map_metadata -1 -map_chapters -1 "${meta[@]}" -muxdelay 0 -avoid_negative_ts make_zero \
    "${fast[@]}" -max_muxing_queue_size 4096 -f mp4 "$tmp")
  run_ffmpeg "quickfix" 1 1 "${fargs[@]}"
  rc=$?; CUR_TMP=""
  if (( rc != 0 )) || [[ ! -s $tmp ]]; then
    err "${tag}Quick fix failed (ffmpeg exit $rc). Last log lines:"
    tail -n 6 "${LOGF:-$LOG}" | sed 's/^/    /' >&2
    rm -f -- "$tmp"
    add_result "$name" "$(human "$in_sz")" "-" "-" "$(fmt_time $(( SECONDS - t0 )))" "FAILED (try Auto-Repair)" "$src" ""
    tally fail
    return 1
  fi
  if ! commit_out "$tmp" "$out"; then
    err "${tag}Could not move the fixed file into place."
    add_result "$name" "$(human "$in_sz")" "-" "-" "$(fmt_time $(( SECONDS - t0 )))" "FAILED (move)" "$src" ""
    tally fail
    return 1
  fi
  keep_dates "$src" "$out"
  (( nsubs > 0 )) && extract_subs_silent "$src" "${out%.*}"
  out_sz=$(fsize "$out")
  qstat="QUICKFIXED"
  VERIFY_OK=0; VERIFY_NOTE="the fixed file cannot be read back"
  if diag_probe "$out"; then repair_verify "$out" "$src_dur"; fi
  if (( VERIFY_OK )); then
    ok "${tag}Fixed + verified: $(basename -- "$out")  $(human "$in_sz") -> $(human "$out_sz")  ($(fmt_time $(( SECONDS - t0 ))))"
  else
    warn "${tag}Fixed, but please CHECK the result: $VERIFY_NOTE"; qstat="QUICKFIXED (CHECK)"
  fi
  (( s_round )) && warn "Timestamps are still rounded (gradual TV drift) - run Auto-Repair to rebuild them."
  (( s_vfr && ! s_round )) && warn "Video is still variable frame rate - run Auto-Repair to stop the drift."
  [[ $s_vcodec != h264 ]] && warn "Video codec kept as '$s_vcodec' - run Auto-Repair to convert to H.264."
  if (( s_anum > 0 )); then
    case $s_acodec in aac|ac3|eac3) ;; *) warn "Audio codec kept as '$s_acodec' - run Auto-Repair to convert to AAC.";; esac
    [[ $s_arate == 48000 ]] || warn "Audio kept at ${s_arate:-?} Hz - run Auto-Repair to resample to 48 kHz."
  fi
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
  add_result "$name" "$(human "$in_sz")" "$(human "$out_sz")" "0%" "$(fmt_time $(( SECONDS - t0 )))" "$qstat" "$src" "$out"
  tally ok "$in_sz" "$out_sz"
  if (( REPAIR_AUTO == 0 )); then yesno "Open it now?" n && open_file "$out"; fi
  return 0
}

sync_shift_file() {   # $1 src  $2 milliseconds (positive = delay the audio)
  local src=$(readlink -f -- "$1") ms=$2 off name base dir out tmp rc t0=$SECONDS in_sz out_sz nsubs src_dur sstat slack
  local -a aargs=() fast=() meta=()
  name=$(basename -- "$src"); in_sz=$(fsize "$src")
  [[ $ms =~ ^-?[0-9]+$ ]] || { err "Shift must be a number of milliseconds (e.g. 250 or -250)."; return 1; }
  (( ms == 0 )) && { err "A shift of 0 ms does nothing."; return 1; }
  (( ms > 10000 || ms < -10000 )) && { err "Use a shift between -10000 and 10000 ms."; return 1; }
  if ! diag_probe "$src"; then
    err "Cannot read this video (damaged or not a video): $name"
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (unreadable)" "$src" ""
    tally fail; return 1
  fi
  if (( D_ANUM == 0 )); then
    err "This file has no audio track: $name"
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (no audio)" "$src" ""
    tally fail; return 1
  fi
  src_dur=$D_DUR; nsubs=$D_NSUBS
  [[ -n $D_CTIME ]] && meta=(-metadata "creation_time=$D_CTIME")
  off=$(awk -v m="$ms" 'BEGIN{ printf "%.3f", m / 1000 }')
  slack=$(awk -v m="$ms" 'BEGIN{ if (m < 0) m = -m; printf "%.3f", m / 1000 }')
  base=${name%.*}; dir=$(dirname -- "$src")
  if (( ms > 0 )); then info "Delaying audio by ${ms} ms (audio was too early)."
  else info "Advancing audio by ${ms#-} ms (audio was too late)."; fi
  case $D_ACODEC in
    aac|mp3|ac3|eac3) aargs=(-c:a copy);;
    *) aargs=(-c:a aac -b:a 192k -af "aresample=async=1")
       warn "Audio re-encoded to AAC ('$D_ACODEC' is not safe in MP4).";;
  esac
  out=$(unique_file "$dir" "${base}_shifted" "mp4")
  if ! space_check "$dir" "$(( in_sz + 1048576 ))"; then
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (no space)" "$src" ""
    tally fail; return 1
  fi
  out_tmp "$out" "$(( in_sz + 65536 ))"; tmp=$OT_TMP; CUR_TMP=$tmp
  fast=(-movflags +faststart); (( OT_DIRECT )) && fast=()
  EDUR=$D_DUR
  mkdir -p "$CONF_DIR" 2>/dev/null
  run_ffmpeg "shift" 1 1 -i "$src" -itsoffset "$off" -i "$src" \
    -map 0:v:0 -map 1:a:0 -c:v copy "${aargs[@]}" -sn -map_metadata -1 "${meta[@]}" \
    -avoid_negative_ts make_zero -muxdelay 0 "${fast[@]}" \
    -max_muxing_queue_size 4096 -f mp4 "$tmp"
  rc=$?; CUR_TMP=""
  if (( rc != 0 )) || [[ ! -s $tmp ]]; then
    err "Audio shift failed (ffmpeg exit $rc). Last log lines:"
    tail -n 6 "${LOGF:-$LOG}" | sed 's/^/    /' >&2
    rm -f -- "$tmp"
    add_result "$name" "$(human "$in_sz")" "-" "-" "$(fmt_time $(( SECONDS - t0 )))" "FAILED" "$src" ""
    tally fail
    return 1
  fi
  if ! commit_out "$tmp" "$out"; then
    err "Could not move the shifted file into place."
    add_result "$name" "$(human "$in_sz")" "-" "-" "$(fmt_time $(( SECONDS - t0 )))" "FAILED (move)" "$src" ""
    tally fail
    return 1
  fi
  keep_dates "$src" "$out"
  (( nsubs > 0 )) && extract_subs_silent "$src" "${out%.*}"
  out_sz=$(fsize "$out")
  sstat="SHIFTED"
  VERIFY_OK=0; VERIFY_NOTE="the shifted file cannot be read back"
  if diag_probe "$out"; then
    ok "New start times - video: $(num_or0 "$D_VSTART") s, audio: $(num_or0 "$D_ASTART") s"
    repair_verify "$out" "$(awk -v d="$src_dur" -v o="$off" 'BEGIN{ printf "%.3f", d + ((o > 0) ? o : 0) }')" "$slack"
  fi
  if (( VERIFY_OK )); then ok "Shifted + verified: $(pretty "$out")  ($(human "$in_sz") -> $(human "$out_sz"))"
  else warn "Shifted, but please CHECK the result: $VERIFY_NOTE"; sstat="SHIFTED (CHECK)"; fi
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
  add_result "$name" "$(human "$in_sz")" "$(human "$out_sz")" "0%" "$(fmt_time $(( SECONDS - t0 )))" "$sstat" "$src" "$out"
  tally ok "$in_sz" "$out_sz"
  if (( REPAIR_AUTO == 0 )); then yesno "Open it now?" n && open_file "$out"; fi
  return 0
}

shift_audio_dialog() {   # $1 video
  local ms
  echo " Positive = delay the audio (sound is too early)."
  echo " Negative = advance the audio (sound is too late)."
  echo " Example: 250    or    -250"
  ms=$(ask "Shift audio by (ms)" "")
  [[ -n $ms ]] && sync_shift_file "$1" "$ms"
  return 0
}

queue_run() {   # $1 label  $2 function(src, tag): runs it over the WHOLE queue, one after another (or -j in parallel)
  local label=$1 fn=$2
  (( ${#SELECTED[@]} )) || { err "No videos selected."; return 1; }
  local prev_auto=$REPAIR_AUTO
  REPAIR_AUTO=1
  mkdir -p "$CONF_DIR"; : > "$LOG"
  RESULTS=(); N_OK=0; N_FAIL=0; TOTAL_IN=0; TOTAL_OUT=0; BATCH_T0=$SECONDS
  BATCH_TMP=$(mktemp -d) || { err "Cannot create temp dir."; REPAIR_AUTO=$prev_auto; return 1; }
  wake_lock
  [[ -z $VC_NOSTAGE ]] && stage_root   # one shared build area: parallel children inherit it
  detect_ff_caps
  local i=0 n=${#SELECTED[@]} f st a b running=0
  (( n > 1 )) && calc_threads "$PARALLEL_JOBS" || calc_threads 1
  if (( PARALLEL_JOBS > 1 && n > 1 )); then
    info "$label: up to $PARALLEL_JOBS files at once ($n total, $THREADS_PER_JOB threads each)"
    for f in "${SELECTED[@]}"; do
      i=$(( i + 1 ))
      while (( running >= PARALLEL_JOBS )); do wait -n || true; running=$(( running - 1 )); done
      printf '%s[%d/%d] %s%s\n' "$C_B" "$i" "$n" "$(trunc "$(basename -- "$f")")" "$C_0"
      (
        SIMPLE=1 LOGF="$BATCH_TMP/log_$i" STATS="$BATCH_TMP/stats" RESULT_FILE="$BATCH_TMP/results"
        REPAIR_AUTO=1 "$fn" "$f" "[$i/$n] "
      ) &
      running=$(( running + 1 ))
    done
    wait
    [[ -f $BATCH_TMP/results ]] && mapfile -t RESULTS < "$BATCH_TMP/results"
    if [[ -f $BATCH_TMP/stats ]]; then
      while read -r st a b; do
        case $st in
          ok)   N_OK=$(( N_OK + 1 )); TOTAL_IN=$(( TOTAL_IN + a )); TOTAL_OUT=$(( TOTAL_OUT + b ));;
          fail) N_FAIL=$(( N_FAIL + 1 ));;
        esac
      done < "$BATCH_TMP/stats"
    fi
    cat "$BATCH_TMP"/log_* >> "$LOG" 2>/dev/null
  else
    for f in "${SELECTED[@]}"; do
      i=$(( i + 1 ))
      printf '\n%s== %s [%d/%d]: %s ==%s\n' "$C_B" "$label" "$i" "$n" "$(basename -- "$f")" "$C_0"
      "$fn" "$f" "[$i/$n] " || true
      printf '  %s%d of %d done  (ok %d, failed %d)%s\n' "$C_D" "$i" "$n" "$N_OK" "$N_FAIL" "$C_0"
    done
  fi
  rm -rf "$BATCH_TMP"; BATCH_TMP=""
  wake_unlock
  print_summary
  notify "$label finished: $N_OK ok, $N_FAIL failed"
  REPAIR_AUTO=$prev_auto
  (( N_FAIL == 0 ))
}
repair_batch() { queue_run "Repair" repair_file; }
q_shift()      { sync_shift_file "$1" "$QUEUE_MS"; }
ask_shift_ms() {   # asks ONCE -> QUEUE_MS (valid, non-zero) ; 1 = cancelled
  local ms
  echo " Positive = delay the audio (sound is too early)."
  echo " Negative = advance the audio (sound is too late)."
  echo " Example: 250    or    -250        (applies to every queued video)"
  ms=$(ask "Shift audio by (ms)" "")
  [[ $ms =~ ^-?[0-9]+$ ]] && (( ms != 0 && ms >= -10000 && ms <= 10000 )) || { [[ -n $ms ]] && warn "Use a whole number of ms between -10000 and 10000, not 0."; return 1; }
  QUEUE_MS=$ms
}
diag_queue() {   # diagnose every queued video; offers to repair exactly the ones with problems
  local f i=0 n=${#SELECTED[@]} brief=0 np pr bad=0 good=0 unread=0
  local -a fix=() saved=()
  (( n > 3 )) && brief=1
  for f in "${SELECTED[@]}"; do
    i=$(( i + 1 ))
    if (( brief )); then
      diag_report "$f" >/dev/null 2>&1; np=$DIAG_NPROBS
      if   (( np < 0 )); then printf ' %s[%d/%d]%s %s✘%s %s - cannot be read\n' "$C_D" "$i" "$n" "$C_0" "$C_R" "$C_0" "$(trunc "$(basename -- "$f")")"; unread=$(( unread + 1 ))
      elif (( np == 0 )); then printf ' %s[%d/%d]%s %s✔%s %s - ok\n' "$C_D" "$i" "$n" "$C_0" "$C_G" "$C_0" "$(trunc "$(basename -- "$f")")"; good=$(( good + 1 ))
      else
        printf ' %s[%d/%d]%s %s!%s %s - %d problem(s)\n' "$C_D" "$i" "$n" "$C_0" "$C_Y" "$C_0" "$(trunc "$(basename -- "$f")")" "$np"
        for pr in "${DIAG_PROBS[@]}"; do printf '          %s%s%s\n' "$C_D" "$(trunc "$pr")" "$C_0"; done
        fix+=("$f"); bad=$(( bad + 1 ))
      fi
    else
      diag_report "$f" || true; np=$DIAG_NPROBS
      if   (( np < 0 )); then unread=$(( unread + 1 ))
      elif (( np == 0 )); then good=$(( good + 1 ))
      else fix+=("$f"); bad=$(( bad + 1 )); fi
    fi
  done
  (( n > 1 )) && printf '\n%s== Diagnosis finished ==%s  %d ok, %d need repair, %d unreadable\n' "$C_B" "$C_0" "$good" "$bad" "$unread"
  if (( bad > 0 )) && [[ -t 0 ]] && yesno "Auto-repair the $bad video(s) with problems now, one after another?" y; then
    saved=("${SELECTED[@]}"); SELECTED=("${fix[@]}")
    repair_batch
    SELECTED=("${saved[@]}")
  fi
  return 0
}
need_queue() {   # opens the finder when the queue is empty
  (( ${#SELECTED[@]} )) || find_videos multi
  (( ${#SELECTED[@]} )) || { warn "Nothing selected."; sleep 1; return 1; }
}

queue_pick() {   # $1 label -> PICKED = the chosen part of the queue (one, several or all). 1 = cancelled
  local label=$1 n=${#SELECTED[@]} i ans tok lo hi k added
  local -A got=()
  PICKED=()
  (( n == 0 )) && return 1
  if (( n == 1 )) || ! [[ -t 0 && -t 1 ]]; then PICKED=("${SELECTED[@]}"); return 0; fi
  printf '\n%s%s%s - which of your %d queued videos?\n' "$C_B" "$label" "$C_0" "$n"
  for (( i = 0; i < n && i < 30; i++ )); do
    fsize_v "${SELECTED[i]}"
    printf ' %2d) %8s  %s\n' $(( i + 1 )) "$(human "$FSZ")" "$(trunc "$(basename -- "${SELECTED[i]}")")"
  done
  (( n > 30 )) && printf '  %s... %d more (their numbers work too)%s\n' "$C_D" $(( n - 30 )) "$C_0"
  echo " a or Enter = ALL     one number = just that video"
  echo " several: 1 3 5-7     b = cancel"
  while true; do
    read -r -p "> " ans || return 1
    ans=${ans//,/ }
    case ${ans,,} in
      ""|a|all) PICKED=("${SELECTED[@]}"); return 0;;
      b|0|q) return 1;;
    esac
    got=(); PICKED=(); added=0
    for tok in $ans; do
      if   [[ $tok =~ ^[0-9]+$ ]]; then lo=$tok; hi=$tok
      elif [[ $tok =~ ^([0-9]+)-([0-9]+)$ ]]; then lo=${BASH_REMATCH[1]}; hi=${BASH_REMATCH[2]}
      else continue; fi
      for (( k = lo; k <= hi; k++ )); do
        if (( k >= 1 && k <= n )) && [[ -z ${got[$k]-} ]]; then got[$k]=1; PICKED+=("${SELECTED[k-1]}"); added=$(( added + 1 )); fi
      done
    done
    (( added > 0 )) && return 0
    warn "Type a (all), one number, or several like 1 3 5-7."
  done
}
run_on_picked() {   # $1 label, rest = command; runs it with the queue temporarily narrowed to the picked videos
  local label=$1 rc
  shift
  queue_pick "$label" || return 1
  local -a saved=("${SELECTED[@]}")
  SELECTED=("${PICKED[@]}")
  "$@"; rc=$?
  SELECTED=("${saved[@]}")
  return $rc
}
_rm_repair() { if (( ${#SELECTED[@]} == 1 )); then repair_file "${SELECTED[0]}"; else repair_batch; fi; }
_rm_quick()  { if (( ${#SELECTED[@]} == 1 )); then REPAIR_AUTO=0 quickfix_file "${SELECTED[0]}"; else queue_run "Quick fix" quickfix_file; fi; }
_rm_shift()  {
  ask_shift_ms || return 1
  if (( ${#SELECTED[@]} == 1 )); then sync_shift_file "${SELECTED[0]}" "$QUEUE_MS"; else queue_run "Audio shift" q_shift; fi
}
tool_on_queue() {   # $1 function (uses pick_target)  $2 label: one video, several or all of the queue
  local fn=$1 label=$2 n f i=0 okc=0 failc=0 rc
  local -a failed=()
  if (( ${#SELECTED[@]} == 0 )) && [[ -t 0 && -t 1 ]]; then
    info "$label: pick the videos (a = all of them, numbers, or type a name)"
    find_videos multi
  fi
  (( ${#SELECTED[@]} )) || { warn "Nothing selected."; return 1; }
  queue_pick "$label" || return 1
  n=${#PICKED[@]}
  if (( n == 1 )); then
    FORCE_TARGET=${PICKED[0]}; "$fn"; rc=$?; FORCE_TARGET=""
    return $rc
  fi
  info "$n videos, one after another - the same settings are used for each (asked once)."
  ASK_MEMO_DIR=$(mktemp -d) || { ASK_MEMO_DIR=""; err "Cannot create temp dir."; return 1; }
  wake_lock
  for f in "${PICKED[@]}"; do
    i=$(( i + 1 ))
    printf '\n%s== %s [%d/%d]: %s ==%s\n' "$C_B" "$label" "$i" "$n" "$(basename -- "$f")" "$C_0"
    FORCE_TARGET=$f
    if "$fn"; then okc=$(( okc + 1 )); else failc=$(( failc + 1 )); failed+=("$(basename -- "$f")"); fi
  done
  FORCE_TARGET=""; rm -rf -- "$ASK_MEMO_DIR"; ASK_MEMO_DIR=""
  wake_unlock
  printf '\n%s== %s finished ==%s  %d ok, %d failed\n' "$C_B" "$label" "$C_0" "$okc" "$failc"
  for f in "${failed[@]}"; do printf '   %s✘%s %s\n' "$C_R" "$C_0" "$f"; done
  notify "$label finished: $okc ok, $failc failed"
  return 0
}

repair_menu() {
  local c n i
  while true; do
    clear_screen
    n=${#SELECTED[@]}
    printf '%s== Repair & Sync ==%s\n\n' "$C_B" "$C_0"
    if (( n == 0 )); then printf ' Queue: empty - press 1 to choose videos\n'
    elif (( n == 1 )); then printf ' Queue: %s\n' "$(trunc "$(pretty "${SELECTED[0]}")")"
    else
      printf ' Queue: %d videos - handled one after another, automatically\n' "$n"
      for (( i = 0; i < n && i < 4; i++ )); do printf '   %s- %s%s\n' "$C_D" "$(trunc "$(basename -- "${SELECTED[i]}")")" "$C_0"; done
      (( n > 4 )) && printf '   %s... and %d more%s\n' "$C_D" $(( n - 4 )) "$C_0"
    fi
    printf ' Fixes audio/video drift and playback problems on TVs & USB players.\n\n'
    echo " 1) Choose videos (add to the queue)"
    echo " 2) Diagnose (find out which ones need fixing)"
    echo " 3) Auto-Repair (fixes only what is broken)"
    echo " 4) Quick fix (seconds each, no re-encode)"
    echo " 5) Shift audio by +/- milliseconds"
    echo "    (2-5 ask which of the queued videos: one, several or all)"
    echo " 6) View / edit the queue"
    echo " b) back"
    read -r -p "> " c || return
    case $c in
      1) find_videos multi;;
      2) need_queue && { run_on_picked "Diagnose" diag_queue; pause; };;
      3) need_queue && { run_on_picked "Auto-Repair" _rm_repair; pause; };;
      4) need_queue && { run_on_picked "Quick fix" _rm_quick; pause; };;
      5) need_queue && { run_on_picked "Shift audio" _rm_shift; pause; };;
      6) queue_menu;;
      b|B|"") return;;
    esac
  done
}

# ====================================================== EXTRA TOOLS (v2.0)
make_gif() {
  local src s l w fps out base rc
  pick_target || return 1; src=$PICK_RESULT
  probe "$src" || return 1
  s=$(ask "Start time (90 / 1:30, blank = middle)" "")
  if [[ -n $s ]] && s=$(to_sec "$s"); then :; else s=$(awk -v d="$DUR" 'BEGIN{ t=d/2-2; if (t<0) t=0; printf "%.0f", t }'); fi
  l=$(ask_int "Length in seconds" 1 30 5)
  w=$(ask_int "Width in pixels" 120 1080 480)
  fps=$(ask_int "Frames per second" 5 24 12)
  EDUR=$l
  base=$(basename -- "$src"); base=${base%.*}
  out=$(unique_file "$(dirname -- "$src")" "${base}_gif" "gif")
  mkdir -p "$CONF_DIR" 2>/dev/null
  run_ffmpeg "gif" 1 1 -ss "$s" -t "$l" -i "$src" \
    -vf "fps=$fps,scale=$w:-2:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
    -loop 0 "$out"
  rc=$?
  if (( rc == 0 )) && [[ -s $out ]]; then
    ok "GIF: $(pretty "$out")  ($(human "$(fsize "$out")"))"
    command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
    yesno "Open it now?" n && open_file "$out"
  else
    err "GIF creation failed."; tail -n 5 "$LOG" >&2
    return 1
  fi
  return 0
}

extract_audio() {
  local src c out base args ext rc
  pick_target || return 1; src=$PICK_RESULT
  probe "$src" || return 1
  EDUR=$DUR
  base=$(basename -- "$src"); base=${base%.*}
  echo " 1) Copy original audio (no quality loss, fastest)"
  echo " 2) MP3 192k    3) MP3 128k    4) M4A (AAC) 128k"
  c=$(ask "Choose" "1")
  case $c in
    1) case $SRC_ACODEC in
         aac)    ext=m4a;  args=(-c:a copy);;
         mp3)    ext=mp3;  args=(-c:a copy);;
         opus)   ext=opus; args=(-c:a copy);;
         flac)   ext=flac; args=(-c:a copy);;
         vorbis) ext=ogg;  args=(-c:a copy);;
         *) warn "Stream copy of '$SRC_ACODEC' is unreliable - encoding AAC 128k instead."
            ext=m4a; args=(-c:a aac -b:a 128k);;
       esac;;
    2) ext=mp3; args=(-c:a libmp3lame -b:a 192k);;
    3) ext=mp3; args=(-c:a libmp3lame -b:a 128k);;
    4) ext=m4a; args=(-c:a aac -b:a 128k);;
    *) return 1;;
  esac
  out=$(unique_file "$(dirname -- "$src")" "${base}_audio" "$ext")
  mkdir -p "$CONF_DIR" 2>/dev/null
  run_ffmpeg "audio" 1 1 -i "$src" -vn "${args[@]}" "$out"
  rc=$?
  if (( rc == 0 )) && [[ -s $out ]]; then
    ok "Audio: $(pretty "$out")  ($(human "$(fsize "$out")"))"
    command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
    yesno "Open it now?" n && open_file "$out"
  else
    err "Audio extraction failed."; tail -n 5 "$LOG" >&2
    return 1
  fi
  return 0
}

make_thumb() {
  local src c t out base iv rc
  pick_target || return 1; src=$PICK_RESULT
  probe "$src" || return 1
  base=$(basename -- "$src"); base=${base%.*}
  echo " 1) Single frame (screenshot)"
  echo " 2) Contact sheet (3x3 preview grid)"
  c=$(ask "Choose" "1")
  mkdir -p "$CONF_DIR" 2>/dev/null
  case $c in
    1) t=$(ask "Time (90 / 1:30, blank = middle)" "")
       if [[ -n $t ]] && t=$(to_sec "$t"); then :; else t=$(awk -v d="$DUR" 'BEGIN{ printf "%.0f", d/2 }'); fi
       out=$(unique_file "$(dirname -- "$src")" "${base}_shot" "jpg")
       if ffmpeg -nostdin -hide_banner -loglevel error -y -ss "$t" -i "$src" -frames:v 1 -q:v 2 "$out" 2>>"$LOG"; then
         ok "Saved: $(pretty "$out")"
         yesno "Open it now?" n && open_file "$out"
       else
         err "Screenshot failed."; return 1
       fi;;
    2) iv=$(awk -v d="$DUR" 'BEGIN{ if (d<9) d=9; printf "%.3f", d/9 }')
       out=$(unique_file "$(dirname -- "$src")" "${base}_sheet" "jpg")
       info "Building 3x3 contact sheet..."
       if ffmpeg -nostdin -hide_banner -loglevel error -y -skip_frame nokey -i "$src" \
            -vf "fps=1/$iv,scale=320:-2,tile=3x3" -frames:v 1 -q:v 3 "$out" 2>>"$LOG"; then
         ok "Saved: $(pretty "$out")"
       else
         warn "Fast keyframe sampling failed - retrying with full decode..."
         if ffmpeg -nostdin -hide_banner -loglevel error -y -i "$src" \
              -vf "fps=1/$iv,scale=320:-2,tile=3x3" -frames:v 1 -q:v 3 "$out" 2>>"$LOG"; then
           ok "Saved: $(pretty "$out")"
         else
           err "Contact sheet failed."; return 1
         fi
       fi
       yesno "Open it now?" n && open_file "$out";;
    *) return 1;;
  esac
  return 0
}

# --------------------------------------------------------------- info tools ---

# ====================================================== FRAME EXTRACTOR (v2.3)
# Choose a start and an end time: vc creates a NEW folder and writes EVERY
# frame in that range as an image.  Range = [start, end): the frame at the
# start time is included, a frame sitting exactly on the end time is not.
# Frame-exact on constant AND variable frame rate videos (no duplicated or
# dropped frames), free space is checked first, the folder is built on fast
# local storage and moved to its final place in one pass.
frame_fmt_label()  { case $FRAME_FMT in png) echo "PNG (lossless)";; bmp) echo "BMP (raw, fastest, huge)";; webp) echo "WebP (quality $(( 101 - FRAME_Q * 3 )))";; *) echo "JPG (quality $FRAME_Q, 1 = best)";; esac; }
frame_step_label() { case $FRAME_STEP in 0) echo "keyframes only (fastest)";; 1) echo "every frame";; *) echo "one frame in every ${FRAME_STEP}";; esac; }
frame_h_label()    { if (( FRAME_H > 0 )); then echo "max ${FRAME_H}p"; else echo "original size"; fi; }

fmt_tc() {   # seconds -> hh:mm:ss.mmm
  secs_us "$1"
  printf '%02d:%02d:%02d.%03d' $(( SECS_US / 3600000000 )) $(( SECS_US % 3600000000 / 60000000 )) \
    $(( SECS_US % 60000000 / 1000000 )) $(( SECS_US % 1000000 / 1000 ))
}
fmt_tag() {   # seconds -> FMT_TAG like 00-01-30 or 00-01-30.5 (safe in folder names)
  local s=$1 i f=""
  i=${s%%.*}; [[ $s == *.* ]] && f=${s#*.}
  [[ $i =~ ^[0-9]+$ ]] || i=0
  printf -v FMT_TAG '%02d-%02d-%02d' $(( i / 3600 )) $(( i % 3600 / 60 )) $(( i % 60 ))
  f=${f:0:3}; while [[ $f == *0 ]]; do f=${f%0}; done
  [[ -n $f ]] && FMT_TAG+=".$f"
  return 0
}
unique_dir() {   # parent base -> a folder path that does not exist yet (parent is created)
  local parent=$1 base=$2 out n=0
  mkdir -p -- "$parent" 2>/dev/null
  out="$parent/$base"
  while [[ -e $out ]]; do n=$(( n + 1 )); out="$parent/${base}_$n"; done
  printf '%s' "$out"
}
free_bytes() { df -Pk -- "$1" 2>/dev/null | awk 'NR==2{printf "%d", $4*1024}'; }

frames_prepare() {   # FRAME_* settings -> FR_EXT, FR_ARGS (encoder), FR_VF (filters)
  local vf=""
  FR_VF=()
  if [[ $FRAME_FMT == webp ]] && ! have_enc libwebp; then
    warn "This ffmpeg build has no libwebp - using JPG."; FRAME_FMT=jpg
  fi
  case $FRAME_FMT in
    png)  FR_EXT=png;  FR_ARGS=(-c:v png -compression_level 3 -pix_fmt rgb24);;
    bmp)  FR_EXT=bmp;  FR_ARGS=(-c:v bmp -pix_fmt bgr24);;
    webp) FR_EXT=webp; FR_ARGS=(-c:v libwebp -quality $(( 101 - FRAME_Q * 3 )) -compression_level 2);;
    *)    FR_EXT=jpg;  FR_ARGS=(-c:v mjpeg -q:v "$FRAME_Q");;
  esac
  (( FRAME_STEP > 1 )) && vf="framestep=$FRAME_STEP"           # drop frames BEFORE scaling
  if (( FRAME_H > 0 )); then
    vf="${vf:+$vf,}scale='if(gt(iw,ih),-2,min($FRAME_H,iw))':'if(gt(iw,ih),min($FRAME_H,ih),-2)':flags=lanczos"
  fi
  [[ -n $vf ]] && FR_VF=(-vf "$vf")
  return 0
}

frames_options() {   # interactive: format / quality / which frames / size
  local c
  echo " 1) JPG (fast, small)   2) PNG (lossless)   3) BMP (raw, fastest)   4) WebP"
  c=$(ask "Image format (blank = keep: $FRAME_FMT)" "")
  case $c in 1) FRAME_FMT=jpg;; 2) FRAME_FMT=png;; 3) FRAME_FMT=bmp;; 4) FRAME_FMT=webp;; esac
  if [[ $FRAME_FMT == jpg || $FRAME_FMT == webp ]]; then
    FRAME_Q=$(ask_int "Quality (1 = best ... 31 = smallest)" 1 31 "$FRAME_Q")
  fi
  echo " 1) every frame   2) one frame in every N   3) keyframes only (very fast)"
  c=$(ask "Which frames (blank = keep: $(frame_step_label))" "")
  case $c in
    1) FRAME_STEP=1;;
    2) FRAME_STEP=$(ask_int "N" 2 1000 "$(( FRAME_STEP > 1 ? FRAME_STEP : 5 ))");;
    3) FRAME_STEP=0;;
  esac
  FRAME_H=$(ask_int "Max picture height in pixels (0 = original size)" 0 4320 "$FRAME_H")
}

move_dir() {   # $1 staged folder  $2 final folder (must not exist) -> 0 = moved completely
  local src=$1 dst=$2 total moved pid rc d1 d2 p
  d1=$(stat -c %d -- "$src" 2>/dev/null); d2=$(stat -c %d -- "$(dirname -- "$dst")" 2>/dev/null)
  if [[ -n $d1 && $d1 == "$d2" ]] && mv -- "$src" "$dst" 2>/dev/null; then return 0; fi   # same disk: instant
  mkdir -p -- "$dst" 2>/dev/null || return 1
  total=$(find "$src" -maxdepth 1 -type f | wc -l)
  find "$src" -maxdepth 1 -type f -print0 | xargs -0 -r -n 400 mv -t "$dst" 2>>"$LOG" &
  pid=$!
  if (( ! SIMPLE )) && [[ -t 1 ]]; then
    while kill -0 "$pid" 2>/dev/null; do
      moved=$(find "$dst" -maxdepth 1 -type f | wc -l)
      (( total > 0 )) && p=$(( moved * 100 / total )) || p=0
      printf '\r\033[K  moving frames to their folder: %d/%d (%d%%)' "$moved" "$total" "$p"
      sleep 1
    done
    printf '\r\033[K'
  fi
  wait "$pid"; rc=$?
  moved=$(find "$dst" -maxdepth 1 -type f | wc -l)
  if (( rc == 0 && moved == total )); then rm -rf -- "$src"; return 0; fi
  return 1
}

extract_frames() {   # $1 video  $2 start  $3 end ("" = to the end, +N = N s after start)  $4 confirm 1|0  $5 parent folder
  local src s_in=$2 e_in=$3 confirm=${4:-1} parent=${5:-}
  local start end len fps est digits base fname out work stage="" n rc t0=$SECONDS d first
  local smp mid est_b=0 need free_d free_s c what fname_x
  local -a iopt=()
  src=$(readlink -f -- "$1")
  detect_ff_caps
  probe "$src" || return 1
  [[ -z $VC_NOSTAGE ]] && stage_root

  # ---- times
  if [[ -z $s_in ]]; then start=0
  elif ! start=$(to_sec "$s_in"); then err "Bad start time: $s_in  (use 90, 1:30 or 0:01:30.5)"; return 1; fi
  if [[ -z $e_in || ${e_in,,} == end ]]; then end=$DUR
  elif [[ $e_in == +* ]]; then
    d=$(to_sec "${e_in#+}") || { err "Bad end time: $e_in"; return 1; }
    end=$(awk -v a="$start" -v b="$d" 'BEGIN{ printf "%.3f", a + b }')
  else
    end=$(to_sec "$e_in") || { err "Bad end time: $e_in  (use 90, 1:30 or 0:01:30.5)"; return 1; }
  fi
  if ! awk -v s="$start" -v d="$DUR" 'BEGIN{ exit !(s < d) }'; then
    err "Start ($start s) is beyond the end of the video ($DUR s)."; return 1
  fi
  if awk -v e="$end" -v d="$DUR" 'BEGIN{ exit !(e > d) }'; then
    warn "End is after the video's end - using the end of the video."; end=$DUR
  fi
  len=$(awk -v a="$start" -v b="$end" 'BEGIN{ printf "%.3f", b - a }')
  if ! awk -v l="$len" 'BEGIN{ exit !(l > 0) }'; then err "End must be after start."; return 1; fi
  fps=$SRC_AFPS; awk -v f="$fps" 'BEGIN{ exit !(f + 0 > 0) }' || fps=$SRC_FPS

  base=$(basename -- "$src"); base=${base%.*}
  fmt_tag "$start"; fname="${base}_frames_${FMT_TAG}"
  fmt_tag "$end";   fname+="_to_${FMT_TAG}"
  [[ -n $parent ]] || parent=${OUTDIR:-$(dirname -- "$src")}
  mkdir -p -- "$parent" 2>/dev/null || { err "Cannot create/use folder: $parent"; return 1; }

  while true; do
    frames_prepare
    case $FRAME_STEP in 0) what="keyframes only";; 1) what="every frame";; *) what="one frame in every ${FRAME_STEP}";; esac
    if (( FRAME_STEP == 0 )); then
      est=$(awk -v l="$len" 'BEGIN{ n = int(l / 2 + 0.5); if (n < 1) n = 1; print n }')      # ~1 keyframe / 2 s
    else
      est=$(awk -v l="$len" -v f="$fps" -v k="$FRAME_STEP" 'BEGIN{ n = int(l * f / k + 0.5); if (n < 1) n = 1; print n }')
    fi
    digits=$(( ${#est} + 1 )); (( digits < 5 )) && digits=5
    case $FRAME_STEP in 1) fname_x="";; 0) fname_x="_keyframes";; *) fname_x="_every${FRAME_STEP}";; esac
    out=$(unique_dir "$parent" "${fname}${fname_x}")

    # ---- size estimate from ONE real sample frame (same format, size and quality)
    mid=$(awk -v a="$start" -v l="$len" 'BEGIN{ printf "%.3f", a + l / 2 }')
    smp="${STAGE_ROOT:-${TMPDIR:-/tmp}}/vcsample_$$_$RANDOM.$FR_EXT"
    mkdir -p "$CONF_DIR" 2>/dev/null; : > "$LOG"
    if ffmpeg -nostdin -hide_banner -loglevel error -y -ss "$mid" -i "$src" -map 0:v:0 -an -sn -dn \
         "${FR_VF[@]}" "${FR_ARGS[@]}" -frames:v 1 -update 1 "$smp" 2>>"$LOG" && [[ -s $smp ]]; then
      est_b=$(( $(fsize "$smp") * est ))
    else
      rm -f -- "$smp"; err "Cannot decode this video's picture. Last log lines:"; tail -n 4 "$LOG" >&2; return 1
    fi
    rm -f -- "$smp"
    need=$(( est_b + est_b / 10 + 4194304 ))
    free_d=$(free_bytes "$parent")

    printf '\n%s== Frame extractor ==%s\n' "$C_B" "$C_0"
    printf '  Video   : %s\n' "$(trunc "$(basename -- "$src")")"
    printf '  Range   : %s -> %s   (%s s)\n' "$(fmt_tc "$start")" "$(fmt_tc "$end")" "$len"
    printf '  Frames  : %s, about %s  (%s fps)\n' "$what" "$est" "$fps"
    printf '  Format  : %s, %s\n' "$(frame_fmt_label)" "$(frame_h_label)"
    printf '  Size    : about %s   (free space here: %s)\n' "$(human "$est_b")" "$(human "$free_d")"
    printf '  Folder  : %s\n' "$(pretty "$out")"
    if (( free_d > 0 && need > free_d )); then
      err "Not enough free space for these frames (need ~$(human "$need"))."
      (( confirm )) || return 1
    fi
    (( confirm )) || break
    printf '  y) start    o) options    l) change location    b) cancel\n'
    read -r -p "> " c || return 1
    case ${c,,} in
      y|"") break;;
      o) frames_options;;
      l) parent=$(ask "Create the folder inside" "$parent"); parent=${parent/#\~/$HOME}
         mkdir -p -- "$parent" 2>/dev/null || { warn "Cannot use that folder."; parent=${OUTDIR:-$(dirname -- "$src")}; };;
      b) return 1;;
    esac
  done

  # ---- build locally when there is room, otherwise write straight into place
  if [[ -n $STAGE_ROOT ]] && free_s=$(stage_free) && (( free_s > need + 104857600 )); then
    stage=$(mktemp -d "$STAGE_ROOT/frames.XXXXXX") || stage=""
  fi
  if [[ -n $stage ]]; then work=$stage; else mkdir -- "$out" || { err "Cannot create $out"; return 1; }; work=$out; fi
  CUR_TMPDIR=$work

  (( FRAME_STEP == 0 )) && iopt=(-skip_frame nokey)
  EDUR=$len
  run_ffmpeg "frames" 1 1 "${iopt[@]}" -ss "$start" -i "$src" -t "$len" -map 0:v:0 -an -sn -dn \
    "${FR_VF[@]}" "${FPSMODE_OPT[@]}" "${ENCTB_OPT[@]}" "${FR_ARGS[@]}" -start_number 1 "$work/frame_%0${digits}d.$FR_EXT"
  rc=$?
  n=$(find "$work" -maxdepth 1 -type f -name "frame_*.$FR_EXT" | wc -l)
  if (( rc != 0 || n == 0 )); then
    if (( rc == 255 )); then warn "Cancelled - nothing was saved."
    elif (( rc != 0 )); then err "Frame extraction failed (ffmpeg exit $rc). Last log lines:"; tail -n 6 "$LOG" | sed 's/^/    /' >&2
    else err "No frames found between those two times."; fi
    rm -rf -- "$work"; CUR_TMPDIR=""
    return 1
  fi
  if [[ -n $stage ]]; then
    if ! move_dir "$stage" "$out"; then
      err "Could not move the frames into $(pretty "$out") (destination full / not writable?)."
      CUR_TMPDIR=""; return 1
    fi
  fi
  CUR_TMPDIR=""
  printf -v first "frame_%0${digits}d.%s" 1 "$FR_EXT"
  ok "$n frames -> $(pretty "$out")"
  info "  $(human "$(du -sk -- "$out" 2>/dev/null | awk '{printf "%d", $1 * 1024}')") in $(fmt_time $(( SECONDS - t0 )))  |  first: $first"
  FRAMES_OUT=$out
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 60 termux-media-scan -r "$out" >/dev/null 2>&1 & }
  if (( confirm )) && [[ -t 0 ]]; then yesno "Open the first frame?" n && open_file "$out/$first"; fi
  return 0
}

frames_flow() {   # $1 optional video - interactive front end
  local src=${1:-} s e
  if [[ -z $src ]]; then pick_target || return 1; src=$PICK_RESULT; fi
  probe "$src" || return 1
  printf '\n%s== Frame extractor ==%s\n' "$C_B" "$C_0"
  printf '  %s\n  length %s (%s s)  |  %s fps  |  %sx%s\n\n' "$(trunc "$(basename -- "$src")")" \
    "$(fmt_time "$DUR")" "$DUR" "$SRC_AFPS" "$SRC_W" "$SRC_H"
  info "Times: 90 | 1:30 | 0:01:30.5      End: blank = to the end,  +5 = 5 s after start"
  s=$(ask "Start" "0")
  e=$(ask "End  " "")
  extract_frames "$src" "$s" "$e" 1
}

# ======================================================== PRESET RACE (v2.3)
# Encodes the same short sample with every preset and prints the real speed,
# estimated size and estimated time on THIS device - so you pick the right
# preset from facts, not guesses.

quality_ssim() {   # $1 encoded sample -> SSIM_VAL (0..1, vs the SAME seconds of the source scaled to the same size)
  local f=$1 dim w h rf="" line
  SSIM_VAL=""
  dim=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x -- "$f" 2>/dev/null | head -n1)
  [[ $dim =~ ^([0-9]+)x([0-9]+)$ ]] || return 1
  w=${BASH_REMATCH[1]}; h=${BASH_REMATCH[2]}
  if (( FPS > 0 )) && awk -v s="$SRC_FPS" -v t="$FPS" 'BEGIN{ exit !(s > t+0.5) }'; then rf="fps=$FPS,"; fi
  line=$(ffmpeg -nostdin -hide_banner -ss "$RACE_SSTART" -t "$RACE_SLEN" -i "$RACE_SRC" -i "$f" \
    -filter_complex "[0:v]${rf}scale=${w}:${h}:flags=bicubic,format=yuv420p[r];[1:v]format=yuv420p[d];[d][r]ssim" \
    -f null - 2>&1 | grep -o 'All:[0-9.]*' | tail -n1)
  SSIM_VAL=${line#All:}
  [[ $SSIM_VAL =~ ^[01](\.[0-9]+)?$ ]] || { SSIM_VAL=""; return 1; }
}
ssim_label() {   # rough human label for an SSIM value
  local v=$1 t
  [[ $v =~ ^0\.([0-9]{3,4}) ]] || { [[ $v == 1* ]] && echo "identical"; return 0; }
  t=${BASH_REMATCH[1]}; t=${t}0000; t=$(( 10#${t:0:4} ))
  if   (( t >= 9900 )); then echo "excellent"
  elif (( t >= 9700 )); then echo "very good"
  elif (( t >= 9400 )); then echo "good"
  elif (( t >= 9000 )); then echo "fair"
  else echo "visible loss"; fi
}
now_us() { if [[ -n ${EPOCHREALTIME-} ]]; then NOW_US=${EPOCHREALTIME/[.,]/}; else NOW_US=$(( SECONDS * 1000000 )); fi; }
race_setup() {   # $1 video -> RACE_* globals, settings snapshot, temp dir
  RACE_SRC=$1
  CROP_VF=""; AENC_NAME=aac; CT_SUBS=mov_text; CT_FMT=mp4; CT_FAST=1; CT_STAGE=1; CT_HVC=1
  probe "$RACE_SRC" || return 1
  detect_ff_caps
  RACE_SLEN=$(awk -v d="$DUR" -v L="$RACE_LEN" 'BEGIN{ printf "%.3f", (d > L + 2) ? L : d }')
  RACE_SSTART=$(awk -v d="$DUR" -v l="$RACE_SLEN" 'BEGIN{ s = (d - l) / 2; if (s < 0) s = 0; printf "%.3f", s }')
  secs_us "$RACE_SLEN"; RACE_SLEN_US=$SECS_US; (( RACE_SLEN_US < 1 )) && RACE_SLEN_US=1
  secs_us "$DUR"; RACE_FULL_US=$SECS_US
  RACE_SNAP=$(mktemp) || return 1
  write_settings "$RACE_SNAP"
  TMPD=$(mktemp -d) || { rm -f -- "$RACE_SNAP"; return 1; }
  mkdir -p "$CONF_DIR"; : > "$LOG"
  TARGET_MB=0
  calc_threads 1
  return 0
}
race_teardown() {   # restore settings, CPU pinning and thread budget
  freq_sample_stop
  rm -rf -- "$TMPD"; TMPD=""
  load_conf "$RACE_SNAP"; rm -f -- "$RACE_SNAP"
  if [[ -n $PIN_MASK ]]; then set_affinity "$PIN_MASK" >/dev/null 2>&1
  elif [[ -n $ORIG_MASK ]]; then set_affinity "$ORIG_MASK" >/dev/null 2>&1; fi
  calc_threads 1
}
race_encode() {   # one sample encode with the CURRENT settings -> R_RC, R_US (microseconds), R_SZ, file $R_TMP
  local br="" vf t0
  [[ $CODEC == hw* ]] && br=$VBR
  EDUR=$RACE_SLEN
  vf=$(build_vf); VFARG=(); [[ -n $vf ]] && VFARG=(-vf "$vf")
  build_aenc; build_venc single "$br"
  R_TMP="$TMPD/race_sample.mp4"; rm -f -- "$R_TMP"
  now_us; t0=$NOW_US
  ( cd "$TMPD" && SIMPLE=1 LOGF="$LOG" run_ffmpeg "" 1 1 -ss "$RACE_SSTART" -t "$RACE_SLEN" -i "$RACE_SRC" \
      -map 0:v:0 -map '0:a?' "${VFARG[@]}" "${VENC[@]}" "${AENC[@]}" -f mp4 "$R_TMP" )
  R_RC=$?
  now_us; R_US=$(( NOW_US - t0 )); (( R_US < 1 )) && R_US=1
  R_SZ=0
  if (( R_RC == 0 )) && [[ -s $R_TMP ]]; then R_SZ=$(fsize "$R_TMP"); else R_RC=1; fi
}
fmt_x100() { printf '%d.%02d' $(( $1 / 100 )) $(( $1 % 100 )); }

preset_race() {   # $1 optional video: every preset -> speed, size, time, quality
  local src=${1:-} p i bi=-1 bs=-1 bq=-1 spd est_sz est_t lab
  local -a names=() spds=() szs=() qs=() tms=()
  if [[ -z $src ]]; then pick_target || return 1; src=$PICK_RESULT; fi
  race_setup "$src" || return 1
  printf '\n%s== Preset race ==%s\n' "$C_B" "$C_0"
  info "${RACE_SLEN}s sample of $(trunc "$(basename -- "$src")") - measured on THIS device"
  info "CPU: ${PIN_NOTE:-all cores}$( (( THREADS_PER_JOB > 0 )) && echo ", $THREADS_PER_JOB thread(s)" )"
  printf '  %s%-9s %8s  %10s  %9s  %s%s\n' "$C_D" "preset" "speed" "est. size" "est. time" "quality (SSIM)" "$C_0"
  for p in turbo fast balanced quality small tiny social compat av1 web hardware; do
    apply_preset "$p" || continue
    TARGET_MB=0
    case $CODEC in
      hw*) have_enc "$(hw_encoder_name)" || continue;;
      av1) have_enc libsvtav1 || continue;;
      vp9) have_enc libvpx-vp9 || continue;;
    esac
    printf '  %-9s %srunning...%s' "$p" "$C_D" "$C_0"
    race_encode
    if (( R_RC == 0 )); then
      spd=$(( RACE_SLEN_US * 100 / R_US ))
      est_sz=$(( R_SZ * RACE_FULL_US / RACE_SLEN_US ))
      est_t=$(( RACE_FULL_US * R_US / RACE_SLEN_US / 1000000 ))
      SSIM_VAL=""
      if (( ! NOQUALITY )); then printf '\r\033[K  %-9s %smeasuring quality...%s' "$p" "$C_D" "$C_0"; quality_ssim "$R_TMP"; fi
      lab=""; [[ -n $SSIM_VAL ]] && lab="${SSIM_VAL:0:6} $(ssim_label "$SSIM_VAL")"
      printf '\r\033[K  %-9s %5s x  %10s  %9s  %s\n' "$p" "$(fmt_x100 "$spd")" "$(human "$est_sz")" "$(fmt_time "$est_t")" "${lab:--}"
      names+=("$p"); spds+=("$spd"); szs+=("$est_sz"); qs+=("${SSIM_VAL:-0}"); tms+=("$est_t")
    else
      printf '\r\033[K  %-9s %sfailed (see log)%s\n' "$p" "$C_R" "$C_0"
    fi
    rm -f -- "$R_TMP"
  done
  race_teardown
  RACE_R_NAMES=("${names[@]}"); RACE_R_SPD=("${spds[@]}"); RACE_R_SZ=("${szs[@]}"); RACE_R_Q=("${qs[@]}"); RACE_R_TM=("${tms[@]}")
  if (( ${#names[@]} )); then
    for i in "${!names[@]}"; do
      (( bi < 0 || spds[i] > spds[bi] )) && bi=$i
      (( bs < 0 || szs[i] < szs[bs] )) && bs=$i
      if (( NOQUALITY == 0 )) && [[ ${qs[i]} != 0 ]]; then
        if (( bq < 0 )) || awk -v a="${qs[i]}" -v b="${qs[bq]}" 'BEGIN{ exit !(a > b) }'; then bq=$i; fi
      fi
    done
    printf '\n  %sFastest      :%s %s (%s x real time)\n' "$C_G" "$C_0" "${names[bi]}" "$(fmt_x100 "${spds[bi]}")"
    printf '  %sSmallest     :%s %s (~%s)\n' "$C_G" "$C_0" "${names[bs]}" "$(human "${szs[bs]}")"
    (( bq >= 0 )) && printf '  %sBest quality :%s %s (SSIM %s)\n' "$C_G" "$C_0" "${names[bq]}" "${qs[bq]:0:6}"
    info "  Speed/size are rough (+/-20%). Quality = how close the result is to the source scaled to the SAME size,"
    info "  so a small picture is not penalised for being small. Pick:  vc -y -p <preset> FILE"
  else
    err "No preset could be encoded - see the log: $(pretty "$LOG")"; return 1
  fi
  return 0
}

cores_race() {   # $1 optional video, $2 = "apply" -> switch to a clearly better setup without asking
  local src=${1:-} mode=${2:-} nb i r k best=0 cur=-1 gain n_all key runs=3 s
  local -a cn=() cm=() ct=() cs=() sp=() sum=()
  if [[ -z $src ]]; then pick_target || return 1; src=$PICK_RESULT; fi
  race_setup "$src" || return 1
  detect_cpu
  n_all=$CPU_N; (( n_all < 1 )) && n_all=$(nproc --all 2>/dev/null || echo 4)
  nb=$BIG_N; (( nb < 1 )) && nb=$(( n_all / 2 )); (( nb < 1 )) && nb=1
  # setups: name | affinity mask ("" = leave) | threads | settings to save "CORES|THREADS"
  cn+=("all cores, auto threads");  cm+=("${ORIG_MASK}"); ct+=(0);     cs+=("all|0")
  cn+=("all cores, $nb threads");   cm+=("${ORIG_MASK}"); ct+=("$nb"); cs+=("all|$nb")
  if (( CPU_HETERO )) && [[ -n $BIG_MASK ]] && find_taskset && [[ -n $ORIG_MASK ]]; then
    cn+=("big cores only ($BIG_LIST)"); cm+=("$BIG_MASK"); ct+=(0); cs+=("auto|0")
  fi
  # which setup is in use RIGHT NOW? (CORES/THREADS were snapshotted by race_setup)
  key="$CORES|$THREADS"
  for i in "${!cs[@]}"; do [[ ${cs[i]} == "$key" ]] && cur=$i; done
  if (( cur < 0 )) && [[ $key == "auto|0" ]]; then cur=0; fi     # auto on a phone without a big/little split = all cores
  printf '\n%s== CPU test ==%s\n' "$C_B" "$C_0"
  info "Same ${RACE_SLEN}s encode ($PRESET_NAME), each setup $runs times, interleaved so heat affects all equally"
  (( ${#cn[@]} < 3 )) && info "(no big/little split found or pinning unavailable: testing thread counts only)"
  for (( r = 1; r <= runs; r++ )); do
    for i in "${!cn[@]}"; do
      printf '\r\033[K  run %d/%d: %s ...' "$r" "$runs" "${cn[i]}"
      if [[ -n ${cm[i]} ]]; then set_affinity "${cm[i]}" >/dev/null 2>&1; fi
      if [[ ${cs[i]%%|*} == auto ]]; then THREADS_PER_JOB=$BIG_N; else THREADS_PER_JOB=${ct[i]}; fi
      race_encode
      if (( R_RC == 0 )); then sp[i*runs+r-1]=$(( RACE_SLEN_US * 100 / R_US )); else sp[i*runs+r-1]=0; fi
      rm -f -- "$R_TMP"
    done
  done
  printf '\r\033[K'
  printf '  %s%-26s' "$C_D" "setup"; for (( r = 1; r <= runs; r++ )); do printf ' %7s' "run $r"; done; printf ' %9s%s\n' "average" "$C_0"
  for i in "${!cn[@]}"; do
    s=0; for (( r = 0; r < runs; r++ )); do s=$(( s + sp[i*runs+r] )); done
    sum[i]=$(( s / runs ))
    printf '  %-26s' "${cn[i]}"; for (( r = 0; r < runs; r++ )); do printf ' %6sx' "$(fmt_x100 "${sp[i*runs+r]}")"; done
    printf ' %8sx' "$(fmt_x100 "${sum[i]}")"; (( i == cur )) && printf '  <- in use now'; printf '\n'
    (( sum[i] > sum[best] )) && best=$i
  done
  race_teardown
  (( cur < 0 )) && cur=0
  if (( sum[cur] > 0 )); then gain=$(( (sum[best] - sum[cur]) * 100 / sum[cur] )); else gain=0; fi
  if (( best == cur || gain < 8 )); then
    printf '\n  %sResult:%s the setup in use ("%s") is as good as any here: gaps under 8%% are noise.\n' "$C_G" "$C_0" "${cn[cur]}"
  else
    printf '\n  %sBest:%s %s  (+%d%% vs the setup in use)\n' "$C_G" "$C_0" "${cn[best]}" "$gain"
    if [[ $mode == apply ]]; then
      CORES=${cs[best]%%|*}; THREADS=${cs[best]##*|}
      reapply_cores; ok "CPU setup switched to: ${cn[best]}"
    elif [[ -t 0 ]] && yesno "Make this your default CPU setup?" n; then
      CORES=${cs[best]%%|*}; THREADS=${cs[best]##*|}
      save_settings; reapply_cores; ok "Saved (CORES=$CORES, THREADS=$THREADS)."
    fi
  fi
  info "  A phone may behave differently once it is hot - see the heat test (vc --stamina)."
  return 0
}

stamina_test() {   # $1 optional video: repeat one encode and watch speed, temperature, clock
  local src=${1:-} r=0 spd first=0 last=0 prev=0 t_start t0 el limit drop tmp0="" tmpN="" f0="" fN="" shown
  local -a all=()
  limit=${VC_STAMINA_SEC:-90}
  if [[ -z $src ]]; then pick_target || return 1; src=$PICK_RESULT; fi
  race_setup "$src" || return 1
  race_cpus
  printf '\n%s== Heat test ==%s\n' "$C_B" "$C_0"
  info "Repeats the same ${RACE_SLEN}s encode ($PRESET_NAME) for about ${limit}s. If speed keeps falling, the phone is throttling."
  info "CPU: ${PIN_NOTE:-all cores}$( (( THREADS_PER_JOB > 0 )) && echo ", $THREADS_PER_JOB thread(s)" )"
  read_temp; tmp0=$TEMP_C
  now_us; t_start=$NOW_US
  printf '  %s%-6s %6s %8s %7s  %s%s\n' "$C_D" "round" "time" "speed" "temp" "CPU clock (average)" "$C_0"
  while true; do
    r=$(( r + 1 ))
    printf '  round %-3d %srunning...%s' "$r" "$C_D" "$C_0"
    freq_sample_start
    race_encode
    freq_sample_stop
    read_temp
    now_us; el=$(( (NOW_US - t_start) / 1000000 ))
    if (( R_RC != 0 )); then printf '\r\033[K  %sencode failed - see %s%s\n' "$C_R" "$(pretty "$LOG")" "$C_0"; break; fi
    spd=$(( RACE_SLEN_US * 100 / R_US )); all+=("$spd")
    (( r == 1 )) && { first=$spd; f0=$FREQ_AVG; }
    fN=$FREQ_AVG; tmpN=$TEMP_C
    printf '\r\033[K  %-6s %5ss %7sx %7s  %s\n' "$r" "$el" "$(fmt_x100 "$spd")" "${TEMP_C:+${TEMP_C}°C}" \
      "${FREQ_AVG:+${FREQ_AVG} MHz}"
    rm -f -- "$R_TMP"
    (( r >= 15 )) && break
    (( el >= limit && r >= 3 )) && break
  done
  race_teardown
  if [[ -z $tmp0 && -z $f0 ]]; then
    info "  (Android does not let Termux read temperature or CPU clock here - only the speed trend can be shown.)"
  fi
  (( ${#all[@]} >= 2 )) || return 0
  # compare the first round with the average of the last two (or last one)
  if (( ${#all[@]} >= 4 )); then last=$(( (all[-1] + all[-2]) / 2 )); else last=${all[-1]}; fi
  (( first > 0 )) && drop=$(( (first - last) * 100 / first )) || drop=0
  printf '\n'
  local proof=0
  if [[ -n $f0 && -n $fN ]] && (( fN * 100 < f0 * 90 )); then proof=1; fi          # clock fell >10%
  if [[ -n $tmp0 && -n $tmpN ]] && (( tmpN - tmp0 >= 5 )); then proof=1; fi          # got 5C hotter
  if   (( drop >= 20 && proof )); then printf '  %sThrottling:%s speed fell %d%% (%sx -> %sx) in %ss, and the clock/temperature confirm heat.\n' "$C_R" "$C_0" "$drop" "$(fmt_x100 "$first")" "$(fmt_x100 "$last")" "$el"
  elif (( drop >= 20 )); then printf '  %sBig slowdown:%s speed fell %d%% (%sx -> %sx) in %ss. Usually heat, but without a clock/temperature reading (or with another app busy) this cannot be proven.\n' "$C_R" "$C_0" "$drop" "$(fmt_x100 "$first")" "$(fmt_x100 "$last")" "$el"
  elif (( drop >= 8 ));  then printf '  %sMild slowdown:%s speed fell %d%% (%sx -> %sx) in %ss.\n' "$C_Y" "$C_0" "$drop" "$(fmt_x100 "$first")" "$(fmt_x100 "$last")" "$el"
  else printf '  %sStable:%s speed stayed within %d%% over %ss (%sx -> %sx).\n' "$C_G" "$C_0" "$(( drop < 0 ? -drop : drop ))" "$el" "$(fmt_x100 "$first")" "$(fmt_x100 "$last")"; fi
  if [[ -n $tmp0 && -n $tmpN ]]; then printf '  Temperature: %s°C -> %s°C\n' "$tmp0" "$tmpN"; fi
  if [[ -n $f0 && -n $fN ]]; then printf '  CPU clock  : %s MHz -> %s MHz\n' "$f0" "$fN"; fi
  if (( drop >= 8 )); then
    info "  What helps: take the case off, unplug the charger, keep Termux battery use on 'unrestricted',"
    info "  try the 'hardware' preset (it uses the video chip, not the CPU), or compress in smaller batches."
    if [[ -z $f0 ]]; then info "  (This phone hides the CPU clock, so heat vs. other causes cannot be separated here.)"; fi
  fi
  (( el < 60 )) && info "  Short test (${el}s): a long compress can heat the phone more. Run again right after for a hot-start comparison."
  return 0
}

race_all() {   # $1 optional video
  local src=${1:-}
  if [[ -z $src ]]; then pick_target || return 1; src=$PICK_RESULT; fi
  device_report
  preset_race "$src"
  cores_race "$src"
  stamina_test "$src"
}


# ================================================================ AUTO-TUNE (v2.5)
# One question ("what matters most?"), one test video. vc races every preset on
# it (speed, size, SSIM quality), tests the CPU setup, then picks and saves the
# best settings for THIS phone. Quality floors (SSIM): good 0.95, very good 0.97.
ssim_t10k() {   # "0.9712" -> 9712 ; unknown -> 0
  local v=$1 f
  if [[ $v =~ ^0\.([0-9]+)$ ]]; then f=${BASH_REMATCH[1]}0000; echo $(( 10#${f:0:4} ))
  elif [[ $v =~ ^1(\.0+)?$ ]]; then echo 10000
  else echo 0; fi
}
tune_pick() {   # $1 goal: speed | balanced | size | quality  -> TUNE_PICK, TUNE_WHY (uses RACE_R_* from preset_race)
  local g=$1 i n=${#RACE_R_NAMES[@]} best=-1 q floor=0 better note=""
  local -a Q=()
  TUNE_PICK=""; TUNE_WHY=""
  (( n > 0 )) || return 1
  case $g in speed|size) floor=9500;; balanced) floor=9700;; esac
  for (( i = 0; i < n; i++ )); do Q[i]=$(ssim_t10k "${RACE_R_Q[i]}"); done
  for (( i = 0; i < n; i++ )); do
    q=${Q[i]}
    if [[ $g != quality ]] && (( q < floor )); then continue; fi
    better=0
    if (( best < 0 )); then better=1
    else
      case $g in
        speed)    (( RACE_R_SPD[i] > RACE_R_SPD[best] )) && better=1;;
        size)     (( RACE_R_SZ[i] < RACE_R_SZ[best] )) && better=1;;
        balanced) (( RACE_R_TM[i] * RACE_R_SZ[i] < RACE_R_TM[best] * RACE_R_SZ[best] )) && better=1;;
        quality)  if (( q > Q[best] + 20 )); then better=1
                  elif (( q >= Q[best] - 20 && RACE_R_SPD[i] > RACE_R_SPD[best] )); then better=1; fi;;
      esac
    fi
    (( better )) && best=$i
  done
  if (( best < 0 )); then   # nothing reached the quality floor: take the best quality available
    for (( i = 0; i < n; i++ )); do (( best < 0 || Q[i] > Q[best] )) && best=$i; done
    note=" (no preset reached the quality target on this video, so this is the best available)"
  fi
  TUNE_PICK=${RACE_R_NAMES[best]}
  local sx; printf -v sx '%d.%02d' $(( RACE_R_SPD[best] / 100 )) $(( RACE_R_SPD[best] % 100 ))
  local sq="${RACE_R_Q[best]:0:6}"
  case $g in
    speed)    TUNE_WHY="the fastest preset that still reaches good quality (SSIM $sq)";;
    size)     TUNE_WHY="the smallest files that still reach good quality (SSIM $sq)";;
    balanced) TUNE_WHY="very good quality (SSIM $sq) for the least time x size";;
    quality)  TUNE_WHY="the highest quality measured (SSIM $sq)";;
  esac
  TUNE_WHY+="$note; ${sx}x real time, about $(human "${RACE_R_SZ[best]}") for this video"
  return 0
}

auto_tune() {   # $1 optional video
  local src=${1:-} goal=${TUNE_GOAL:-} c snap sv_noq=$NOQUALITY sv_len=$RACE_LEN interactive=0
  [[ -t 0 && -t 1 ]] && interactive=1
  if [[ -z $src ]]; then
    if (( ${#SELECTED[@]} == 1 )); then src=${SELECTED[0]}
    else pick_target || return 1; src=$PICK_RESULT; fi
  fi
  if [[ -z $goal ]]; then
    printf '\n%s== Auto-tune ==%s\n' "$C_B" "$C_0"
    echo "What matters most to you?"
    echo " 1) Speed       fastest, still good quality"
    echo " 2) Balanced    very good quality, as quick as possible  (recommended)"
    echo " 3) Small files smallest size, still good quality"
    echo " 4) Quality     best picture, slower"
    c=$(ask "Choose" "2")
    case $c in 1) goal=speed;; 3) goal=size;; 4) goal=quality;; *) goal=balanced;; esac
  fi
  snap=$(mktemp) || return 1; write_settings "$snap"
  info "vc will now test your phone with this video: $(trunc "$(basename -- "$src")")"
  info "About 3-5 minutes. Keep the screen on and do not use other heavy apps."
  wake_lock
  NOQUALITY=0; RACE_LEN=6
  if ! preset_race "$src"; then NOQUALITY=$sv_noq; RACE_LEN=$sv_len; wake_unlock; rm -f -- "$snap"; return 1; fi
  if ! tune_pick "$goal"; then err "No result to choose from."; NOQUALITY=$sv_noq; RACE_LEN=$sv_len; wake_unlock; rm -f -- "$snap"; return 1; fi
  printf '\n%s== Result ==%s\n' "$C_B" "$C_0"
  printf '  Goal   : %s\n  Preset : %s%s%s - %s\n' "$goal" "$C_G" "$TUNE_PICK" "$C_0" "$TUNE_WHY"
  apply_preset "$TUNE_PICK"
  detect_cpu
  if (( CPU_HETERO )) && [[ -n $BIG_MASK ]] && find_taskset; then
    info "Now testing the CPU setup (big cores vs all cores) with that preset..."
    cores_race "$src" apply
  fi
  NOQUALITY=$sv_noq; RACE_LEN=$sv_len
  wake_unlock
  printf '  CPU    : %s\n\n' "${PIN_NOTE:-all cores}"
  if (( interactive )) && ! yesno "Use these settings from now on?" y; then
    load_conf "$snap"; reapply_cores; rm -f -- "$snap"
    info "Nothing changed."
    return 0
  fi
  rm -f -- "$snap"
  save_settings
  mkdir -p "$CONF_DIR"; printf '%s goal=%s preset=%s cores=%s threads=%s\n' "$(date +%F)" "$goal" "$TUNE_PICK" "$CORES" "$THREADS" > "$CONF_DIR/autotune"
  ok "Saved. Preset: $TUNE_PICK   CPU: ${PIN_NOTE:-all cores}"
  info "Change any time: menu 3 (preset), 4 then 24 (CPU). Run auto-tune again with menu t."
  return 0
}
first_run_offer() {   # once: offer the automatic speed setup
  [[ -t 0 && -t 1 ]] || return 0
  [[ -f $CONF_DIR/autotune || -f $CONF_DIR/autotune_skip ]] && return 0
  local c
  clear_screen
  printf '%s== First-time speed setup ==%s\n\n' "$C_B" "$C_0"
  echo "vc can test YOUR phone now and choose the"
  echo "fastest settings automatically."
  echo "It needs one video to test with and takes"
  echo "about 3-5 minutes. Only done once."
  echo
  echo " y) Run it now (recommended)"
  echo " l) Later (ask again next time)"
  echo " n) Never ask again"
  c=$(ask "Choose" "y")
  case ${c,,} in
    y|"") auto_tune ""; pause;;
    n)    mkdir -p "$CONF_DIR"; : > "$CONF_DIR/autotune_skip";;
  esac
}
race_menu() {   # interactive "speed lab"
  local c src=""
  while true; do
    clear_screen
    printf '%s== Speed lab ==%s\n' "$C_B" "$C_0"
    printf '  %sCPU: %s%s\n\n' "$C_D" "${PIN_NOTE:-all cores}" "$C_0"
    echo " 1) AUTO-TUNE      (finds and saves the best settings for you)"
    echo " 2) Preset race    (speed, size and quality of every preset)"
    echo " 3) CPU test       (all cores vs fewer threads vs big cores only)"
    echo " 4) Heat test      (does speed drop while it runs?)"
    echo " 5) Everything     (2 + 3 + 4, takes a few minutes)"
    echo " 6) CPU info       (core layout, pinning, sensors)"
    echo " b) Back"
    read -r -p "> " c || return
    case $c in
      1) auto_tune "${src}"; pause;;
      2|3|4|5)
        if [[ -z $src ]]; then pick_target || continue; src=$PICK_RESULT; fi
        case $c in 2) preset_race "$src";; 3) cores_race "$src";; 4) stamina_test "$src";; 5) race_all "$src";; esac
        pause;;
      6) device_report; pause;;
      b|B|"") return;;
    esac
  done
}
show_info() {
  (( ${#SELECTED[@]} )) || { warn "No videos selected."; return; }
  local f kb
  for f in "${SELECTED[@]}"; do
    probe "$f" || continue
    kb=$(awk -v s="$(fsize "$f")" -v d="$DUR" 'BEGIN{ printf "%d", s*8/d/1000 }')
    printf '\n%s%s%s\n' "$C_B" "$(trunc "$(basename -- "$f")")" "$C_0"
    printf '  Size      : %s   Duration: %s   Avg: %s kbps\n' "$(human "$(fsize "$f")")" "$(fmt_time "$DUR")" "$kb"
    printf '  Video     : %s %sx%s @ %s fps%s\n' "$SRC_VCODEC" "$SRC_W" "$SRC_H" "$SRC_FPS" "${SRC_VBR:+, ${SRC_VBR} kbps}"
    printf '  Audio     : %s%s\n' "${SRC_ACODEC:-none}" "${SRC_ABR:+, ${SRC_ABR} kbps}"
    printf '  Subtitles : %s track(s)\n' "$SRC_NSUBS"
  done
}
check_deps() {
  local c e fd
  echo
  for c in ffmpeg ffprobe awk; do
    if command -v "$c" >/dev/null 2>&1; then ok "$c found"; else err "$c missing"; fi
  done
  command -v ffmpeg >/dev/null 2>&1 && info "$(ffmpeg -version 2>/dev/null | head -n1)"
  for e in libx265 libx264 libsvtav1 libmp3lame aac hevc_mediacodec h264_mediacodec; do
    if have_enc "$e"; then ok "encoder: $e"; else warn "encoder missing: $e"; fi
  done
  fd=$(fonts_dir)
  if [[ -n $fd ]]; then ok "fonts directory (subtitle burn-in): $fd"; else warn "no fonts dir found - subtitle burn-in may fail"; fi
  for c in termux-wake-lock termux-notification termux-media-scan termux-open; do
    if command -v "$c" >/dev/null 2>&1; then ok "optional: $c"; else info "optional (Termux tools): $c not available"; fi
  done
  if [[ -d $HOME/storage/shared ]]; then ok "shared storage access OK"; else warn "no storage access - run: termux-setup-storage"; fi
}
do_setup() {
  if command -v pkg >/dev/null 2>&1; then
    pkg install -y ffmpeg gawk openssl-tool || err "pkg install failed (try: pkg update)"
    if [[ -t 0 ]] && yesno "Also install termux-api (notifications + gallery refresh; needs the Termux:API app)?" n; then
      pkg install -y termux-api
    fi
  else
    warn "'pkg' not found - install ffmpeg and gawk with your package manager."
  fi
  [[ -d $HOME/storage ]] || { command -v termux-setup-storage >/dev/null 2>&1 && termux-setup-storage; }
  ok "Setup finished."
}
do_install() {
  local dest="${PREFIX:-/usr/local}/bin/vc"
  cp -f -- "${BASH_SOURCE[0]}" "$dest" && chmod +x "$dest" && ok "Installed by $CREATOR. Run it with:  vc" || err "Install failed ($dest)"
}

# ---------------------------------------------------------------- settings ---
set_codec() {
  local c old=$CODEC maxc
  echo " 1) x265  H.265/HEVC   - smallest files (default)"
  echo " 2) x264  H.264/AVC    - plays everywhere, ~40% bigger"
  echo " 3) hw265 hardware H.265 (MediaCodec) - fast, experimental"
  echo " 4) hw264 hardware H.264 (MediaCodec) - fast, experimental"
  echo " 5) av1   AV1 (SVT-AV1) - next-gen, ~30% smaller, needs a modern player"
  echo " 6) vp9   VP9 (libvpx) - WebM / web browsers, ~25% smaller than H.264"
  c=$(ask "Choose" "")
  case $c in 1) CODEC=x265;; 2) CODEC=x264;; 3) CODEC=hw265;; 4) CODEC=hw264;; 5) CODEC=av1;; 6) CODEC=vp9;; *) return;; esac
  if [[ $CODEC == vp9 ]] && ! have_enc libvpx-vp9; then
    warn "This ffmpeg build has no libvpx-vp9. Keeping $old."; CODEC=$old; return
  fi
  if [[ $CODEC == hw* ]] && ! have_enc "$(hw_encoder_name)"; then
    warn "This ffmpeg build has no $(hw_encoder_name). Keeping $old."; CODEC=$old; return
  fi
  if [[ $CODEC == av1 ]] && ! have_enc libsvtav1; then
    warn "This ffmpeg build has no libsvtav1. Keeping $old."; CODEC=$old; return
  fi
  if   [[ $old == x265 && $CODEC == x264 ]]; then CRF=$(( CRF - 5 ))
  elif [[ $old == x264 && $CODEC == x265 ]]; then CRF=$(( CRF + 5 ))
  elif [[ $old == x265 && $CODEC == av1 ]];  then CRF=$(( CRF + 8 ))
  elif [[ $old == av1 && $CODEC == x265 ]];  then CRF=$(( CRF - 8 ))
  elif [[ $old == x264 && $CODEC == av1 ]];  then CRF=$(( CRF + 13 ))
  elif [[ $old == av1 && $CODEC == x264 ]];  then CRF=$(( CRF - 13 ))
  elif [[ $old == x265 && $CODEC == vp9 ]];  then CRF=$(( CRF + 7 ))
  elif [[ $old == x264 && $CODEC == vp9 ]];  then CRF=$(( CRF + 8 ))
  elif [[ $old == vp9 && $CODEC == x265 ]];  then CRF=$(( CRF - 7 ))
  elif [[ $old == vp9 && $CODEC == x264 ]];  then CRF=$(( CRF - 8 )); fi
  maxc=51; [[ $CODEC == av1 ]] && maxc=60; [[ $CODEC == vp9 ]] && maxc=63
  (( CRF < 0 )) && CRF=0; (( CRF > maxc )) && CRF=$maxc
  PRESET_NAME=custom
}
set_mode() {
  local c def
  echo " 1) Constant quality (CRF / bitrate) - best quality per MB"
  echo " 2) Target file size (two-pass)      - e.g. 'under 100 MB'"
  c=$(ask "Choose" "")
  case $c in
    1) TARGET_MB=0
       if [[ $CODEC == hw* ]]; then VBR=$(ask_int "Video bitrate in kbps" 100 30000 "$VBR")
       else info "x265: 22 high / 26 balanced / 30 small   |   x264: 18 / 23 / 27   |   av1: 30-40"
            CRF=$(ask_int "CRF" 0 60 "$CRF"); fi;;
    2) def=$TARGET_MB; (( def > 0 )) || def=95
       TARGET_MB=$(ask_int "Target size in MB" 1 20000 "$def");;
    *) return;;
  esac
  PRESET_NAME=custom
}
set_res() {
  local c
  echo " 1) keep original  2) 1080p  3) 720p  4) 576p  5) 480p  6) 360p  7) 240p  8) custom"
  c=$(ask "Choose" "")
  case $c in
    1) HEIGHT=0;; 2) HEIGHT=1080;; 3) HEIGHT=720;; 4) HEIGHT=576;; 5) HEIGHT=480;; 6) HEIGHT=360;; 7) HEIGHT=240;;
    8) HEIGHT=$(ask_int "Max short side in pixels" 100 4320 720);;
    *) return;;
  esac
  PRESET_NAME=custom
}
set_fps() {
  local c
  echo " 1) keep original  2) 60  3) 30  4) 24  5) 15  6) custom"
  c=$(ask "Choose" "")
  case $c in
    1) FPS=0;; 2) FPS=60;; 3) FPS=30;; 4) FPS=24;; 5) FPS=15;;
    6) FPS=$(ask_int "Max frame rate" 5 120 30);;
    *) return;;
  esac
  PRESET_NAME=custom
}
set_speed() {
  local c list=(ultrafast superfast veryfast faster fast medium slow slower veryslow) i
  info "Slower = smaller file / better quality at the same CRF, but takes longer."
  for i in "${!list[@]}"; do printf ' %d) %s\n' $(( i + 1 )) "${list[i]}"; done
  c=$(ask "Choose" "")
  if [[ $c =~ ^[1-9]$ ]] && (( c <= ${#list[@]} )); then SPEED=${list[c-1]}; PRESET_NAME=custom; fi
}
set_audio() {
  local c
  echo " 1) AAC 128k  2) AAC 96k  3) AAC 64k  4) AAC 48k (voice)  5) copy  6) remove audio  7) custom kbps"
  c=$(ask "Choose" "")
  case $c in
    1) AUDIO=aac; ABR=128;; 2) AUDIO=aac; ABR=96;; 3) AUDIO=aac; ABR=64;; 4) AUDIO=aac; ABR=48;;
    5) AUDIO=copy;; 6) AUDIO=none;;
    7) AUDIO=aac; ABR=$(ask_int "AAC bitrate in kbps" 16 320 96);;
    *) return;;
  esac
  PRESET_NAME=custom
}
set_denoise() {
  local c
  echo " 1) off  2) light  3) medium  4) strong   (denoise makes noisy/dark footage compress much smaller)"
  c=$(ask "Choose" "")
  case $c in 1) DENOISE=0;; 2) DENOISE=1;; 3) DENOISE=2;; 4) DENOISE=3;; *) return;; esac
  PRESET_NAME=custom
}
set_trim() {
  local s e
  info "Times: seconds (90), mm:ss (1:30) or hh:mm:ss. Leave blank to clear."
  s=$(ask "Start" ""); e=$(ask "End  " "")
  TRIM_START=""; TRIM_END=""
  if [[ -n $s ]]; then TRIM_START=$(to_sec "$s") || { err "Invalid start time."; TRIM_START=""; }; fi
  if [[ -n $e ]]; then TRIM_END=$(to_sec "$e")   || { err "Invalid end time.";   TRIM_END="";   }; fi
  if [[ -n $TRIM_START && -n $TRIM_END ]] && ! awk -v a="$TRIM_START" -v b="$TRIM_END" 'BEGIN{ exit !(b > a) }'; then
    err "End must be after start."; TRIM_START=""; TRIM_END=""
  fi
}
set_outdir() {
  local c s="$HOME/storage/shared" p
  echo " 1) same folder as source"
  echo " 2) /sdcard/Movies/VidCompress"
  echo " 3) /sdcard/Download/VidCompress"
  echo " 4) custom path"
  c=$(ask "Choose" "")
  case $c in
    1) OUTDIR="";;
    2) OUTDIR="$s/Movies/VidCompress";;
    3) OUTDIR="$s/Download/VidCompress";;
    4) p=$(ask "Folder path" ""); p=${p/#\~/$HOME}; [[ -n $p ]] && OUTDIR=$p;;
  esac
}
set_suffix() { SUFFIX=$(ask "Filename suffix" "$SUFFIX"); SUFFIX=${SUFFIX//\//_}; }
set_parallel() { PARALLEL_JOBS=$(ask_int "Parallel jobs (1 = one file at a time)" 1 8 "$PARALLEL_JOBS"); }
set_format() {
  local c
  echo " 1) MP4  - most compatible (soft subtitles)"
  echo " 2) MKV  - keeps any subtitles, many streams"
  echo " 3) WebM - for websites (VP9/AV1 + Opus: vc switches the codec)"
  echo " 4) MOV  - Apple / editing tools (like MP4)"
  echo " 5) AVI  - old players (H.264 + MP3, no subtitles)"
  echo " 6) TS   - broadcast / some TVs (no subtitles)"
  c=$(ask "Choose" "")
  case $c in 1) OUT_EXT=mp4;; 2) OUT_EXT=mkv;; 3) OUT_EXT=webm;; 4) OUT_EXT=mov;; 5) OUT_EXT=avi;; 6) OUT_EXT=ts;; esac
}
set_submode() {
  local c
  echo " 1) off   2) embed matching .srt as soft subtitle (default)   3) burn .srt into the picture"
  c=$(ask "Choose" "")
  case $c in 1) SUB_MODE=off;; 2) SUB_MODE=soft;; 3) SUB_MODE=burn;; esac
}
set_subfile() {
  local p
  echo " Current: ${SUB_FILE:-auto-find (same name as the video)}"
  p=$(ask "Path to .srt (blank = auto-find)" "")
  SUB_FILE=${p/#\~/$HOME}
}
set_sublang() { SUB_LANG=$(ask "Language code for embedded subtitles (fa, en, ...)" "$SUB_LANG"); }
set_substyle() {
  local c
  echo " 1) small white   2) medium white   3) medium yellow   4) large white"
  c=$(ask "Choose" "2")
  case $c in
    1) SUB_SIZE=18; SUB_COLOR="&H00FFFFFF";;
    3) SUB_SIZE=24; SUB_COLOR="&H0000FFFF";;
    4) SUB_SIZE=32; SUB_COLOR="&H00FFFFFF";;
    *) SUB_SIZE=24; SUB_COLOR="&H00FFFFFF";;
  esac
}
set_finish() {
  local c
  echo " 1) Results menu (open output / compare / side-by-side video)"
  echo " 2) Summary only"
  echo " 3) Summary + open first output in the player"
  c=$(ask "Choose" "1")
  case $c in 2) FINISH_ACTION=summary;; 3) FINISH_ACTION=open;; *) FINISH_ACTION=menu;; esac
}

settings_menu() {
  local c
  while true; do
    clear_screen
    printf '%s== Advanced settings ==%s  (base: %s)\n\n' "$C_B" "$C_0" "$PRESET_NAME"
    printf '  1) Video codec      %s\n'  "$(codec_label)"
    printf '  2) Quality mode     %s\n'  "$(mode_label)"
    printf '  3) Max resolution   %s\n'  "$(res_label)"
    printf '  4) Max frame rate   %s\n'  "$(fps_label)"
    printf '  5) Encoder speed    %s\n'  "$SPEED"
    printf '  6) Audio            %s\n'  "$(audio_label)"
    printf '  7) Denoise          %s\n'  "$(denoise_label)"
    printf '  8) Trim             %s\n'  "$(trim_label)"
    printf '  9) Output folder    %s\n'  "$(out_label)"
    printf ' 10) Filename suffix  %s\n'  "$SUFFIX"
    printf ' 11) Strip metadata   %s\n'  "$(yn_label "$STRIP_META")"
    printf ' 12) Delete originals %s  (only after a verified result)\n' "$(yn_label "$DELETE_ORIG")"
    printf ' 13) Parallel jobs    %s  (batch speed)\n' "$PARALLEL_JOBS"
    printf ' 14) Output format    %s\n'  "$OUT_EXT"
    printf ' 15) Keep subtitles   %s  (existing subtitle tracks)\n' "$(yn_label "$KEEP_SUBS")"
    printf ' 16) Subtitle mode    %s\n'  "$(sub_mode_label)"
    printf ' 17) Subtitle file    %s\n'  "${SUB_FILE:-auto-find}"
    printf ' 18) Subtitle style   %s  (burn-in)\n' "$(sub_style_label)"
    printf ' 19) Subtitle lang    %s\n'  "$SUB_LANG"
    printf ' 20) After finishing  %s\n'  "$(finish_label)"
    printf ' 21) Resume mode      %s  (skip files that already have a finished output)\n' "$(yn_label "$SKIP_DONE")"
    printf ' 22) Frame extractor  %s, %s, %s\n' "$(frame_fmt_label)" "$(frame_step_label)" "$(frame_h_label)"
    printf ' 23) Downscaler       %s\n' "$( [[ $SCALER == lanczos ]] && echo "Lanczos (sharper, files ~5% bigger)" || echo "bicubic (default)" )"
    printf ' 26) Deinterlace      %s  (DVD / TV recordings)\n' "$(yn_label "$DEINT")"
    printf ' 27) Auto-crop bars   %s  (removes black bars: smaller files)\n' "$(yn_label "$AUTOCROP")"
    printf ' 24) CPU cores        %s  [now: %s]\n' "$CORES" "${PIN_NOTE:-all cores}"
    printf ' 25) Encoder threads  %s\n' "$( (( THREADS > 0 )) && echo "$THREADS (fixed)" || echo "auto" )"
    printf '\n  s) save as default     b) back\n'
    read -r -p "Edit: " c || exit 0
    case $c in
      1) set_codec;; 2) set_mode;; 3) set_res;; 4) set_fps;; 5) set_speed;; 6) set_audio;;
      7) set_denoise;; 8) set_trim;; 9) set_outdir;; 10) set_suffix;;
      11) STRIP_META=$(( 1 - STRIP_META ));;
      12) if (( DELETE_ORIG )); then DELETE_ORIG=0
          else warn "Originals will be DELETED after successful compression (not for trimmed clips)."
               yesno "Enable?" n && DELETE_ORIG=1; fi;;
      13) set_parallel;;
      14) set_format;;
      15) KEEP_SUBS=$(( 1 - KEEP_SUBS ));;
      16) set_submode;;
      17) set_subfile;;
      18) set_substyle;;
      19) set_sublang;;
      20) set_finish;;
      21) SKIP_DONE=$(( 1 - SKIP_DONE ));;
      22) frames_options;;
      23) if [[ $SCALER == lanczos ]]; then SCALER=bicubic; else SCALER=lanczos; fi; PRESET_NAME=custom;;
      26) DEINT=$(( 1 - DEINT ));;
      27) AUTOCROP=$(( 1 - AUTOCROP ));;
      24) detect_cpu
          [[ -n $CPU_TOPO ]] && info "Layout: $CPU_TOPO"
          echo " 1) auto  (only the fast cores - test with the CPU test first)"
          echo " 2) all cores (default)"
          echo " 3) custom list, e.g. 4-7"
          c=$(ask "Choose" "2")
          case $c in
            1) CORES=auto;;
            2) CORES=all;;
            3) c=$(ask "Core list" "${BIG_LIST:-4-7}")
               if mask_of_list "$c"; then CORES=$c; else err "Use numbers like 4-7 or 0,2,4."; sleep 1; fi;;
          esac
          reapply_cores; info "CPU: $PIN_NOTE"; sleep 1;;
      25) THREADS=$(ask_int "Encoder threads in total (0 = auto)" 0 128 "$THREADS"); calc_threads 1;;
      s|S) save_settings; ok "Saved as default."; sleep 1;;
      b|B|"") return;;
    esac
  done
}

preset_menu() {
  local p i=0 c names=()
  clear_screen
  printf '%s== Presets ==%s\n\n' "$C_B" "$C_0"
  for p in $PRESET_LIST; do
    i=$(( i + 1 )); names+=("$p")
    printf ' %2d) %-9s %s\n' "$i" "$p" "$(trunc "$(preset_desc "$p")")"
  done
  echo
  c=$(ask "Choose (blank = back)" "")
  if [[ $c =~ ^[0-9]+$ ]] && (( c >= 1 && c <= ${#names[@]} )); then
    apply_preset "${names[c-1]}" || { err "Unknown preset."; return; }
    ok "Preset '${names[c-1]}' applied."
    if (( TARGET_MB > 0 )); then
      TARGET_MB=$(ask_int "Target size in MB" 1 20000 "$TARGET_MB")
    fi
    sleep 1
  fi
}

profile_menu() {
  local c n files=() i f
  while true; do
    clear_screen
    printf '%s== Profiles ==%s\n\n' "$C_B" "$C_0"
    mapfile -t files < <(find "$PROF_DIR" -maxdepth 1 -name '*.conf' -printf '%f\n' 2>/dev/null | sort)
    if (( ${#files[@]} == 0 )); then echo "  (no saved profiles)"; fi
    for i in "${!files[@]}"; do printf ' %d) %s\n' $(( i + 1 )) "${files[i]%.conf}"; done
    printf '\n  s) save current settings as a profile   d) delete one   b) back\n'
    read -r -p "Load number / option: " c || exit 0
    case $c in
      s|S) n=$(ask "Profile name" ""); n=${n//[^A-Za-z0-9_-]/}
           if [[ -n $n ]]; then mkdir -p "$PROF_DIR"; write_settings "$PROF_DIR/$n.conf"; ok "Saved profile '$n'."; sleep 1; else err "Invalid name."; fi;;
      d|D) n=$(ask "Number to delete" "")
           if [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#files[@]} )); then rm -f "$PROF_DIR/${files[n-1]}"; ok "Deleted."; fi;;
      b|B|"") return;;
      *[!0-9]*) ;;
      *) if (( c >= 1 && c <= ${#files[@]} )); then load_conf "$PROF_DIR/${files[c-1]}"; ok "Loaded '${files[c-1]%.conf}'."; sleep 1; return; fi;;
    esac
  done
}

tools_menu() {
  local c
  while true; do
    clear_screen
    printf '%s== Tools ==%s\n\n' "$C_B" "$C_0"
    echo " 1) Video info (selected files)"
    echo " 2) Estimate output size (20 s test encode)"
    echo " 3) Subtitle studio (add / extract / remove SRT)"
    echo " 4) Make GIF from a video          (one or many)"
    echo " 5) Extract audio (MP3 / M4A)       (one or many)"
    echo " 6) Thumbnail / contact sheet       (one or many)"
    echo " 7) Check installation / encoders"
    echo " 8) Setup (install ffmpeg, storage access)"
    echo " 9) Install 'vc' command"
    echo "10) Show last log"
    echo "11) Extract frames (time range -> new folder)"
    echo "12) Speed lab (preset race, CPU test, heat test)"
    echo " b) back"
    read -r -p "> " c || exit 0
    case $c in
      1) need_queue && { run_on_picked "Video info" show_info; pause; };;
      2) estimate_size; pause;;
      3) sub_studio;;
      4) tool_on_queue make_gif "Make GIF"; pause;;
      5) tool_on_queue extract_audio "Extract audio"; pause;;
      6) tool_on_queue make_thumb "Thumbnail"; pause;;
      7) check_deps; pause;;
      8) do_setup; pause;;
      9) do_install; pause;;
      10) if [[ -s $LOG ]]; then tail -n 40 "$LOG"; else echo "(log is empty)"; fi; pause;;
      11) frames_flow; pause;;
      12) race_menu;;
      b|B|"") return;;
    esac
  done
}

# ------------------------------------------------------------- main menu ----
print_plan() {
  local tot
  sum_sizes; tot=$SEL_BYTES
  printf '\n%s== Plan ==%s\n' "$C_B" "$C_0"
  printf '  Files      : %d (%s)\n' "${#SELECTED[@]}" "$(human "$tot")"
  printf '  Codec      : %s\n' "$(codec_label)"
  printf '  Quality    : %s\n' "$(mode_label)"
  printf '  Resolution : %s\n' "$(res_label)"
  printf '  Frame rate : %s\n' "$(fps_label)"
  printf '  Speed      : %s\n' "$SPEED"
  printf '  Audio      : %s\n' "$(audio_label)"
  printf '  Subtitles  : %s   (keep existing: %s)\n' "$(sub_mode_label)" "$(yn_label "$KEEP_SUBS")"
  printf '  Format     : %s   Parallel: %s job(s)\n' "$OUT_EXT" "$PARALLEL_JOBS"
  printf '  Output     : %s/%s%s.%s\n' "$(out_label)" "<name>" "$SUFFIX" "$OUT_EXT"
  (( DELETE_ORIG )) && printf '  %sOriginals will be deleted after success.%s\n' "$C_Y" "$C_0"
  echo
}
start_flow() {
  if (( ${#SELECTED[@]} == 0 )); then warn "Select at least one video first (option 1)."; pause; return; fi
  print_plan
  yesno "Start compression?" y || return
  run_batch
  pause
  finish_flow
}
main_menu() {
  local c n tot f
  while true; do
    clear_screen
    n=${#SELECTED[@]}
    sum_sizes; tot=$SEL_BYTES
    printf '%sVidCompress v%s%s  -  by %s\n' "$C_B" "$VERSION" "$C_0" "$CREATOR"
    printf '%s%s  |  %s cores  |  ffmpeg %s%s\n' "$C_D" "$WEBSITE" "${NCPU:-?}" "${FF_VER:-?}" "$C_0"
    (( PIN_N > 0 )) && printf '%sCPU: %s%s\n' "$C_D" "$PIN_NOTE" "$C_0"
    printf '%s------------------------------------------%s\n' "$C_D" "$C_0"
    if (( n == 0 )); then printf ' Selected : nothing yet - press 1 to see your videos\n'
    else printf ' Selected : %d file(s), %s\n' "$n" "$(human "$tot")"; fi
    printf ' Preset   : %s\n' "$PRESET_NAME"
    printf ' Plan     : %s\n\n' "$(trunc "$(plan_line)")"
    echo " 1) Choose videos (newest first, or search a name)"
    echo " 2) Queue (view / remove)"
    echo " 3) Choose preset"
    echo " 4) Advanced settings"
    echo " 5) Profiles (save / load)"
    echo " 6) Subtitle studio (SRT add / extract / remove)"
    echo " 7) Repair & sync (fix A/V drift for TVs)"
    echo " 8) Tools (info, estimate, GIF, audio, thumbs)"
    echo " 9) START compression"
    echo " f) Extract frames (time range -> new folder)"
    echo " t) Speed lab & AUTO-TUNE (fastest settings for this phone)"
    echo " w) W6W vault (encrypted .w6w: video, pictures, text, audio ...)"
    echo " r) Results & compare (last batch)"
    echo " c) Clear selection"
    echo " 0) Quit"
    read -r -p "> " c || exit 0
    case $c in
      1) choose_videos;;
      2) queue_menu;;
      3) preset_menu;;
      4) settings_menu;;
      5) profile_menu;;
      6) sub_studio;;
      7) repair_menu;;
      8) tools_menu;;
      9) start_flow;;
      f|F) frames_flow; pause;;
      t|T) race_menu;;
      w|W) w6w_menu;;
      r|R) results_menu;;
      c|C) SELECTED=();;
      0|q|Q) exit 0;;
    esac
  done
}

# --------------------------------------------------------------------- CLI ---
usage() {
  cat <<EOF
VidCompress v$VERSION - ffmpeg video compression toolkit for Termux
Creator : $CREATOR
Website : $WEBSITE

Usage:
  vc                          interactive menu
  vc --sub                    subtitle studio (add / extract / remove SRT)
  vc [options] FILE|DIR ...   preload files/folders (menu opens unless -y)

Options:
  -p PRESET   balanced | quality | small | tiny | social | compat | fast | turbo | target | hardware | av1
  -t MB       target size in MB (two-pass), e.g. -t 95
  -c CRF      constant quality (x265: 22-30, x264: 18-27, av1: 30-45; lower = better)
  -r PIXELS   max short side: 1080, 720, 480 ... (0 = keep original)
  -f FPS      max frame rate (0 = keep)
  -s SPEED    ultrafast ... medium ... veryslow
  -k CODEC    x265 | x264 | av1 | hw265 | hw264
  -a AUDIO    copy | none | <kbps>   e.g. -a 64
  -S TIME     trim start (90, 1:30, 0:01:30)
  -E TIME     trim end
  -o DIR      output folder (default: next to the source)
  -j JOBS     parallel jobs, 1-8 (default 1; try 2-3 for hw encoders)
  -d          delete originals after verified success
  -y          start immediately, no menu
  -h          this help

Subtitle options:
  --srt FILE       embed FILE as a soft (selectable) subtitle track
  --srt-burn FILE  burn FILE permanently into the video picture
  --nosrt          no subtitle handling at all
  --keepsubs       keep the video's existing subtitle tracks (default)
  --nosubs         drop existing subtitle tracks
  --mkv            output as .mkv instead of .mp4
  (FILE='auto' finds a .srt with the same name next to the video)

Frame extractor (every frame between two times -> a NEW folder):
  --frames FILE          with -S START -E END (end: 1:40 | 100 | +10 = 10 s after start)
                         range = [start, end): start frame in, end frame out
  --frame-format FMT     jpg (default) | png | bmp | webp
  --frame-quality N      jpg/webp quality 1-31 (1 = best, default 2)
  --frame-step N|key     every Nth frame, or "key" = keyframes only (very fast)
  --frame-height PX      scale pictures to at most PX high (default: original)
  -o DIR                 create the frames folder inside DIR (default: next to video)
  (no -S/-E in a terminal: an interactive question-and-answer flow starts)

Speed tools:
  --race FILE            encode a sample with every preset: real speed, size, time, quality
  --race-cores FILE      same encode on all cores / fewer threads / big cores only
  --stamina FILE         heat test: repeat an encode, watch speed + temperature + clock
  --race-all FILE        all three (a few minutes); --no-quality skips the SSIM scoring
  --cpu                  show CPU layout (big/little), pinning and readable sensors
  --tune [FILE]          AUTO-TUNE: test this phone, pick + save the best preset and CPU setup
  --w6w CMD ...          .w6w vault (encrypted container for video, pictures, audio, text, scripts):
                           pack OUT.w6w FILE|FOLDER ...  [--squeeze] [--password] [--comment TEXT]
                           info F.w6w | verify F.w6w | play F.w6w [N] | key show|export|import HEX|new
                           extract F.w6w [-o DIR] [N ...] | convert F.w6w [--to FMT] [-o DIR] [N ...]
  --goal G               for --tune: speed | balanced (default) | size | quality
  --cores all|auto|LIST  all cores (default), the fast cores only (auto), or e.g. 4-7
  --threads N            fixed encoder thread budget (0 = auto)
  --resume               skip files whose finished output already exists
  --lanczos              sharper downscaling (files ~5% bigger); --bicubic = default
  --format FMT           output container: mp4 (default) | mkv | webm | mov | avi | ts
  --no-deint             do not deinterlace DVD / TV sources;  --autocrop = remove black bars

Repair & sync options:
  --repair FILE...       fix A/V drift and make the file play on any TV/USB
                         player. Smart tiers: remux-only / audio-only /
                         video-only / full rebuild - the fastest path that
                         really fixes it (turbo x264 by default). Add -j N
                         to repair several files in parallel.
  --diagnose FILE        report sync / TV-compatibility problems (no changes)
  --quickfix FILE        remux only, no re-encode: faststart + clean timestamps
  --sync-shift MS FILE   shift the audio: +250 = delay 250 ms, -250 = advance
  --fps RATE             force the output frame rate for --repair (e.g. 25)
  --repair-crf N         repair re-encode quality (default 16 = turbo: same
                         quality as 18 @ medium, about 2x faster)
  --repair-preset NAME   repair encoder speed (default veryfast)
  --oldtv                ultra compatibility: Main profile, no B-frames, <=30 fps
  --stereo               downmix surround audio to stereo

Other commands:
  vc --setup      install ffmpeg and storage access
  vc --install    install this script as the 'vc' command
  vc --version

Examples:
  vc -y -p target -t 95 movie.mp4             # under 100 MB, 720p
  vc -y -p av1 movie.mp4                      # next-gen AV1, smallest files
  vc -y -j 3 -p turbo ~/storage/movies       # 3 files at once
  vc -y --srt auto -p balanced movie.mp4      # compress + embed movie.srt
  vc -y --srt-burn auto -p social movie.mp4   # compress + burn subtitles
  vc -y -p small --mkv movie.mp4              # mkv output (native srt subs)
  vc --diagnose movie.mkv                     # what is wrong with this file?
  vc --repair movie.mkv                       # fix drift, TV-ready output
  vc --repair --oldtv movie.mkv               # ancient TV / USB stick mode
  vc --repair -j 4 *.mp4                      # repair 4 files at once
  vc --sync-shift -250 movie.mp4              # audio was 250 ms late
  vc --frames movie.mp4 -S 1:30 -E 1:40       # all frames 1:30 -> 1:40, new folder
  vc --frames movie.mp4 -S 90 -E +5 --frame-format png
  vc --frames movie.mp4 -S 0 -E 60 --frame-step key --frame-height 480
  vc --race movie.mp4                         # which preset suits this phone?
  vc movie.mp4 -p turbo -y                    # options may follow the file
  vc movie.mkv -p web -y                      # VP9 + Opus in WebM (websites)
  vc --w6w pack trip.w6w movie.mp4 movie.srt cover.jpg notes.txt   # one encrypted file
  vc --w6w info trip.w6w ;  vc --w6w convert trip.w6w --to mp4
  vc old_dvd.vob --format mp4 --autocrop -y   # DVD rip: deinterlaced, bars removed
EOF
}

cleanup() {
  if [[ -n $BATCH_TMP && -d $BATCH_TMP ]]; then
    local m
    for m in "$BATCH_TMP"/part_*; do
      [[ -f $m ]] || continue
      rm -f -- "$(cat -- "$m" 2>/dev/null)" 2>/dev/null
      rm -f -- "$m"
    done
    rm -rf -- "$BATCH_TMP"
  fi
  [[ -n $TMPD ]] && rm -rf -- "$TMPD"
  [[ -n $FREQ_PID ]] && kill "$FREQ_PID" 2>/dev/null
  [[ -n $FREQ_FILE ]] && rm -f -- "$FREQ_FILE"
  # remove the local build area with anything left in it (crashed jobs etc.)
  [[ -n $STAGE_ROOT && -d $STAGE_ROOT ]] && rm -rf -- "$STAGE_ROOT"
  wake_unlock
}
on_int() {
  printf '\n'; warn "Interrupted - cleaning up."
  [[ -n $CUR_TMP ]] && rm -f -- "$CUR_TMP"
  [[ -n $CUR_TMPDIR && -d $CUR_TMPDIR ]] && rm -rf -- "$CUR_TMPDIR"
  [[ -n $FREQ_PID ]] && kill "$FREQ_PID" 2>/dev/null
  exit 130
}

# ======================================================================= .W6W VAULT
# A .w6w file is ONE encrypted container that can hold anything: videos, pictures, audio,
# text, scripts (.sh .py ...), subtitles, documents, other files. vc looks at every item
# when it is packed, remembers what it is (kind, codecs, size, linked subtitle) and can
# later list, play/view, extract and convert it. Only vc + the right key can open it.
#
#   file layout (v1)          bytes
#     "W6W1"                  0-3    magic
#     mode  'D' | 'P'         4      D = this phone's device key, P = password
#     flags + reserved        5-7
#     salt                    8-15   8 random bytes (PBKDF2)
#     iv                      16-31  16 random bytes (AES-CBC)
#     ciphertext              32-... AES-256-CBC( tar( W6W.MANIFEST, e001, e002 ... ) )
#     HMAC-SHA256             last 32 bytes, over everything before it (encrypt-then-MAC)
#   keys: PBKDF2-HMAC-SHA256, 200000 rounds; separate keys for encryption and MAC.
W6W_ITER=200000
W6W_SQUEEZE=0; W6W_PWMODE=0; W6W_TO=""; W6W_COMMENT=""; W6W_SECRET=""; W6W_MAC_SECRET=""
W6W_KEY=""; W6W_IV=""; W6W_MK=""; W6W_DEVKEY=""; W6W_PASSWORD=${W6W_PASSWORD:-}; LAST_OUT=""
W_CREATED=""; W_COMMENT_TXT=""; W_N=0; WD_KIND=""; WD_EXT=""; WD_DETAIL=""; WD_DUR=""
declare -a W_KIND=() W_EXT=() W_STORED=() W_SIZE=() W_DUR=() W_FOR=() W_MT=() W_DETAIL=() W_NAME=()

w6w_have_tools() { command -v openssl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1 && command -v od >/dev/null 2>&1 \
  || { err ".w6w needs openssl, tar and od.  Install:  pkg install openssl-tool tar coreutils"; return 1; }; }
w6w_hex_rand() { head -c "$1" /dev/urandom | od -An -v -tx1 | tr -d ' \n'; }
w6w_hex2bin()  { local esc; esc=$(sed 's/../\\x&/g' <<<"$1"); printf '%b' "$esc"; }
w6w_field()    { od -An -v -tx1 -j "$2" -N "$3" -- "$1" | tr -d ' \n'; }          # file offset length -> hex
w6w_enc()      { printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n' | sed 's/../%&/g'; }   # every byte as %HH
w6w_dec()      { local s=${1//%/\\x}; printf '%b' "$s"; }
w6w_is()       { [[ $(head -c 4 -- "$1" 2>/dev/null) == W6W1 ]]; }
w6w_fp()       { printf '%s' "$1" | sha256sum | cut -c1-12; }

w6w_device_key() {   # W6W_DEVKEY = this install's random 256-bit key (created once, mode 600)
  local kf="$CONF_DIR/w6w.key"
  if [[ ! -s $kf ]]; then
    mkdir -p "$CONF_DIR"
    ( umask 077; w6w_hex_rand 32 > "$kf" )
    W6W_DEVKEY=$(<"$kf")
    warn "A new device key was created [$(w6w_fp "$W6W_DEVKEY")]. Back it up now: vc --w6w key export  (after a reinstall or data wipe, device-mode .w6w files cannot be opened without it)."
  fi
  W6W_DEVKEY=$(<"$kf")
}
w6w_secret_for() {   # $1 mode D|P  $2 "confirm" (ask twice when creating) -> W6W_SECRET
  local a b
  case $1 in
    D) w6w_device_key; W6W_SECRET=$W6W_DEVKEY;;
    P) if [[ -n $W6W_PASSWORD ]]; then W6W_SECRET=$W6W_PASSWORD
       else
         [[ -t 0 ]] || { err "Password needed: set W6W_PASSWORD or run in a terminal."; return 1; }
         read -r -s -p "Password: " a; echo >&2
         if [[ ${2:-} == confirm ]]; then
           read -r -s -p "Repeat password: " b; echo >&2
           [[ $a == "$b" ]] || { err "Passwords differ."; return 1; }
         fi
         [[ -n $a ]] || { err "Empty password."; return 1; }
         W6W_SECRET=$a; W6W_PASSWORD=$a          # remembered for this run only
       fi;;
    *) err "Unknown W6W mode '$1'."; return 1;;
  esac
}
w6w_derive() {   # $1 salt-hex -> W6W_KEY (encryption) and W6W_MK (MAC), both hex
  local out
  export W6W_SECRET W6W_MAC_SECRET="mac:$W6W_SECRET"
  out=$(openssl enc -aes-256-cbc -pbkdf2 -iter "$W6W_ITER" -md sha256 -S "$1" -pass env:W6W_SECRET -P 2>/dev/null) || return 1
  W6W_KEY=$(sed -n 's/^key=//p' <<<"$out")
  out=$(openssl enc -aes-256-cbc -pbkdf2 -iter "$W6W_ITER" -md sha256 -S "$1" -pass env:W6W_MAC_SECRET -P 2>/dev/null) || return 1
  W6W_MK=$(sed -n 's/^key=//p' <<<"$out")
  [[ ${#W6W_KEY} -eq 64 && ${#W6W_MK} -eq 64 ]]
}
w6w_unlock() {   # $1 file  [$2 noverify] -> W6W_KEY W6W_IV W6W_MK ; verifies the MAC (wrong key / damaged file) unless noverify
  local f=$1 mode sz mac want salt
  w6w_have_tools || return 1
  w6w_is "$f" || { err "Not a .w6w file: $f"; return 1; }
  mode=$(head -c 5 -- "$f" | tail -c 1)
  w6w_secret_for "$mode" || return 1
  salt=$(w6w_field "$f" 8 8); W6W_IV=$(w6w_field "$f" 16 16)
  w6w_derive "$salt" || { err "Key derivation failed (is openssl working?)."; return 1; }
  if [[ ${2:-} != noverify ]]; then
    sz=$(stat -c %s -- "$f"); (( sz > 80 )) || { err "File is too short / damaged."; return 1; }
    mac=$(head -c -32 -- "$f" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$W6W_MK" -binary | od -An -v -tx1 | tr -d ' \n')
    want=$(w6w_field "$f" $(( sz - 32 )) 32)
    if [[ $mac != "$want" ]]; then
      err "Cannot open: wrong key/password, or the file was changed or damaged."
      [[ $mode == P ]] && W6W_PASSWORD=""
      return 1
    fi
  fi
  return 0
}
w6w_stream() { tail -c +33 -- "$1" | head -c -32 | openssl enc -d -aes-256-cbc -K "$W6W_KEY" -iv "$W6W_IV"; }

# ---------------------------------------------------------------- what is this file?
w6w_detect() {   # $1 file -> WD_KIND WD_EXT WD_DETAIL WD_DUR
  local f=$1 ext n line k v ctype codec w h br dur vc="" ac="" vw="" vh="" ab="" nf="" isvid=0 isaud=0 fmtn=
  local -a P
  n=${f##*/}; ext=""; [[ $n == *.* ]] && ext=${n##*.}; ext=${ext,,}
  WD_KIND=other; WD_EXT=$ext; WD_DETAIL=""; WD_DUR=""
  case $ext in
    srt|ass|ssa|vtt|sub|sbv|ttml|smi|lrc) WD_KIND=subtitle; WD_DETAIL=$ext; return 0;;
    sh|bash|zsh|ksh|fish|py|pl|rb|php|lua|js|mjs|ps1|bat|cmd|awk|sed|jl|rs|go|c|cpp|h|java|kt|swift)
      WD_KIND=script; WD_DETAIL="$ext source"; return 0;;
    txt|md|log|csv|tsv|json|xml|yaml|yml|ini|conf|cfg|toml|html|htm|css|rst|tex|svg|rtf|srt)
      WD_KIND=text; WD_DETAIL="$ext text"; [[ $ext == svg ]] && WD_KIND=image; return 0;;
    pdf|doc|docx|xls|xlsx|ppt|pptx|odt|ods|odp|epub|mobi) WD_KIND=document; WD_DETAIL=$ext; return 0;;
    zip|rar|7z|tar|gz|tgz|xz|bz2|zst|apk|iso) WD_KIND=archive; WD_DETAIL=$ext; return 0;;
    bin|dat|dll|exe|so|db|sqlite|dex|odex|img|elf|o|a|class|pyc|wasm) WD_KIND=other; WD_DETAIL="binary ($ext)"; return 0;;
  esac
  # look inside with ffprobe (pictures, audio and video of any format ffmpeg knows)
  while IFS= read -r line; do
    ctype=""; codec=""; w=""; h=""; br=""; dur=""; fnm=""
    IFS='|' read -ra P <<<"$line"
    for k in "${P[@]:1}"; do
      v=${k#*=}; k=${k%%=*}
      case $k in format_name) fnm=$v;; codec_type) ctype=$v;; codec_name) codec=$v;; width) w=$v;; height) h=$v;; bit_rate) br=$v;; duration) dur=$v;; nb_frames) nf=$v;; esac
    done
    case ${P[0]} in
      format) [[ $dur =~ ^[0-9]+(\.[0-9]+)?$ ]] && WD_DUR=$dur; fmtn=$fnm;;
      stream)
        case $ctype in
          video) if (( ! isvid )); then isvid=1; vc=$codec; vw=$w; vh=$h; fi;;
          audio) if (( ! isaud )); then isaud=1; ac=$codec; [[ $br =~ ^[0-9]+$ ]] && ab=$(( br / 1000 )); fi;;
        esac;;
    esac
  done < <(ffprobe -v error -show_entries 'format=duration,format_name:stream=codec_type,codec_name,width,height,bit_rate,nb_frames' -of compact -- "$f" 2>/dev/null)
  # ffprobe "recognises" random binary or plain text as ANSI-art / teletext: not real media
  case $fmtn in tty|bin|xbin|ansi|idf|adf|artworx|tmv|image_*pipe*|"") [[ $fmtn == image_* ]] || { isvid=0; isaud=0; };; esac
  case $vc in bintext|xbin|idf|ansi|ascii|tty) isvid=0;; esac
  if (( isvid )); then
    case $ext in
      jpg|jpeg|jfif|png|webp|bmp|tif|tiff|gif|heic|heif|avif|ico|apng) WD_KIND=image;;
      *) case $vc in
           mjpeg|png|bmp|tiff|webp|jpegls|jpeg2000|apng|gif)
             if [[ $nf =~ ^[0-9]+$ ]] && (( nf <= 1 )); then WD_KIND=image; else WD_KIND=video; fi;;
           *) WD_KIND=video;;
         esac;;
    esac
    if [[ $WD_KIND == image ]]; then WD_DETAIL="$vc ${vw}x${vh}"; WD_DUR=""
    else WD_DETAIL="$vc${ac:++$ac} ${vw}x${vh}"; fi
    return 0
  fi
  if (( isaud )); then WD_KIND=audio; WD_DETAIL="$ac${ab:+ ${ab}k}"; return 0; fi
  # not media: text, script or something else
  if [[ -s $f ]] && LC_ALL=C grep -Iq . -- "$f" 2>/dev/null; then
    if [[ $(head -c 2 -- "$f") == '#!' ]]; then WD_KIND=script; WD_DETAIL="script ($(head -n1 -- "$f" | cut -c1-30))"
    else WD_KIND=text; WD_DETAIL="text"; fi
    return 0
  fi
  WD_KIND=other; WD_DETAIL="binary"
  return 0
}
w6w_label() {   # kind -> short upper-case label
  case $1 in video) echo VIDEO;; image) echo IMAGE;; audio) echo AUDIO;; subtitle) echo SUBTITLE;; text) echo TEXT;; script) echo SCRIPT;; document) echo DOCUMENT;; archive) echo ARCHIVE;; *) echo FILE;; esac
}

# ---------------------------------------------------------------- squeeze (smaller before packing)
w6w_squeeze() {   # $1 file $2 kind $3 workdir -> W_SQ = path to use (the original when nothing smaller was made)
  local f=$1 kind=$2 wd=$3 out snap="" insz osz
  W_SQ=$f
  insz=$(fsize "$f")
  case $kind in
    video)
      snap=$(mktemp) || return 0
      write_settings "$snap"
      OUTDIR=$wd; SUFFIX="_w6w"; SUB_MODE=off; DELETE_ORIG=0; TRIM_START=""; TRIM_END=""; SKIP_DONE=0
      LAST_OUT=""
      compress_file "$f" 0 0 >&2 || true
      load_conf "$snap"; rm -f -- "$snap"
      if [[ -n $LAST_OUT && -s $LAST_OUT ]]; then
        osz=$(fsize "$LAST_OUT")
        if (( osz < insz )); then W_SQ=$LAST_OUT; else rm -f -- "$LAST_OUT"; fi
      fi;;
    image)
      [[ $WD_EXT == gif || $WD_EXT == svg ]] && return 0
      have_enc libwebp || return 0
      out="$wd/sq_$$_${RANDOM}.webp"
      if ffmpeg -nostdin -v error -y -i "$f" -frames:v 1 -c:v libwebp -quality 82 "$out" 2>>"$LOG" && [[ -s $out ]] && (( $(fsize "$out") < insz )); then W_SQ=$out; else rm -f -- "$out"; fi;;
    audio)
      if have_enc libopus; then out="$wd/sq_$$_${RANDOM}.opus"; ffmpeg -nostdin -v error -y -i "$f" -vn -c:a libopus -b:a 64k "$out" 2>>"$LOG"
      else out="$wd/sq_$$_${RANDOM}.m4a"; ffmpeg -nostdin -v error -y -i "$f" -vn -c:a aac -b:a 96k "$out" 2>>"$LOG"; fi
      if [[ -s $out ]] && (( $(fsize "$out") < insz )); then W_SQ=$out; else rm -f -- "$out"; fi;;
  esac
  return 0
}

# ---------------------------------------------------------------- pack
w6w_collect() {   # args: files and folders -> W_LIST (every regular file, folders walked, any type)
  local a f
  W_LIST=()
  for a in "$@"; do
    a=${a#[\'\"]}; a=${a%[\'\"]}; a=${a/#\~/$HOME}
    if [[ -d $a ]]; then
      while IFS= read -r f; do [[ -n $f ]] && W_LIST+=("$f"); done < <(find -H "$a" -type f ! -name '.*' 2>/dev/null | LC_ALL=C sort)
    elif [[ -f $a ]]; then W_LIST+=("$(readlink -f -- "$a")")
    else warn "Not found: $a"; fi
  done
  (( ${#W_LIST[@]} ))
}
w6w_pack() {   # $1 output .w6w  then files/folders   (uses W6W_PWMODE, W6W_SQUEEZE, W6W_COMMENT)
  local out=$1 f i n=0 mode=D kind wd man name ext stored src size dur forid mt base b2 j k smp smb xzl
  local -a pf=() ek=() ee=() es=() ez=() ed=() eg=() en=() et=() ef=() ep=() fl=()
  shift
  w6w_have_tools || return 1
  w6w_collect "$@" || { err "Nothing to pack."; return 1; }
  (( W6W_PWMODE )) && mode=P
  w6w_secret_for "$mode" confirm || return 1
  [[ $out == *.w6w ]] || out="$out.w6w"
  wd=$(mktemp -d) || return 1
  # 1) look at every file, 2) optionally squeeze it, 3) store it (text-like files are xz-compressed)
  for f in "${W_LIST[@]}"; do
    n=$(( n + 1 ))
    w6w_detect "$f"; kind=$WD_KIND; ext=$WD_EXT; name=${f##*/}
    src=$f
    if (( W6W_SQUEEZE )) && [[ $kind == video || $kind == image || $kind == audio ]]; then
      info "[$n/${#W_LIST[@]}] squeezing $kind: $(trunc "$name")"
      w6w_squeeze "$f" "$kind" "$wd"; src=$W_SQ
    fi
    size=$(fsize "$src"); dur=${WD_DUR:-0}; mt=$(stat -c %Y -- "$f" 2>/dev/null || echo 0)
    stored=raw
    case $kind in
      text|script|subtitle|document)
        xzl=-9e; (( size > 52428800 )) && xzl=-6        # huge text: a faster level
        if xz $xzl -T0 -c -- "$src" > "$wd/e$(printf '%03d' $n)" 2>/dev/null && [[ -s $wd/e$(printf '%03d' $n) ]]; then stored=xz
        else rm -f -- "$wd/e$(printf '%03d' $n)"; ln -s -- "$src" "$wd/e$(printf '%03d' $n)"; fi;;
      other)
        # compress only if a quick 1 MB sample shows it is worth it (random/encrypted data is not)
        smp=$(head -c 1048576 -- "$src" | xz -1 -c 2>/dev/null | wc -c); smb=$(( size < 1048576 ? size : 1048576 ))
        if (( smb > 0 && smp * 100 < smb * 85 )) && xz -6 -T0 -c -- "$src" > "$wd/e$(printf '%03d' $n).try" 2>/dev/null \
             && (( $(fsize "$wd/e$(printf '%03d' $n).try") * 100 < size * 95 )); then
          mv -f -- "$wd/e$(printf '%03d' $n).try" "$wd/e$(printf '%03d' $n)"; stored=xz
        else rm -f -- "$wd/e$(printf '%03d' $n).try"; ln -s -- "$src" "$wd/e$(printf '%03d' $n)"; fi;;
      *) ln -s -- "$src" "$wd/e$(printf '%03d' $n)";;
    esac
    if [[ $src != "$f" ]]; then   # squeezed: the stored name/extension follows the new file
      name="${name%.*}.${src##*.}"; ext=${src##*.}
    fi
    ek[n]=$kind; ee[n]=${ext:-none}; es[n]=$stored; ez[n]=$size; ed[n]=$dur; et[n]=$mt; ep[n]=$(w6w_enc "$WD_DETAIL"); en[n]=$(w6w_enc "$name"); eg[n]=${name%.*}
    ef[n]=0
  done
  # link each subtitle to the video with the same base name
  for (( i = 1; i <= n; i++ )); do
    [[ ${ek[i]} == subtitle ]] || continue
    for (( j = 1; j <= n; j++ )); do
      [[ ${ek[j]} == video ]] || continue
      b2=${eg[j]}; base=${eg[i]}
      if [[ ${base,,} == "${b2,,}" || ${base,,} == "${b2,,}".* ]]; then ef[i]=$j; break; fi
    done
  done
  man="$wd/W6W.MANIFEST"
  {
    echo "W6W-MANIFEST 1"
    echo "app=VidCompress $VERSION"
    echo "created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "comment=$(w6w_enc "$W6W_COMMENT")"
    echo "count=$n"
    for (( i = 1; i <= n; i++ )); do
      printf 'E|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$i" "${ek[i]}" "${ee[i]}" "${es[i]}" "${ez[i]}" "${ed[i]}" "${ef[i]}" "${et[i]}" "${ep[i]}" "${en[i]}"
    done
  } > "$man"
  for (( i = 1; i <= n; i++ )); do fl+=("e$(printf '%03d' "$i")"); done
  info "Encrypting $n item(s) ..."
  local salt iv mac
  salt=$(w6w_hex_rand 8); iv=$(w6w_hex_rand 16)
  w6w_derive "$salt" || { err "Key derivation failed."; rm -rf -- "$wd"; return 1; }
  mkdir -p -- "$(dirname -- "$out")"
  {
    printf 'W6W1%s' "$mode"; printf '\0\0\0'
    w6w_hex2bin "$salt"; w6w_hex2bin "$iv"
  } > "$out.part"
  if ! ( cd "$wd" && tar -chf - W6W.MANIFEST "${fl[@]}" ) | openssl enc -aes-256-cbc -K "$W6W_KEY" -iv "$iv" >> "$out.part"; then
    err "Packing failed."; rm -rf -- "$wd" "$out.part"; return 1
  fi
  mac=$(openssl dgst -sha256 -mac HMAC -macopt "hexkey:$W6W_MK" -binary < "$out.part" | od -An -v -tx1 | tr -d ' \n')
  w6w_hex2bin "$mac" >> "$out.part"
  rm -rf -- "$wd"
  mv -f -- "$out.part" "$out"
  ok "Created: $(pretty "$out")  ($n items, $(human "$(fsize "$out")"), $( [[ $mode == D ]] && echo "locked to this phone's key [$(w6w_fp "$W6W_DEVKEY")]" || echo "password protected" ))"
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
  return 0
}

# ---------------------------------------------------------------- read the contents
w6w_load() {   # $1 file (already unlocked) -> W_* arrays
  local man line i F mode
  local -a P
  man=$(w6w_stream "$1" 2>/dev/null | tar -xOf - W6W.MANIFEST --occurrence=1 2>/dev/null)
  [[ $man == W6W-MANIFEST* ]] || { err "Cannot read the contents (wrong key, or damaged file)."; return 1; }
  W_KIND=(); W_EXT=(); W_STORED=(); W_SIZE=(); W_DUR=(); W_FOR=(); W_MT=(); W_DETAIL=(); W_NAME=(); W_N=0; W_CREATED=""; W_COMMENT_TXT=""
  while IFS= read -r line; do
    case $line in
      created=*) W_CREATED=${line#created=};;
      comment=*) W_COMMENT_TXT=$(w6w_dec "${line#comment=}");;
      E\|*)
        IFS='|' read -ra P <<<"$line"
        i=${P[1]}
        W_KIND[i]=${P[2]}; W_EXT[i]=${P[3]}; W_STORED[i]=${P[4]}; W_SIZE[i]=${P[5]}; W_DUR[i]=${P[6]}
        W_FOR[i]=${P[7]}; W_MT[i]=${P[8]}; W_DETAIL[i]=$(w6w_dec "${P[9]}"); W_NAME[i]=$(w6w_dec "${P[10]}")
        (( i > W_N )) && W_N=$i;;
    esac
  done <<<"$man"
  (( W_N > 0 ))
}
w6w_show() {   # $1 file (loaded)
  local i mode
  mode=$(head -c 5 -- "$1" | tail -c 1)
  printf '\n%s== %s ==%s\n' "$C_B" "$(basename -- "$1")" "$C_0"
  printf '  %s%d item(s) | created %s | %s%s\n' "$C_D" "$W_N" "${W_CREATED:-?}" "$( [[ $mode == D ]] && echo "device key" || echo "password")" "$C_0"
  [[ -n $W_COMMENT_TXT ]] && printf '  %s"%s"%s\n' "$C_D" "$W_COMMENT_TXT" "$C_0"
  echo
  for (( i = 1; i <= W_N; i++ )); do
    [[ -n ${W_KIND[i]-} ]] || continue
    printf ' %2d) %-8s %-5s %9s  %s\n' "$i" "$(w6w_label "${W_KIND[i]}")" "${W_EXT[i]}" "$(human "${W_SIZE[i]}")" "$(trunc "${W_NAME[i]}")"
    printf '      %s%s%s%s%s\n' "$C_D" "${W_DETAIL[i]}" "$( [[ ${W_DUR[i]} != 0 && -n ${W_DUR[i]} ]] && printf ' | %s' "$(fmt_time "${W_DUR[i]}")" )" "$( (( ${W_FOR[i]:-0} > 0 )) && printf ' | subtitle for #%s' "${W_FOR[i]}" )" "$C_0"
  done
}

# ---------------------------------------------------------------- extract / convert / play
w6w_take() {   # $1 file  $2 workdir  $3.. indexes (empty = all)  -> eNNN files in workdir
  local f=$1 wd=$2 i
  local -a m=()
  shift 2
  for i in "$@"; do m+=("e$(printf '%03d' "$i")"); done
  if (( ${#m[@]} )); then w6w_stream "$f" 2>/dev/null | tar -xf - -C "$wd" --occurrence=1 "${m[@]}" 2>/dev/null
  else w6w_stream "$f" 2>/dev/null | tar -xf - -C "$wd" 2>/dev/null; fi
  return 0
}
w6w_restore() {   # $1 workdir $2 index $3 destdir -> W_OUT (real file with its original name, decompressed)
  local wd=$1 i=$2 dest=$3 nm base ext tmp
  local e="$wd/e$(printf '%03d' "$i")"
  [[ -e $e ]] || return 1
  nm=${W_NAME[i]##*/}; [[ -n $nm ]] || nm="item$i.${W_EXT[i]}"
  base=${nm%.*}; ext=${nm##*.}; [[ $nm == *.* ]] || ext=""
  mkdir -p -- "$dest"
  W_OUT=$(unique_file "$dest" "$base" "${ext:-bin}")
  [[ -z $ext ]] && W_OUT=${W_OUT%.bin}
  if [[ ${W_STORED[i]} == xz ]]; then xz -dc -- "$e" > "$W_OUT"; else cp -f -- "$e" "$W_OUT"; fi
  rm -f -- "$e"
  [[ -s $W_OUT ]] || [[ ${W_SIZE[i]} == 0 ]] || return 1
  [[ ${W_MT[i]} =~ ^[0-9]+$ ]] && touch -d "@${W_MT[i]}" -- "$W_OUT" 2>/dev/null
  return 0
}
w6w_extract() {   # $1 file $2 destdir  [indexes...]
  local f=$1 dest=$2 wd i c=0
  local -a want=()
  shift 2
  want=("$@")
  wd=$(mktemp -d) || return 1
  w6w_take "$f" "$wd" "${want[@]}"
  if (( ${#want[@]} == 0 )); then for (( i = 1; i <= W_N; i++ )); do want+=("$i"); done; fi
  for i in "${want[@]}"; do
    if w6w_restore "$wd" "$i" "$dest"; then ok "$(printf '%-8s' "$(w6w_label "${W_KIND[i]}")") -> $(pretty "$W_OUT")"; c=$(( c + 1 ))
    else warn "Item $i could not be restored."; fi
  done
  rm -rf -- "$wd"
  info "$c item(s) extracted to $(pretty "$dest")"
  return 0
}
w6w_convert_one() {   # $1 file path  $2 kind  $3 target ext ("" = keep)  $4 destdir  $5 subtitle path ("" none) -> W_OUT
  local f=$1 kind=$2 to=${3,,} dest=$4 sub=${5:-} base out dur sc
  local -a a=() ar=()
  base=${f##*/}; base=${base%.*}
  case $kind in
    video)
      case $to in mp4|mkv|webm|mov|avi|ts) ;; "") to=mkv;; *) return 1;; esac
      out=$(unique_file "$dest" "$base" "$to")
      ar=(-i "$f"); [[ -n $sub ]] && ar+=(-i "$sub")
      probe "$f" >/dev/null 2>&1; dur=$DUR
      a=(-map 0:v:0 -map '0:a?')
      [[ -n $sub ]] && a+=(-map 1:0)
      case $to in
        mkv) a+=(-c copy); [[ -n $sub ]] && { case ${sub##*.} in ass|ssa) sc=ass;; *) sc=srt;; esac; a+=(-c:s "$sc"); };;
        mp4|mov)
          case $SRC_VCODEC in h264|hevc|av1) a+=(-c:v copy);; *) a+=(-c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p);; esac
          case $SRC_ACODEC in aac|mp3|ac3|eac3|"") a+=(-c:a copy);; *) a+=(-c:a aac -b:a 160k);; esac
          [[ -n $sub ]] && a+=(-c:s mov_text); [[ $to == mp4 ]] && a+=(-movflags +faststart);;
        webm)
          case $SRC_VCODEC in vp8|vp9|av1) a+=(-c:v copy);; *) a+=(-c:v libvpx-vp9 -b:v 0 -crf 33 -row-mt 1 -deadline good -cpu-used 4);; esac
          case $SRC_ACODEC in opus|vorbis|"") a+=(-c:a copy);; *) a+=(-c:a libopus -b:a 96k);; esac
          [[ -n $sub ]] && a+=(-c:s webvtt);;
        avi|ts)
          a+=(-c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -c:a "$(have_enc libmp3lame && echo libmp3lame || echo aac)" -b:a 160k -sn);;
      esac
      EDUR=$dur
      run_ffmpeg "convert" 1 1 "${ar[@]}" "${a[@]}" -max_muxing_queue_size 4096 "$out" || { rm -f -- "$out"; return 1; }
      W_OUT=$out;;
    image)
      case $to in jpg|jpeg|png|webp) ;; "") w6w_copy_to "$f" "$dest"; return 0;; *) return 1;; esac
      out=$(unique_file "$dest" "$base" "$to")
      ffmpeg -nostdin -v error -y -i "$f" -frames:v 1 -update 1 "$out" 2>>"$LOG" && [[ -s $out ]] || { rm -f -- "$out"; return 1; }
      W_OUT=$out;;
    audio)
      case $to in mp3|m4a|opus|wav|flac) ;; "") w6w_copy_to "$f" "$dest"; return 0;; *) return 1;; esac
      out=$(unique_file "$dest" "$base" "$to")
      case $to in
        mp3) ar=(-c:a libmp3lame -b:a 192k);; m4a) ar=(-c:a aac -b:a 160k);; opus) ar=(-c:a libopus -b:a 96k);; wav) ar=(-c:a pcm_s16le);; flac) ar=(-c:a flac);;
      esac
      ffmpeg -nostdin -v error -y -i "$f" -vn "${ar[@]}" "$out" 2>>"$LOG" && [[ -s $out ]] || { rm -f -- "$out"; return 1; }
      W_OUT=$out;;
    subtitle)
      case $to in srt|vtt|ass) ;; "") w6w_copy_to "$f" "$dest"; return 0;; *) return 1;; esac
      out=$(unique_file "$dest" "$base" "$to")
      ffmpeg -nostdin -v error -y -i "$f" "$out" 2>>"$LOG" && [[ -s $out ]] || { rm -f -- "$out"; return 1; }
      W_OUT=$out;;
    *) w6w_copy_to "$f" "$dest";;      # text, scripts, documents, archives, other files: restored as they are
  esac
  return 0
}
w6w_copy_to() {   # $1 file  $2 destdir -> W_OUT (same name, never overwrites)
  local n=${1##*/} base ext
  base=${n%.*}; ext=${n##*.}; [[ $n == *.* ]] || ext=""
  W_OUT=$(unique_file "$2" "$base" "${ext:-bin}")
  [[ -z $ext ]] && W_OUT=${W_OUT%.bin}
  cp -f -- "$1" "$W_OUT"
}
w6w_convert() {   # $1 file $2 destdir $3 target ("" = natural defaults) [indexes...]
  local f=$1 dest=$2 to=$3 wd i k c=0 skipped=0 tmpd sub s
  local -a want=()
  shift 3
  want=("$@")
  wd=$(mktemp -d) || return 1; tmpd=$(mktemp -d) || return 1
  w6w_take "$f" "$wd" "${want[@]}"
  if (( ${#want[@]} == 0 )); then for (( i = 1; i <= W_N; i++ )); do want+=("$i"); done; fi
  mkdir -p -- "$dest"
  # linked subtitles are restored first, then muxed into their video
  for i in "${want[@]}"; do
    if w6w_restore "$wd" "$i" "$tmpd"; then W_RES[i]=$W_OUT; fi
  done
  for i in "${want[@]}"; do
    [[ -n ${W_RES[i]-} ]] || continue
    k=${W_KIND[i]}
    if [[ $k == subtitle ]] && (( ${W_FOR[i]:-0} > 0 )) && [[ -n ${W_RES[${W_FOR[i]}]-} ]] && [[ -z $to || $to == mp4 || $to == mkv || $to == webm || $to == mov ]]; then
      continue    # goes inside its video below
    fi
    sub=""
    if [[ $k == video ]]; then
      for (( s = 1; s <= W_N; s++ )); do
        [[ ${W_KIND[s]-} == subtitle && ${W_FOR[s]:-0} == "$i" && -n ${W_RES[s]-} ]] && { sub=${W_RES[s]}; break; }
      done
    fi
    if w6w_convert_one "${W_RES[i]}" "$k" "$to" "$dest" "$sub"; then
      ok "$(printf '%-8s' "$(w6w_label "$k")") -> $(pretty "$W_OUT")${sub:+  (+ subtitle inside)}"; c=$(( c + 1 ))
    else
      # this target does not fit this kind: keep the original format
      if w6w_convert_one "${W_RES[i]}" "$k" "" "$dest" "$sub"; then ok "$(printf '%-8s' "$(w6w_label "$k")") -> $(pretty "$W_OUT")  (kept as is)"; c=$(( c + 1 ))
      else warn "Item $i ($k) could not be converted."; skipped=$(( skipped + 1 )); fi
    fi
  done
  rm -rf -- "$wd" "$tmpd"; W_RES=()
  info "$c item(s) written to $(pretty "$dest")"
  return 0
}
declare -a W_RES=()
w6w_play() {   # $1 file (loaded) $2 index -> view / play one item without leaving a decrypted copy behind
  local f=$1 i=$2 wd pd rest s sub="" out
  [[ -n ${W_KIND[i]-} ]] || { err "No item $i."; return 1; }
  wd=$(mktemp -d) || return 1
  w6w_take "$f" "$wd" "$i"
  case ${W_KIND[i]} in
    text|script|subtitle)
      if w6w_restore "$wd" "$i" "$wd/out"; then
        printf '\n%s--- %s ---%s\n' "$C_B" "${W_NAME[i]}" "$C_0"
        if [[ -t 1 ]] && command -v less >/dev/null 2>&1 && (( $(wc -l < "$W_OUT") > 40 )); then less -- "$W_OUT"; else head -n 200 -- "$W_OUT"; fi
      fi;;
    video|image|audio)
      if [[ -d $HOME/storage/shared ]]; then pd="$HOME/storage/shared/.w6w_play"; else pd=${TMPDIR:-/tmp}/.w6w_play; fi
      mkdir -p -- "$pd"; : > "$pd/.nomedia"
      if w6w_restore "$wd" "$i" "$pd"; then
        out=$W_OUT
        if [[ ${W_KIND[i]} == video ]]; then
          for (( s = 1; s <= W_N; s++ )); do
            if [[ ${W_KIND[s]-} == subtitle && ${W_FOR[s]:-0} == "$i" ]]; then
              w6w_take "$f" "$wd" "$s"; w6w_restore "$wd" "$s" "$wd/sub" && sub=$W_OUT; break
            fi
          done
          if [[ -n $sub ]]; then
            local mux="$pd/play_$$.mkv" sc=srt; [[ ${sub##*.} == ass || ${sub##*.} == ssa ]] && sc=ass
            if ffmpeg -nostdin -v error -y -i "$out" -i "$sub" -map 0 -map 1:0 -c copy -c:s "$sc" "$mux" 2>>"$LOG" && [[ -s $mux ]]; then rm -f -- "$out"; out=$mux; fi
          fi
        fi
        if command -v termux-open >/dev/null 2>&1; then
          termux-open "$out" || warn "Could not open it with an app."
          info "Opened. The temporary decrypted copy is deleted when you press Enter."
          read -r -p "Press Enter when you are done ... " rest || true
        else
          warn "termux-open is missing (pkg install termux-tools). Decrypted copy: $out"
          read -r -p "Press Enter to delete it ... " rest || true
        fi
        rm -f -- "$out" "$pd"/play_$$.mkv
      fi;;
    *) warn "A ${W_KIND[i]} item cannot be played - use extract.";;
  esac
  rm -rf -- "$wd"
  return 0
}

# ---------------------------------------------------------------- key management
w6w_key_cmd() {   # show | export | import HEX | new
  w6w_have_tools || return 1
  case ${1:-show} in
    show)   w6w_device_key
            printf 'Device key fingerprint: %s  (the key stays on this phone: %s)\n' "$(w6w_fp "$W6W_DEVKEY")" "$(pretty "$CONF_DIR/w6w.key")"
            printf 'Files packed in device mode open ONLY with this key. Back it up: vc --w6w key export\n';;
    export) w6w_device_key
            warn "Anyone with this text can open your device-mode .w6w files. Keep it secret."
            printf '%s\n' "$W6W_DEVKEY";;
    import) [[ ${2:-} =~ ^[0-9a-fA-F]{64}$ ]] || { err "Give the 64-character hex key."; return 1; }
            mkdir -p "$CONF_DIR"
            local had=0; [[ -s $CONF_DIR/w6w.key ]] && { had=1; cp -f -- "$CONF_DIR/w6w.key" "$CONF_DIR/w6w.key.bak"; }
            ( umask 077; printf '%s' "${2,,}" > "$CONF_DIR/w6w.key" ); ok "Key imported.$( (( had )) && echo ' (the old one is kept as w6w.key.bak)')";;
    new)    warn "A NEW key makes every device-mode .w6w made so far unreadable (unless you keep a backup)."
            if [[ -t 0 ]] && ! yesno "Create a new key?" n; then return 1; fi
            [[ -s $CONF_DIR/w6w.key ]] && cp -f -- "$CONF_DIR/w6w.key" "$CONF_DIR/w6w.key.bak"
            ( umask 077; w6w_hex_rand 32 > "$CONF_DIR/w6w.key" ); ok "New key created (old one kept as w6w.key.bak).";;
    *) err "Use: key show | export | import HEX | new"; return 1;;
  esac
}

# ---------------------------------------------------------------- menus & CLI
w6w_find_files() {   # newest .w6w files on the phone -> W_FOUND
  local root line
  W_FOUND=()
  fv_root; root=$FV_ROOT
  while IFS= read -r line; do [[ -n $line ]] && W_FOUND+=("${line#*$'\t'}"); done < <(find -H "$root" -maxdepth 9 \( -name '.*' -o -iname cache -o -path '*/Android/data' \) -prune -o -type f -iname '*.w6w' -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -n 30)
}
w6w_pick_file() {   # -> PICK_RESULT
  local i ans
  PICK_RESULT=""
  w6w_find_files
  if (( ${#W_FOUND[@]} )); then
    echo " .w6w files found on your phone:"
    for i in "${!W_FOUND[@]}"; do printf ' %2d) %8s  %s\n' $(( i + 1 )) "$(human "$(fsize "${W_FOUND[i]}")")" "$(trunc "$(pretty "${W_FOUND[i]}")")"; done
  else echo " (no .w6w file found - type a path)"; fi
  ans=$(ask "Number or path" "")
  [[ -n $ans ]] || return 1
  if [[ $ans =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= ${#W_FOUND[@]} )); then PICK_RESULT=${W_FOUND[ans-1]}
  else ans=${ans/#\~/$HOME}; [[ -f $ans ]] && PICK_RESULT=$(readlink -f -- "$ans"); fi
  [[ -n $PICK_RESULT ]] || { warn "Not found."; return 1; }
}
w6w_open_flow() {   # $1 file: look inside, then play / extract / convert
  local f=$1 c a dest
  w6w_unlock "$f" || return 1
  w6w_load "$f" || return 1
  while true; do
    w6w_show "$f"
    echo
    echo " number = play / view that item     x = extract all"
    echo " c = convert all (video->mp4 ...)   e N = extract item N     b = back"
    read -r -p "> " c || return 0
    case ${c,,} in
      b|"") return 0;;
      x) dest=$(ask "Extract into folder" "$(dirname -- "$f")/$(basename -- "${f%.*}")_extracted"); dest=${dest/#\~/$HOME}; w6w_extract "$f" "$dest"; pause;;
      c) a=$(ask "Convert to (mp4 / mkv / webm, jpg / png / webp, mp3 / m4a / opus, srt / vtt - blank = natural)" "")
         dest=$(ask "Write into folder" "$(dirname -- "$f")/$(basename -- "${f%.*}")_converted"); dest=${dest/#\~/$HOME}
         w6w_convert "$f" "$dest" "$a"; pause;;
      e\ *) a=${c#e }; if [[ $a =~ ^[0-9]+$ ]]; then dest=$(dirname -- "$f")/$(basename -- "${f%.*}")_extracted; w6w_extract "$f" "$dest" "$a"; fi; pause;;
      *) if [[ $c =~ ^[0-9]+$ ]]; then w6w_play "$f" "$c"; fi;;
    esac
  done
}
w6w_pack_flow() {   # interactive: pick files, options, create
  local out p ans first
  local -a extra=()
  w6w_have_tools || { pause; return 1; }
  printf '\n%s== Pack into .w6w ==%s\n' "$C_B" "$C_0"
  info "Pick videos below (a = all). Then you can add ANY other file or folder: pictures, text, scripts, subtitles ..."
  find_videos multi
  while true; do
    p=$(ask "Add a file or folder (blank = done)" "")
    [[ -n $p ]] || break
    p=${p/#\~/$HOME}
    if [[ -e $p ]]; then extra+=("$p"); ok "Added: $p"; else warn "Not found: $p"; fi
  done
  if (( ${#SELECTED[@]} + ${#extra[@]} == 0 )); then warn "Nothing chosen."; pause; return 1; fi
  first=${SELECTED[0]:-${extra[0]}}
  out=$(ask "Name of the .w6w file" "$(dirname -- "$first")/$(basename -- "${first%.*}").w6w")
  out=${out/#\~/$HOME}
  if yesno "Squeeze first (shrinks videos with your current preset, pictures to WebP, audio to Opus)?" n; then W6W_SQUEEZE=1; else W6W_SQUEEZE=0; fi
  echo " 1) lock to THIS phone (device key - nothing else can open it)"
  echo " 2) password (can be opened on another phone that has vc)"
  ans=$(ask "Choose" "1")
  [[ $ans == 2 ]] && W6W_PWMODE=1 || W6W_PWMODE=0
  W6W_COMMENT=$(ask "Note inside the file (optional)" "")
  w6w_pack "$out" "${SELECTED[@]}" "${extra[@]}"
  pause
}
w6w_menu() {
  local c f
  while true; do
    clear_screen
    printf '%s== W6W vault ==%s\n' "$C_B" "$C_0"
    printf '  %sOne encrypted file for videos, pictures, audio, text, scripts, subtitles...%s\n\n' "$C_D" "$C_0"
    echo " 1) Pack files into a .w6w"
    echo " 2) Open a .w6w (look inside, play, extract, convert)"
    echo " 3) Key & security"
    echo " b) Back"
    read -r -p "> " c || return
    case $c in
      1) w6w_pack_flow;;
      2) if w6w_pick_file; then w6w_open_flow "$PICK_RESULT"; fi;;
      3) clear_screen; w6w_key_cmd show; echo
         echo " e) export the key (backup)   n) create a NEW key   b) back"
         read -r -p "> " c || return
         case $c in e|E) w6w_key_cmd export;; n|N) w6w_key_cmd new;; esac
         pause;;
      b|B|"") return;;
    esac
  done
}
w6w_cli() {   # vc --w6w  pack|info|extract|convert|play|key|list ...
  local cmd=${1:-} f dest idx
  shift || true
  dest=${OUTDIR:-}
  case $cmd in
    pack)    (( $# >= 2 )) || { err "Usage: vc --w6w pack OUT.w6w FILE|FOLDER ... [--squeeze] [--password] [--comment TEXT]"; return 1; }
             w6w_pack "$@";;
    info|ls) f=${1:-}; [[ -f $f ]] || { err "Usage: vc --w6w info FILE.w6w"; return 1; }
             w6w_unlock "$f" noverify || return 1; w6w_load "$f" || return 1; w6w_show "$f";;
    verify)  f=${1:-}; [[ -f $f ]] || { err "Usage: vc --w6w verify FILE.w6w"; return 1; }
             w6w_unlock "$f" && ok "Integrity OK - key accepted, nothing was changed.";;
    extract) f=${1:-}; [[ -f $f ]] || { err "Usage: vc --w6w extract FILE.w6w [-o DIR] [N ...]"; return 1; }
             shift; w6w_unlock "$f" || return 1; w6w_load "$f" || return 1
             [[ -n $dest ]] || dest=$(dirname -- "$f")/$(basename -- "${f%.*}")_extracted
             w6w_extract "$f" "$dest" "$@";;
    convert) f=${1:-}; [[ -f $f ]] || { err "Usage: vc --w6w convert FILE.w6w [--to FMT] [-o DIR] [N ...]"; return 1; }
             shift; w6w_unlock "$f" || return 1; w6w_load "$f" || return 1
             [[ -n $dest ]] || dest=$(dirname -- "$f")/$(basename -- "${f%.*}")_converted
             w6w_convert "$f" "$dest" "$W6W_TO" "$@";;
    play)    f=${1:-}; idx=${2:-1}; [[ -f $f ]] || { err "Usage: vc --w6w play FILE.w6w [N]"; return 1; }
             w6w_unlock "$f" || return 1; w6w_load "$f" || return 1; w6w_play "$f" "$idx";;
    key)     w6w_key_cmd "$@";;
    list|find) w6w_find_files; printf '%s\n' "${W_FOUND[@]}";;
    *)       err "Usage: vc --w6w pack | info | verify | extract | convert | play | key | list"; return 1;;
  esac
}

main() {
  local STUDIO=0 FRAMES_MODE=0 RACE_MODE="" W6W_MODE=0
  refresh_cols; trap refresh_cols WINCH
  case ${1:-} in
    --setup)   do_setup; exit;;
    --install) do_install; exit;;
    --version) echo "VidCompress $VERSION  by $CREATOR  ($WEBSITE)"; exit;;
    --help|-h) usage; exit;;
    --sub)     STUDIO=1; shift;;
  esac

  mkdir -p "$CONF_DIR" "$PROF_DIR"
  set_defaults
  load_conf "$CONF"
  # sanitize values loaded from an older config
  case $SUB_MODE in off|soft|burn) ;; *) SUB_MODE=soft;; esac
  case $FINISH_ACTION in summary|open) ;; *) FINISH_ACTION=menu;; esac
  case $OUT_EXT in mp4|mkv|webm|mov|avi|ts) ;; *) OUT_EXT=mp4;; esac
  [[ $DEINT =~ ^[01]$ ]] || DEINT=1
  [[ $AUTOCROP =~ ^[01]$ ]] || AUTOCROP=0
  [[ $KEEP_SUBS =~ ^[01]$ ]] || KEEP_SUBS=1
  [[ $PARALLEL_JOBS =~ ^[1-8]$ ]] || PARALLEL_JOBS=1
  [[ $SUB_SIZE =~ ^[0-9]+$ ]] || SUB_SIZE=24
  [[ -n $SUB_LANG ]] || SUB_LANG=fa
  [[ $SKIP_DONE =~ ^[01]$ ]] || SKIP_DONE=0
  case $FRAME_FMT in jpg|png|bmp|webp) ;; *) FRAME_FMT=jpg;; esac
  [[ $FRAME_Q =~ ^[0-9]+$ ]] && (( FRAME_Q >= 1 && FRAME_Q <= 31 )) || FRAME_Q=2
  [[ $FRAME_STEP =~ ^[0-9]+$ ]] || FRAME_STEP=1
  [[ $FRAME_H =~ ^[0-9]+$ ]] || FRAME_H=0
  [[ $SCALER == lanczos ]] || SCALER=bicubic
  [[ $CORES == auto || $CORES == all || $CORES =~ ^[0-9]+([-,][0-9]+)*$ ]] || CORES=auto
  [[ $THREADS =~ ^[0-9]+$ ]] && (( THREADS <= 128 )) || THREADS=0

  # --- long options (override config)
  local newargs=() a
  while (( $# )); do
    case $1 in
      --srt|--srt-burn)
        [[ $1 == --srt-burn ]] && SUB_MODE=burn || SUB_MODE=soft
        if (( $# >= 2 )); then SUB_FILE=$2; shift 2; else shift; fi;;
      --nosrt)    SUB_MODE=off; shift;;
      --keepsubs) KEEP_SUBS=1; shift;;
      --nosubs)   KEEP_SUBS=0; shift;;
      --mkv)      OUT_EXT=mkv; shift;;
      --format)   if (( $# >= 2 )); then OUT_EXT=${2,,}; shift 2; else err "--format needs mp4 | mkv | webm | mov | avi | ts"; exit 1; fi;;
      --no-deint) DEINT=0; shift;;
      --autocrop) AUTOCROP=1; shift;;
      --repair)   REPAIR_ACTION=repair; shift;;
      --diagnose) REPAIR_ACTION=diagnose; shift;;
      --quickfix) REPAIR_ACTION=quickfix; shift;;
      --sync-shift)
        if [[ $2 =~ ^-?[0-9]+$ ]]; then REPAIR_SHIFT_MS=$2; REPAIR_ACTION=shift; shift 2
        else err "--sync-shift needs a number of milliseconds (e.g. --sync-shift 250)"; exit 1; fi;;
      --fps)        if (( $# >= 2 )); then REPAIR_FPS=$2; shift 2; else err "--fps needs a value"; exit 1; fi;;
      --repair-crf) if [[ $2 =~ ^[0-9]+$ ]]; then REPAIR_CRF=$2; shift 2; else err "--repair-crf needs a number"; exit 1; fi;;
      --repair-preset)
        if (( $# >= 2 )); then REPAIR_PRESET=$2; shift 2; else err "--repair-preset needs a value"; exit 1; fi;;
      --oldtv)    REPAIR_OLDTV=1; shift;;
      --stereo)   REPAIR_STEREO=1; shift;;
      --frames)   FRAMES_MODE=1; shift;;
      --race)        RACE_MODE=presets; shift;;
      --race-cores)  RACE_MODE=cores; shift;;
      --stamina|--heat) RACE_MODE=stamina; shift;;
      --race-all)    RACE_MODE=all; shift;;
      --no-quality)  NOQUALITY=1; shift;;
      --cpu)         CPU_MODE=1; shift;;
      --w6w)         W6W_MODE=1; shift;;
      --squeeze)     W6W_SQUEEZE=1; shift;;
      --password)    W6W_PWMODE=1; shift;;
      --to)          if (( $# >= 2 )); then W6W_TO=${2,,}; shift 2; else err "--to needs a format (mp4, png, mp3 ...)"; exit 1; fi;;
      --comment)     if (( $# >= 2 )); then W6W_COMMENT=$2; shift 2; else err "--comment needs a text"; exit 1; fi;;
      --tune)        TUNE_MODE=1; shift;;
      --goal)        if (( $# >= 2 )); then TUNE_GOAL=${2,,}; shift 2; else err "--goal needs speed | balanced | size | quality"; exit 1; fi;;
      --cores)    if (( $# >= 2 )); then CORES=${2,,}; shift 2; else err "--cores needs auto | all | a list like 4-7"; exit 1; fi;;
      --threads)  if (( $# >= 2 )); then THREADS=$2; shift 2; else err "--threads needs a number (0 = auto)"; exit 1; fi;;
      --resume)   SKIP_DONE=1; shift;;
      --lanczos)  SCALER=lanczos; shift;;
      --bicubic)  SCALER=bicubic; shift;;
      --frame-format)  if (( $# >= 2 )); then FRAME_FMT=${2,,}; shift 2; else err "--frame-format needs jpg|png|bmp|webp"; exit 1; fi;;
      --frame-quality) if (( $# >= 2 )); then FRAME_Q=$2; shift 2; else err "--frame-quality needs 1-31"; exit 1; fi;;
      --frame-height)  if (( $# >= 2 )); then FRAME_H=$2; shift 2; else err "--frame-height needs a number"; exit 1; fi;;
      --frame-step)    if (( $# >= 2 )); then
                         case ${2,,} in key|keys|keyframes|i) FRAME_STEP=0;; *) FRAME_STEP=$2;; esac
                         shift 2
                       else err "--frame-step needs N or 'key'"; exit 1; fi;;
      *) newargs+=("$1"); shift;;
    esac
  done
  set -- "${newargs[@]}"
  if [[ -n $REPAIR_FPS ]] && ! awk -v x="$(frac2dec "$REPAIR_FPS")" 'BEGIN{ exit !(x + 0 > 0) }'; then
    err "Bad --fps value: $REPAIR_FPS"; exit 1
  fi
  if [[ ! $REPAIR_CRF =~ ^[0-9]+$ ]] || (( REPAIR_CRF < 0 || REPAIR_CRF > 51 )); then
    err "Bad --repair-crf value (0-51)."; exit 1
  fi
  case $REPAIR_PRESET in
    ultrafast|superfast|veryfast|faster|fast|medium|slow|slower|veryslow) ;;
    *) err "Bad --repair-preset value."; exit 1;;
  esac
  case $OUT_EXT in mp4|mkv|webm|mov|avi|ts) ;; *) err "--format must be mp4, mkv, webm, mov, avi or ts."; exit 1;; esac
  case $TUNE_GOAL in ""|speed|balanced|size|quality) ;; *) err "--goal must be speed, balanced, size or quality."; exit 1;; esac
  [[ $CORES == auto || $CORES == all || $CORES =~ ^[0-9]+([-,][0-9]+)*$ ]] || { err "--cores must be auto, all or a list like 4-7."; exit 1; }
  [[ $THREADS =~ ^[0-9]+$ ]] && (( THREADS <= 128 )) || { err "--threads must be 0-128."; exit 1; }
  case $FRAME_FMT in jpg|jpeg|png|bmp|webp) [[ $FRAME_FMT == jpeg ]] && FRAME_FMT=jpg;; *) err "Bad --frame-format (jpg | png | bmp | webp)."; exit 1;; esac
  [[ $FRAME_Q =~ ^[0-9]+$ ]] && (( FRAME_Q >= 1 && FRAME_Q <= 31 )) || { err "--frame-quality must be 1-31."; exit 1; }
  [[ $FRAME_STEP =~ ^[0-9]+$ ]] || { err "--frame-step must be a number or 'key'."; exit 1; }
  [[ $FRAME_H =~ ^[0-9]+$ ]] || { err "--frame-height must be a number."; exit 1; }

  local OPT PRESET_ARG="" OV_T="" OV_C="" OV_R="" OV_F="" OV_S="" OV_K="" OV_A="" OV_O="" OV_J="" OV_TS="" OV_TE="" OV_D=0 AUTO=0
  # short options may come before OR after the files:  vc movie.mp4 -p turbo -y
  local rest=() ch ov i
  while (( $# )); do
    a=$1; shift
    case $a in
      --) rest+=("$@"); break;;
      -[!-]*)
        i=1
        while (( i < ${#a} )); do
          ch=${a:i:1}
          case $ch in
            p|t|c|r|f|s|k|a|S|E|o|j)
              if (( i + 1 < ${#a} )); then ov=${a:i+1}
              elif (( $# )); then ov=$1; shift
              else err "Option -$ch needs a value."; exit 1; fi
              case $ch in
                p) PRESET_ARG=$ov;; t) OV_T=$ov;; c) OV_C=$ov;; r) OV_R=$ov;;
                f) OV_F=$ov;; s) OV_S=$ov;; k) OV_K=$ov;; a) OV_A=$ov;;
                S) OV_TS=$ov;; E) OV_TE=$ov;; o) OV_O=$ov;; j) OV_J=$ov;;
              esac
              break;;
            d) OV_D=1;;
            y) AUTO=1;;
            h) usage; exit 0;;
            *) err "Unknown option: -$ch"; usage; exit 1;;
          esac
          i=$(( i + 1 ))
        done;;
      *) rest+=("$a");;
    esac
  done
  set -- "${rest[@]}"

  if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    err "ffmpeg/ffprobe not found."
    if [[ -t 0 ]] && yesno "Install now?" y; then do_setup; else echo "Run: vc --setup   (or: pkg install ffmpeg)"; exit 1; fi
    command -v ffmpeg >/dev/null 2>&1 || exit 1
  fi

  detect_ff_caps
  NCPU=$(nproc --all 2>/dev/null || nproc 2>/dev/null || echo 4)
  apply_cores; calc_threads 1
  if (( CPU_MODE )); then device_report; exit 0; fi
  if [[ -n $PRESET_ARG ]]; then apply_preset "$PRESET_ARG" || { err "Unknown preset: $PRESET_ARG"; exit 1; }; fi
  [[ -n $OV_K ]] && { case $OV_K in x265|x264|av1|hw265|hw264) CODEC=$OV_K;; *) err "Unknown codec: $OV_K"; exit 1;; esac; PRESET_NAME=custom; }
  [[ -n $OV_C ]] && { CRF=$OV_C; TARGET_MB=0; PRESET_NAME=custom; }
  [[ -n $OV_T ]] && { TARGET_MB=$OV_T; PRESET_NAME=custom; }
  [[ -n $OV_R ]] && { HEIGHT=$OV_R; PRESET_NAME=custom; }
  [[ -n $OV_F ]] && { FPS=$OV_F; PRESET_NAME=custom; }
  [[ -n $OV_S ]] && { SPEED=$OV_S; PRESET_NAME=custom; }
  [[ -n $OV_J ]] && { PARALLEL_JOBS=$OV_J; }
  if [[ -n $OV_A ]]; then
    case $OV_A in copy|none) AUDIO=$OV_A;; *[!0-9]*) err "Bad -a value"; exit 1;; *) AUDIO=aac; ABR=$OV_A;; esac
    PRESET_NAME=custom
  fi
  [[ -n $OV_O ]] && OUTDIR=${OV_O/#\~/$HOME}
  if (( W6W_MODE )); then w6w_cli "$@"; exit $?; fi
  if [[ -n $OV_TS ]]; then TRIM_START=$(to_sec "$OV_TS") || { err "Bad -S time"; exit 1; }; fi
  if [[ -n $OV_TE ]]; then
    if [[ $OV_TE == +* ]]; then      # +N = N seconds after the start
      ov=$(to_sec "${OV_TE#+}") || { err "Bad -E time"; exit 1; }
      TRIM_END=$(awk -v a="${TRIM_START:-0}" -v b="$ov" 'BEGIN{ printf "%.3f", a + b }')
    else TRIM_END=$(to_sec "$OV_TE") || { err "Bad -E time"; exit 1; }; fi
  fi
  (( OV_D )) && DELETE_ORIG=1
  for OPT in CRF TARGET_MB HEIGHT FPS ABR PARALLEL_JOBS; do
    [[ ${!OPT} =~ ^[0-9]+$ ]] || { err "Invalid numeric value for $OPT: ${!OPT}"; exit 1; }
  done
  (( PARALLEL_JOBS >= 1 && PARALLEL_JOBS <= 8 )) || { err "-j must be 1-8"; exit 1; }

  local f skipped_out=0
  for a in "$@"; do
    if [[ -d $a ]]; then
      while IFS= read -r f; do
        if (( FRAMES_MODE )) || [[ -n $RACE_MODE ]] || ! is_vc_output "$f"; then add_sel "$f"; else skipped_out=$(( skipped_out + 1 )); fi
      done < <(list_videos "$a")
    elif [[ -f $a ]]; then add_sel "$a"
    else err "Not found: $a"; fi
  done
  (( skipped_out )) && info "Skipped $skipped_out file(s) that look like earlier vc outputs (add them by name to include them)."

  trap on_int INT TERM
  trap cleanup EXIT

  if (( TUNE_MODE )); then
    if (( ${#SELECTED[@]} )); then auto_tune "${SELECTED[0]}"; exit $?
    elif [[ -t 0 ]]; then auto_tune ""; exit $?
    else err "Usage: vc --tune FILE [--goal speed|balanced|size|quality]"; exit 1; fi
  fi
  if [[ -n $RACE_MODE ]]; then
    local race_f=""
    if (( ${#SELECTED[@]} )); then race_f=${SELECTED[0]}
    elif [[ ! -t 0 ]]; then err "Usage: vc --race | --race-cores | --stamina | --race-all FILE"; exit 1; fi
    case $RACE_MODE in
      presets) preset_race "$race_f";;
      cores)   cores_race "$race_f";;
      stamina) stamina_test "$race_f";;
      all)     race_all "$race_f";;
    esac
    exit $?
  fi
  if (( FRAMES_MODE )); then
    if (( ${#SELECTED[@]} == 0 )); then
      [[ -t 0 ]] || { err "Usage: vc --frames FILE -S START -E END"; exit 1; }
      frames_flow; exit $?
    fi
    (( ${#SELECTED[@]} == 1 )) || { err "--frames works on exactly one video."; exit 1; }
    if [[ -z $TRIM_START && -z $TRIM_END ]] && [[ -t 0 ]]; then frames_flow "${SELECTED[0]}"; exit $?; fi
    NONINTERACTIVE=1
    extract_frames "${SELECTED[0]}" "$TRIM_START" "$TRIM_END" 0 "$OUTDIR"
    exit $?
  fi
  if [[ -n $REPAIR_ACTION ]]; then
    local rf
    case $REPAIR_ACTION in
      diagnose)
        (( ${#SELECTED[@]} )) || { err "Usage: vc --diagnose FILE"; exit 1; }
        diag_queue
        exit 0;;
      quickfix)
        (( ${#SELECTED[@]} )) || { err "Usage: vc --quickfix FILE"; exit 1; }
        REPAIR_AUTO=1
        queue_run "Quick fix" quickfix_file
        exit $?;;
      shift)
        (( ${#SELECTED[@]} )) || { err "Usage: vc --sync-shift MS FILE [FILE ...]"; exit 1; }
        REPAIR_AUTO=1
        if (( ${#SELECTED[@]} == 1 )); then sync_shift_file "${SELECTED[0]}" "$REPAIR_SHIFT_MS"; exit $?; fi
        QUEUE_MS=$REPAIR_SHIFT_MS
        queue_run "Audio shift" q_shift
        exit $?;;
      repair)
        if (( ${#SELECTED[@]} )); then
          repair_batch
          exit $?
        elif [[ -t 0 ]]; then
          repair_menu
          exit 0
        else
          err "Usage: vc --repair FILE ...  (no files given and no terminal for the menu)"
          exit 1
        fi;;
    esac
  fi

  if (( STUDIO )); then
    [[ -t 0 ]] || { err "--sub needs an interactive terminal."; exit 1; }
    sub_studio
    exit 0
  fi

  if (( AUTO )); then
    NONINTERACTIVE=1
    (( ${#SELECTED[@]} )) || { err "No input files given."; exit 1; }
    print_plan
    run_batch
    local rc=$?
    finish_flow
    exit $rc
  fi
  first_run_offer
  main_menu
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
