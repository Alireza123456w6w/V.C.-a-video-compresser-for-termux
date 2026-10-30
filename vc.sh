#!/usr/bin/env bash
# =============================================================================
#  VidCompress (vc) v2.2 - ffmpeg video compression toolkit for Termux
#  Creator : W6W
#  Website : offers-pishnahadat.vercel.app
#
#  Quick start (in Termux):
#     bash vc.sh --setup      # install ffmpeg + storage access
#     bash vc.sh --install    # install the "vc" command
#     vc                      # interactive menu
#     vc --sub                # subtitle studio (SRT add/extract/remove)
#     vc --repair movie.mp4   # fix A/V sync drift (TV & USB player ready)
#     vc -y -p target -t 95 video.mp4     # CLI: compress to ~95 MB
#     vc -h                   # all options
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

VERSION="2.2"
CREATOR="W6W"
WEBSITE="offers-pishnahadat.vercel.app"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vidcompress"
CONF="$CONF_DIR/settings.conf"
PROF_DIR="$CONF_DIR/profiles"
LOG="$CONF_DIR/last_run.log"
VIDEO_EXT='mp4|mkv|mov|avi|webm|3gp|m4v|flv|ts|mpg|mpeg|wmv|mts|m2ts'
SETTING_VARS="CODEC CRF VBR SPEED HEIGHT FPS ABR AUDIO TARGET_MB DENOISE STRIP_META OUTDIR SUFFIX PRESET_NAME PARALLEL_JOBS KEEP_SUBS SUB_MODE SUB_FILE SUB_LANG SUB_SIZE SUB_COLOR OUT_EXT FINISH_ACTION"
PRESET_LIST="balanced quality small tiny social compat fast turbo target hardware av1"

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

# --------------------------------------------------------- small utilities ---
fsize()     { stat -c %s -- "$1" 2>/dev/null || echo 0; }
clear_screen() { [[ -t 1 ]] && clear; return 0; }
pause()     { if [[ -t 0 && $NONINTERACTIVE -eq 0 ]]; then read -r -p "Press Enter to continue..." _ || true; fi; }
term_cols() { local c; c=$(tput cols 2>/dev/null) || c=${COLUMNS:-44}; echo "${c:-44}"; }
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
human() {
  awk -v b="$1" 'BEGIN{
    if (b >= 1073741824) printf "%.2f GB", b/1073741824;
    else if (b >= 1048576) printf "%.1f MB", b/1048576;
    else printf "%.0f KB", b/1024 }'
}
fmt_time() {
  awk -v s="$1" 'BEGIN{ s=int(s); printf "%02d:%02d:%02d", s/3600, (s%3600)/60, s%60 }'
}
pretty() {
  local p=$1 sh="$HOME/storage/shared"
  if [[ $p == "$sh"* ]]; then p="/sdcard${p#"$sh"}"; fi
  printf '%s' "$p"
}
trunc() {
  local m=$(( $(term_cols) - 15 ))
  (( m < 12 )) && m=12
  if (( ${#1} > m )); then printf '%s…' "${1:0:m-1}"; else printf '%s' "$1"; fi
}
to_sec() {   # "90" | "1:30" | "0:01:30.5"  ->  seconds
  [[ $1 =~ ^([0-9]+:){0,2}[0-9]+(\.[0-9]+)?$ ]] || return 1
  awk -F: '{ if (NF==3) print $1*3600+$2*60+$3; else if (NF==2) print $1*60+$2; else print $1 }' <<<"$1"
}
ask() {
  local p=$1 d=${2:-} a
  if [[ -n $d ]]; then
    read -r -p "$p [$d]: " a || exit 0
    printf '%s' "${a:-$d}"
  else
    read -r -p "$p: " a || exit 0
    printf '%s' "$a"
  fi
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
  local a; a=$(ask "$1 (y/n)" "${2:-y}")
  [[ ${a,,} == y* ]]
}
have_enc() { ffmpeg -hide_banner -encoders 2>/dev/null | grep -qw -- "$1"; }
hw_encoder_name() { case $CODEC in hw265) echo hevc_mediacodec;; hw264) echo h264_mediacodec;; esac; }
sel_size() { local t=0 f; for f in "${SELECTED[@]}"; do t=$(( t + $(fsize "$f") )); done; echo "$t"; }

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
    hw265) echo "H.265 hardware (MediaCodec, experimental)";;
    hw264) echo "H.264 hardware (MediaCodec, experimental)";;
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
probe() {
  local f=$1 k v
  SRC_VCODEC=""; SRC_W=""; SRC_H=""; SRC_FPS=0; SRC_VBR=""; SRC_ACODEC=""; SRC_ABR=""
  [[ -f $f ]] || { err "Not a file: $f"; return 1; }
  DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null | head -n1)
  [[ $DUR =~ ^[0-9]+(\.[0-9]+)?$ ]] || { err "Cannot read duration: $(basename -- "$f")"; return 1; }
  while IFS='=' read -r k v; do
    case $k in
      codec_name)   SRC_VCODEC=$v;;
      width)        SRC_W=$v;;
      height)       SRC_H=$v;;
      r_frame_rate) SRC_FPS=$(awk -F/ -v r="$v" 'BEGIN{ split(r,a,"/"); if (a[2]>0) printf "%.2f", a[1]/a[2]; else print a[1] }');;
      bit_rate)     [[ $v =~ ^[0-9]+$ ]] && SRC_VBR=$(( v / 1000 ));;
    esac
  done < <(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate,bit_rate -of default=nw=1 "$f" 2>/dev/null)
  [[ -n $SRC_VCODEC ]] || { err "No video stream: $(basename -- "$f")"; return 1; }
  while IFS='=' read -r k v; do
    case $k in
      codec_name) SRC_ACODEC=$v;;
      bit_rate)   [[ $v =~ ^[0-9]+$ ]] && SRC_ABR=$(( v / 1000 ));;
    esac
  done < <(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,bit_rate -of default=nw=1 "$f" 2>/dev/null)
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
  case $AUDIO in aac) a=$ABR;; copy) a=${SRC_ABR:-128};; none) a=0;; esac
  awk -v mb="$TARGET_MB" -v d="$EDUR" -v a="$a" \
    'BEGIN{ v = mb*8000*0.97/d - a; if (v < 40) exit 1; printf "%d", v }'
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

diag_probe() {   # $1 file -> D_* fields; fails when there is no video stream
  local f=$1 k v
  D_VCODEC=""; D_W=0; D_H=0; D_PIX=""; D_RFPS=""; D_AFPS=""; D_VSTART=""; D_VTB=""
  D_ACODEC=""; D_ARATE=0; D_ACH=0; D_ASTART=""; D_ANUM=0; D_DUR=0; D_FMT=""
  [[ -f $f ]] || return 1
  while IFS='=' read -r k v; do
    case $k in
      codec_name)     D_VCODEC=$v;;
      width)          D_W=$v;;
      height)         D_H=$v;;
      pix_fmt)        D_PIX=$v;;
      r_frame_rate)   D_RFPS=$v;;
      avg_frame_rate) D_AFPS=$v;;
      start_time)     D_VSTART=$v;;
      time_base)      D_VTB=$v;;
    esac
  done < <(ffprobe -v error -select_streams v:0 \
    -show_entries stream=codec_name,width,height,pix_fmt,r_frame_rate,avg_frame_rate,start_time,time_base \
    -of default=nw=1 "$f" 2>/dev/null)
  [[ -n $D_VCODEC ]] || return 1
  case $D_VCODEC in mjpeg|jpegls|png|bmp|tiff) return 1;; esac
  D_VTS=$(awk -v tb="${D_VTB:-}" 'BEGIN{ n=split(tb,a,"/"); if (n==2 && a[2]+0>0) printf "%d", a[2]; else print 0 }')
  D_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null | head -n1)
  [[ $D_DUR =~ ^[0-9]+(\.[0-9]+)?$ ]] || D_DUR=0
  D_FMT=$(ffprobe -v error -show_entries format=format_name -of csv=p=0 "$f" 2>/dev/null | head -n1)
  D_FMT=${D_FMT%%,*}; D_FMT=${D_FMT//\"/}
  D_ANUM=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$f" 2>/dev/null | awk 'END{print NR}')
  if (( D_ANUM > 0 )); then
    while IFS='=' read -r k v; do
      case $k in
        codec_name)  D_ACODEC=$v;;
        sample_rate) D_ARATE=$v;;
        channels)    D_ACH=$v;;
        start_time)  D_ASTART=$v;;
      esac
    done < <(ffprobe -v error -select_streams a:0 \
      -show_entries stream=codec_name,sample_rate,channels,start_time -of default=nw=1 "$f" 2>/dev/null)
  fi
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
  for iv in "${ivs[@]}"; do
    all+=$'\n'$(ffprobe -v error -select_streams v:0 -read_intervals "$iv" \
      -show_entries packet=pts_time,duration -of csv=p=0 "$f" 2>/dev/null)
  done
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
  local f=$1 mo mdat
  case ${f##*.} in
    mp4|MP4|m4v|M4V|mov|MOV|3gp|3GP|3g2|3G2) ;;
    *) return 0;;
  esac
  # 'moov' before 'mdat' = faststart. Small files fit entirely into the
  # sample window, so the ATOM ORDER must be compared - just searching for
  # 'moov' gave false "faststart" results on files under 2 MB.
  mo=$(LC_ALL=C head -c 2097152 -- "$f" 2>/dev/null | LC_ALL=C grep -abo moov | head -n1 | cut -d: -f1)
  mdat=$(LC_ALL=C head -c 2097152 -- "$f" 2>/dev/null | LC_ALL=C grep -abo mdat | head -n1 | cut -d: -f1)
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
  diag_probe "$f" || { err "No video stream: $(basename -- "$f")"; return 1; }
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
  return 0
}

# ----------------------------------------------------- ffmpeg arg builders ---
build_vf() {
  local f=()
  if (( HEIGHT > 0 )); then
    f+=("scale='if(gt(iw,ih),-2,min($HEIGHT,iw))':'if(gt(iw,ih),min($HEIGHT,ih),-2)'")
  fi
  case $DENOISE in
    1) f+=("hqdn3d=1.5:1.5:6:6");;
    2) f+=("hqdn3d=3:2.5:8:7");;
    3) f+=("hqdn3d=4:3:10:8");;
  esac
  if (( FPS > 0 )) && awk -v s="$SRC_FPS" -v t="$FPS" 'BEGIN{ exit !(s > t+0.5) }'; then
    f+=("fps=$FPS")
  fi
  (IFS=,; printf '%s' "${f[*]}")
}
build_venc() {   # $1 = single|p1|p2   $2 = video kbps (empty = CRF mode)
  local pass=$1 br=$2 xp="log-level=error"
  VENC=()
  case $CODEC in
    x265)
      VENC+=(-c:v libx265 -preset "$SPEED" -pix_fmt yuv420p)
      [[ $OUT_EXT == mp4 ]] && VENC+=(-tag:v hvc1)
      if [[ -n $br ]]; then VENC+=(-b:v "${br}k"); else VENC+=(-crf "$CRF"); fi
      case $pass in
        p1) xp+=":pass=1:stats=$TMPD/x265.stats";;
        p2) xp+=":pass=2:stats=$TMPD/x265.stats";;
      esac
      VENC+=(-x265-params "$xp");;
    x264)
      VENC+=(-c:v libx264 -preset "$SPEED" -pix_fmt yuv420p)
      if [[ -n $br ]]; then VENC+=(-b:v "${br}k"); else VENC+=(-crf "$CRF"); fi
      case $pass in
        p1) VENC+=(-pass 1 -passlogfile "$TMPD/x264");;
        p2) VENC+=(-pass 2 -passlogfile "$TMPD/x264");;
      esac;;
    av1)
      VENC+=(-c:v libsvtav1 -preset "$(svt_preset_num)" -pix_fmt yuv420p)
      if [[ -n $br ]]; then VENC+=(-b:v "${br}k"); else VENC+=(-crf "$CRF"); fi;;
    hw265) VENC+=(-c:v hevc_mediacodec -b:v "${br:-$VBR}k")
           [[ $OUT_EXT == mp4 ]] && VENC+=(-tag:v hvc1);;
    hw264) VENC+=(-c:v h264_mediacodec -b:v "${br:-$VBR}k");;
  esac
}
build_aenc() {
  case $AUDIO in
    none) AENC=(-an);;
    copy) AENC=(-c:a copy);;
    *)    local ac=2; (( ABR <= 48 )) && ac=1
          AENC=(-c:a aac -b:a "${ABR}k" -ac "$ac");;
  esac
}

# --------------------------------------------------- progress-bar runner -----
# run_ffmpeg LABEL PASS_INDEX PASS_TOTAL <ffmpeg args...>
run_ffmpeg() {
  local label=$1 pi=$2 pt=$3 rc cols w
  shift 3
  mkdir -p "$CONF_DIR" 2>/dev/null
  if (( SIMPLE )); then
    ffmpeg -nostdin -hide_banner -loglevel error -y "$@" 2>>"${LOGF:-$LOG}"
    return $?
  fi
  cols=$(term_cols); w=$(( cols - 34 )); (( w < 8 )) && w=8; (( w > 28 )) && w=28
  ffmpeg -nostdin -hide_banner -loglevel error -progress pipe:1 -nostats -y "$@" 2>>"${LOGF:-$LOG}" |
  {
    cur=0; spd=""
    while IFS='=' read -r key val; do
      case $key in
        out_time_us|out_time_ms) [[ $val =~ ^[0-9]+$ ]] && cur=$val;;
        speed) spd=${val//[x ]/}; [[ $spd =~ ^[0-9.]+$ ]] || spd="";;
        progress)
          read -r pct eta < <(awk -v c="$cur" -v d="$EDUR" -v pi="$pi" -v pt="$pt" -v s="$spd" 'BEGIN{
              p = c/1e6/d; if (p > 1) p = 1; if (p < 0) p = 0;
              pct = int(((pi-1) + p) / pt * 100);
              if (s+0 > 0) { r = ((1-p) + (pt-pi)) * d / s;
                printf "%d %02d:%02d:%02d\n", pct, r/3600, (r%3600)/60, r%60 }
              else printf "%d --:--:--\n", pct }')
          filled=$(( pct * w / 100 ))
          printf -v b1 '%*s' "$filled" ''; printf -v b2 '%*s' "$(( w - filled ))" ''
          sp=${spd:+${spd}x}
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
    p=$(awk -v a="$(fsize "$dst.vcmove" 2>/dev/null || echo 0)" -v b="$sz" \
      'BEGIN{ if (b+0>0) { x=int(a*100/b); if (x>100) x=100 } else x=0; printf "%d", x }')
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
compress_file() {
  local src=$1 fidx=${2:-0} fn=${3:-0} tag=""
  local name dst tmp in_sz out_sz saved passes=1 br="" vf rc=0 odur status t0=$SECONDS
  local extarg=() maps=() scodec=() submeta=() fmt fast subfilter="" srt="" keepsubs subn
  (( fidx > 0 )) && tag="[$fidx/$fn] "
  name=$(basename -- "$src")
  if ! probe "$src"; then
    add_result "$name" "-" "-" "-" "-" "FAILED (unreadable)" "$src" ""
    tally fail; return 1
  fi
  in_sz=$(fsize "$src")
  if ! calc_edur; then
    err "Trim range is outside the video."
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (trim)" "$src" ""
    tally fail; return 1
  fi
  printf '  %s%s%dx%d %s %s fps | %s | %s%s\n' "$tag" "$C_D" "$SRC_W" "$SRC_H" "$SRC_VCODEC" "$SRC_FPS" \
    "$(fmt_time "$EDUR")" "$(human "$in_sz")" "$C_0"

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

  TMPD=$(mktemp -d) || { err "Cannot create temp dir."; return 1; }
  dst=$(unique_out "$src")
  if [[ $OUT_EXT == mp4 ]]; then
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
      info "Embedding subtitles: $(basename -- "$srt")"
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
  if (( keepsubs )) && (( $(count_subs "$src") > 0 )) && ! sub_codecs_ok "$src"; then
    warn "Bitmap subtitles (PGS/DVD) cannot be copied to this container - dropping them."
    keepsubs=0
  fi
  [[ -n $subfilter ]] && keepsubs=0   # burned subtitles replace tracks

  maps=(-map 0:v:0 -map '0:a?')
  if [[ -n $srt ]]; then
    extarg=(-i "$srt")
    maps+=(-map '0:s?' -map 1:0)
  elif (( keepsubs )); then
    maps+=(-map '0:s?')
  fi
  if (( ${#maps[@]} > 2 )); then
    if [[ $OUT_EXT == mkv ]]; then scodec=(-c:s srt); else scodec=(-c:s mov_text); fi
  fi
  if [[ -n $srt ]]; then
    subn=$(count_subs "$src")
    local sublang=$SUB_LANG
    [[ $OUT_EXT == mp4 ]] && sublang=$(lang3 "$sublang")
    submeta=(-metadata:s:s:$subn language="$sublang")
  fi

  fmt=(-f mp4); fast=(-movflags +faststart)
  [[ $OUT_EXT == mkv ]] && { fmt=(-f matroska); fast=(); }
  (( OT_DIRECT )) && fast=()

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

  out_sz=$(fsize "$dst")
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
  RESULTS=(); N_OK=0; N_FAIL=0; TOTAL_IN=0; TOTAL_OUT=0
  BATCH_TMP=$(mktemp -d) || { err "Cannot create temp dir."; return 1; }
  wake_lock
  [[ -z $VC_NOSTAGE ]] && stage_root   # one shared build area: parallel children inherit it
  local i=0 n=${#SELECTED[@]} f st a b
  if (( PARALLEL_JOBS > 1 )); then
    info "Parallel mode: up to $PARALLEL_JOBS files at once ($n total)"
    for f in "${SELECTED[@]}"; do
      i=$(( i + 1 ))
      while (( $(jobs -rp | wc -l) >= PARALLEL_JOBS )); do wait -n || true; done
      printf '%s[%d/%d] %s%s\n' "$C_B" "$i" "$n" "$(trunc "$(basename -- "$f")")" "$C_0"
      (
        SIMPLE=1 LOGF="$BATCH_TMP/log_$i" STATS="$BATCH_TMP/stats" RESULT_FILE="$BATCH_TMP/results"
        compress_file "$f" "$i" "$n"
      ) &
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
  find "$1" -maxdepth 1 -type f -regextype posix-extended -iregex ".*\.($VIDEO_EXT)" \
    -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-
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
  local dir=$1 files=() ans toks tok lo hi n added f i
  mapfile -t files < <(list_videos "$dir" | head -n 60)
  if (( ${#files[@]} == 0 )); then warn "No videos in $(pretty "$dir")"; return 1; fi
  while true; do
    printf '\n%s%s%s  (newest first)\n' "$C_B" "$(pretty "$dir")" "$C_0"
    for i in "${!files[@]}"; do
      printf ' %2d) %8s  %s\n' $(( i + 1 )) "$(human "$(fsize "${files[i]}")")" "$(trunc "$(basename -- "${files[i]}")")"
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
  local cur="${HOME}/storage/shared" ans i rel v vids=() dirs=()
  [[ -d $cur ]] || cur="$HOME"
  while true; do
    clear_screen
    printf '%s== Browse folders ==%s\n\n' "$C_B" "$C_0"
    printf ' %s\n\n' "$(pretty "$cur")"
    mapfile -t dirs < <(find "$cur" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' 2>/dev/null | LC_ALL=C sort | head -n 40)
    mapfile -t vids < <(list_videos "$cur" | head -n 40)
    for i in "${!dirs[@]}"; do printf ' d%-2d) %s/\n' $(( i + 1 )) "${dirs[i]}"; done
    (( ${#dirs[@]} > 0 )) && echo
    for i in "${!vids[@]}"; do
      printf ' %3d) %8s  %s\n' $(( i + 1 )) "$(human "$(fsize "${vids[i]}")")" "$(trunc "$(basename -- "${vids[i]}")")"
    done
    (( ${#vids[@]} == 0 )) && echo "  (no videos in this folder)"
    echo
    echo " number = select video   d<n> = open folder   a = add all here"
    echo " p = type a path   u = go up   b = back"
    read -r -p "> " ans || return
    case ${ans,,} in
      b|"") return;;
      u) cur=$(dirname -- "$cur");;
      p) ans=$(ask "Path (file or folder)" "")
         [[ -n $ans ]] && { add_path "$ans"; return; };;
      a) if (( ${#vids[@]} > 0 )); then
           for v in "${vids[@]}"; do add_sel "$v"; done
           ok "Added ${#vids[@]} video(s) from this folder."
           return
         fi;;
      d*)
        rel=${ans#d}
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
  local c
  while true; do
    printf '\n%sChoose videos%s\n' "$C_B" "$C_0"
    echo " 1) Browse folders (full file browser)"
    echo " 2) Quick locations (Camera, Download, Telegram, ...)"
    echo " 3) Type/paste a path (file or folder)"
    echo " b) back"
    read -r -p "> " c || return
    case $c in
      1) browse_folders; return;;
      2) quick_locations && return;;
      3) c=$(ask "Path" ""); [[ -n $c ]] && { add_path "$c"; return; };;
      b|B|"") return;;
    esac
  done
}

# --- v2.0: queue management ---------------------------------------------------
queue_menu() {
  local c i n
  while true; do
    clear_screen
    n=${#SELECTED[@]}
    printf '%s== Queue ==%s  (%d file(s), %s)\n\n' "$C_B" "$C_0" "$n" "$(human "$(sel_size)")"
    if (( n == 0 )); then
      echo "  (empty - choose videos first)"
    else
      for i in "${!SELECTED[@]}"; do
        printf ' %2d) %8s  %s\n' $(( i + 1 )) "$(human "$(fsize "${SELECTED[i]}")")" "$(trunc "$(pretty "${SELECTED[i]}")")"
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
  a_sub=$(count_subs "$f1")
  probe "$f2" || return 1
  b_sz=$(fsize "$f2"); b_dur=$DUR
  b_res="${SRC_W}x${SRC_H} ${SRC_VCODEC}"; b_fps=$SRC_FPS
  b_br=${SRC_VBR:-$(awk -v s="$b_sz" -v d="$DUR" 'BEGIN{ if (d+0>0) printf "%d", s*8/d/1000; else print "?" }')}
  b_ac="${SRC_ACODEC:-none}${SRC_ABR:+, ${SRC_ABR} kbps}"
  b_sub=$(count_subs "$f2")
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

repair_file() {   # $1 src, $2 optional "[i/n] " tag -> TV-friendly MP4
  local src=$(readlink -f -- "$1") tag=${2:-}
  local name base dir out tmp rc t0=$SECONDS in_sz out_sz saved need tier
  local vfix=0 afix=0 vf="" fps_arg="" fps_show="" abr=192 vfps=0 stereo=""
  local vst ast b_timing b_ts b_vts b_vinfo b_ainfo b_fast b_gap n_vst n_ast n_gap negts=0 c
  local after_timing="?" after_ts="?" after_fast="?" nsubs extra_audio
  local -a vreasons=() areasons=() fargs=() venc=() aargs=() fast=()
  name=$(basename -- "$src"); in_sz=$(fsize "$src")
  if ! diag_probe "$src"; then err "${tag}Not a (supported) video file: $name"; return 1; fi
  diag_vfr_scan "$src"; diag_faststart "$src"
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
  nsubs=$(count_subs "$src")
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
    info "${tag}Plan: $tier$( (( vfix )) && printf ' - %s' "$(IFS=', '; printf '%s' "${vreasons[*]}")" )$( (( afix && D_ANUM > 0 )) && printf ' + audio fix' )"
  fi

  # ---- run the repair (output is BUILT on fast local storage first, so
  #      ffmpeg's faststart index shift can never fail on Android storage)
  out=$(unique_file "$dir" "${base}_repaired" "mp4")
  need=$(( in_sz + 65536 ))
  (( vfix )) && need=$(( in_sz * 3 / 4 + 1048576 ))
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
  fargs+=(-sn -map_metadata -1 -map_chapters -1 -muxdelay 0 -avoid_negative_ts make_zero \
    "${fast[@]}" -max_muxing_queue_size 4096 -f mp4 "$tmp")
  run_ffmpeg "repair" 1 1 "${fargs[@]}"
  rc=$?
  CUR_TMP=""
  if (( rc != 0 )) || [[ ! -s $tmp ]]; then
    err "${tag}Repair failed (ffmpeg exit $rc). Last log lines:"
    tail -n 6 "$LOG" | sed 's/^/    /' >&2
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
  (( nsubs > 0 )) && extract_subs_silent "$src" "${out%.*}"
  out_sz=$(fsize "$out")

  # ---- verify: show what changed
  if diag_probe "$out" && diag_vfr_scan "$out" && diag_faststart "$out"; then
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
  ok "${tag}Repaired: $(basename -- "$out")  $(human "$in_sz") -> $(human "$out_sz")  (${saved}, $(fmt_time $(( SECONDS - t0 ))))"
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
  add_result "$name" "$(human "$in_sz")" "$(human "$out_sz")" "${saved}" "$(fmt_time $(( SECONDS - t0 )))" "REPAIRED" "$src" "$out"
  tally ok "$in_sz" "$out_sz"
  if (( REPAIR_AUTO == 0 )); then yesno "Open it now?" n && open_file "$out"; fi
  return 0
}

quickfix_file() {   # $1 src, $2 optional tag -> remux to a clean faststart MP4 (seconds)
  local src=$(readlink -f -- "$1") tag=${2:-}
  local name base dir out tmp rc t0=$SECONDS in_sz out_sz nsubs
  local -a fargs=() fast=()
  name=$(basename -- "$src")
  if ! diag_probe "$src"; then err "${tag}Not a (supported) video file: $name"; return 1; fi
  diag_vfr_scan "$src"
  in_sz=$(fsize "$src"); dir=$(dirname -- "$src"); base=${name%.*}
  printf '  %s%s%s %dx%d %s %s | %s | %s%s\n' "$tag" "$C_D" "$(trunc "$name")" \
    "$D_W" "$D_H" "$D_VCODEC" "$D_PIX" "$(fmt_time "$D_DUR")" "$(human "$in_sz")" "$C_0"
  out=$(unique_file "$dir" "${base}_fixed" "mp4")
  out_tmp "$out" "$(( in_sz + 65536 ))"; tmp=$OT_TMP; CUR_TMP=$tmp
  fast=(-movflags +faststart); (( OT_DIRECT )) && fast=()
  EDUR=$D_DUR
  mkdir -p "$CONF_DIR" 2>/dev/null
  fargs=(-fflags +genpts -i "$src" -map 0:v:0)
  (( D_ANUM > 0 )) && fargs+=(-map 0:a:0)
  fargs+=(-c copy -sn -map_metadata -1 -map_chapters -1 -muxdelay 0 -avoid_negative_ts make_zero \
    "${fast[@]}" -max_muxing_queue_size 4096 -f mp4 "$tmp")
  run_ffmpeg "quickfix" 1 1 "${fargs[@]}"
  rc=$?; CUR_TMP=""
  if (( rc != 0 )) || [[ ! -s $tmp ]]; then
    err "${tag}Quick fix failed (ffmpeg exit $rc). Last log lines:"
    tail -n 6 "$LOG" | sed 's/^/    /' >&2
    rm -f -- "$tmp"
    tally fail
    return 1
  fi
  if ! commit_out "$tmp" "$out"; then
    err "${tag}Could not move the fixed file into place."
    tally fail
    return 1
  fi
  nsubs=$(count_subs "$src"); (( nsubs > 0 )) && extract_subs_silent "$src" "${out%.*}"
  out_sz=$(fsize "$out")
  ok "${tag}Fixed: $(basename -- "$out")  $(human "$in_sz") -> $(human "$out_sz")  ($(fmt_time $(( SECONDS - t0 ))))"
  (( D_ROUND )) && warn "Timestamps are still rounded (gradual TV drift) - run Auto-Repair to rebuild them."
  (( D_VFR && ! D_ROUND )) && warn "Video is still variable frame rate - run Auto-Repair to stop the drift."
  [[ $D_VCODEC != h264 ]] && warn "Video codec kept as '$D_VCODEC' - run Auto-Repair to convert to H.264."
  if (( D_ANUM > 0 )); then
    case $D_ACODEC in aac|ac3|eac3) ;; *) warn "Audio codec kept as '$D_ACODEC' - run Auto-Repair to convert to AAC.";; esac
    [[ $D_ARATE == 48000 ]] || warn "Audio kept at ${D_ARATE:-?} Hz - run Auto-Repair to resample to 48 kHz."
  fi
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
  add_result "$name" "$(human "$in_sz")" "$(human "$out_sz")" "0%" "$(fmt_time $(( SECONDS - t0 )))" "QUICKFIXED" "$src" "$out"
  tally ok "$in_sz" "$out_sz"
  if (( REPAIR_AUTO == 0 )); then yesno "Open it now?" n && open_file "$out"; fi
  return 0
}

sync_shift_file() {   # $1 src  $2 milliseconds (positive = delay the audio)
  local src=$(readlink -f -- "$1") ms=$2 off name base dir out tmp rc t0=$SECONDS in_sz out_sz nsubs
  local -a aargs=() fast=()
  [[ $ms =~ ^-?[0-9]+$ ]] || { err "Shift must be a number of milliseconds (e.g. 250 or -250)."; return 1; }
  (( ms == 0 )) && { err "A shift of 0 ms does nothing."; return 1; }
  (( ms > 10000 || ms < -10000 )) && { err "Use a shift between -10000 and 10000 ms."; return 1; }
  if ! diag_probe "$src"; then err "Not a (supported) video file."; return 1; fi
  (( D_ANUM > 0 )) || { err "This file has no audio track."; return 1; }
  off=$(awk -v m="$ms" 'BEGIN{ printf "%.3f", m / 1000 }')
  name=$(basename -- "$src"); base=${name%.*}; dir=$(dirname -- "$src"); in_sz=$(fsize "$src")
  if (( ms > 0 )); then info "Delaying audio by ${ms} ms (audio was too early)."
  else info "Advancing audio by ${ms#-} ms (audio was too late)."; fi
  case $D_ACODEC in
    aac|mp3|ac3|eac3) aargs=(-c:a copy);;
    *) aargs=(-c:a aac -b:a 192k -af "aresample=async=1")
       warn "Audio re-encoded to AAC ('$D_ACODEC' is not safe in MP4).";;
  esac
  out=$(unique_file "$dir" "${base}_shifted" "mp4")
  out_tmp "$out" "$(( in_sz + 65536 ))"; tmp=$OT_TMP; CUR_TMP=$tmp
  fast=(-movflags +faststart); (( OT_DIRECT )) && fast=()
  EDUR=$D_DUR
  mkdir -p "$CONF_DIR" 2>/dev/null
  run_ffmpeg "shift" 1 1 -i "$src" -itsoffset "$off" -i "$src" \
    -map 0:v:0 -map 1:a:0 -c:v copy "${aargs[@]}" -sn -map_metadata -1 \
    -avoid_negative_ts make_zero -muxdelay 0 "${fast[@]}" \
    -max_muxing_queue_size 4096 -f mp4 "$tmp"
  rc=$?; CUR_TMP=""
  if (( rc != 0 )) || [[ ! -s $tmp ]]; then
    err "Audio shift failed (ffmpeg exit $rc). Last log lines:"
    tail -n 6 "$LOG" | sed 's/^/    /' >&2
    rm -f -- "$tmp"
    tally fail
    return 1
  fi
  if ! commit_out "$tmp" "$out"; then
    err "Could not move the shifted file into place."
    tally fail
    return 1
  fi
  nsubs=$(count_subs "$src"); (( nsubs > 0 )) && extract_subs_silent "$src" "${out%.*}"
  out_sz=$(fsize "$out")
  if diag_probe "$out"; then
    ok "New start times - video: $(num_or0 "$D_VSTART") s, audio: $(num_or0 "$D_ASTART") s"
  fi
  ok "Shifted file: $(pretty "$out")  ($(human "$in_sz") -> $(human "$out_sz"))"
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$out" >/dev/null 2>&1 & }
  add_result "$name" "$(human "$in_sz")" "$(human "$out_sz")" "0%" "$(fmt_time $(( SECONDS - t0 )))" "SHIFTED" "$src" "$out"
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

repair_batch() {   # repair every queued video (sequential or -j parallel)
  (( ${#SELECTED[@]} )) || { err "No videos selected."; return 1; }
  local prev_auto=$REPAIR_AUTO
  REPAIR_AUTO=1
  mkdir -p "$CONF_DIR"; : > "$LOG"
  RESULTS=(); N_OK=0; N_FAIL=0; TOTAL_IN=0; TOTAL_OUT=0
  BATCH_TMP=$(mktemp -d) || { err "Cannot create temp dir."; REPAIR_AUTO=$prev_auto; return 1; }
  wake_lock
  [[ -z $VC_NOSTAGE ]] && stage_root   # one shared build area: parallel children inherit it
  local i=0 n=${#SELECTED[@]} f st a b
  if (( PARALLEL_JOBS > 1 && n > 1 )); then
    info "Parallel repair: up to $PARALLEL_JOBS files at once ($n total)"
    for f in "${SELECTED[@]}"; do
      i=$(( i + 1 ))
      while (( $(jobs -rp | wc -l) >= PARALLEL_JOBS )); do wait -n || true; done
      printf '%s[%d/%d] %s%s\n' "$C_B" "$i" "$n" "$(trunc "$(basename -- "$f")")" "$C_0"
      (
        SIMPLE=1 LOGF="$BATCH_TMP/log_$i" STATS="$BATCH_TMP/stats" RESULT_FILE="$BATCH_TMP/results"
        REPAIR_AUTO=1 repair_file "$f" "[$i/$n] "
      ) &
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
      printf '\n%s== Repair [%d/%d]: %s ==%s\n' "$C_B" "$i" "$n" "$(basename -- "$f")" "$C_0"
      repair_file "$f" "[$i/$n] " || true
    done
  fi
  rm -rf "$BATCH_TMP"; BATCH_TMP=""
  wake_unlock
  print_summary
  notify "Repair finished: $N_OK ok, $N_FAIL failed"
  REPAIR_AUTO=$prev_auto
  (( N_FAIL == 0 ))
}

repair_menu() {
  local vid="" c
  while true; do
    clear_screen
    printf '%s== Repair & Sync ==%s\n\n' "$C_B" "$C_0"
    if [[ -n $vid ]]; then printf ' Target: %s\n' "$(trunc "$(pretty "$vid")")"
    else printf ' Target: (none selected)\n'; fi
    printf ' Fixes audio/video drift and playback problems on TVs & USB players.\n\n'
    echo " 1) Select target video"
    echo " 2) Diagnose (check sync & TV compatibility)"
    echo " 3) Auto-Repair (smart tiers + turbo - re-encodes only what is broken)"
    echo " 4) Quick fix (seconds - faststart + clean MP4, no re-encode)"
    echo " 5) Shift audio by +/- milliseconds (constant early/late audio)"
    echo " 6) Repair all queued videos (batch, uses -j parallel jobs)"
    echo " b) back"
    read -r -p "> " c || return
    case $c in
      1) if pick_target; then vid=$PICK_RESULT; ok "Target: $(basename -- "$vid")"; fi;;
      2) if [[ -n $vid ]]; then diag_report "$vid"; pause; fi;;
      3) if [[ -n $vid ]]; then repair_file "$vid"; pause; fi;;
      4) if [[ -n $vid ]]; then quickfix_file "$vid"; pause; fi;;
      5) if [[ -n $vid ]]; then shift_audio_dialog "$vid"; pause; fi;;
      6) if (( ${#SELECTED[@]} )); then
           repair_batch; pause
         else warn "Queue is empty - choose videos from the main menu first."; fi;;
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
  fi
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
  fi
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
         err "Screenshot failed."
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
}

# --------------------------------------------------------------- info tools ---
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
    printf '  Subtitles : %s track(s)\n' "$(count_subs "$f")"
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
    pkg install -y ffmpeg gawk || err "pkg install failed (try: pkg update)"
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
  c=$(ask "Choose" "")
  case $c in 1) CODEC=x265;; 2) CODEC=x264;; 3) CODEC=hw265;; 4) CODEC=hw264;; 5) CODEC=av1;; *) return;; esac
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
  elif [[ $old == av1 && $CODEC == x264 ]];  then CRF=$(( CRF - 13 )); fi
  maxc=51; [[ $CODEC == av1 ]] && maxc=60
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
  echo " 1) MP4 - most compatible (subtitles as mov_text)"
  echo " 2) MKV - keeps SRT subtitles natively, more streams"
  c=$(ask "Choose" "")
  case $c in 1) OUT_EXT=mp4;; 2) OUT_EXT=mkv;; esac
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
    echo " 4) Make GIF from a video"
    echo " 5) Extract audio (MP3 / M4A)"
    echo " 6) Thumbnail / contact sheet"
    echo " 7) Check installation / encoders"
    echo " 8) Setup (install ffmpeg, storage access)"
    echo " 9) Install 'vc' command"
    echo "10) Show last log"
    echo " b) back"
    read -r -p "> " c || exit 0
    case $c in
      1) show_info; pause;;
      2) estimate_size; pause;;
      3) sub_studio;;
      4) make_gif; pause;;
      5) extract_audio; pause;;
      6) make_thumb; pause;;
      7) check_deps; pause;;
      8) do_setup; pause;;
      9) do_install; pause;;
      10) if [[ -s $LOG ]]; then tail -n 40 "$LOG"; else echo "(log is empty)"; fi; pause;;
      b|B|"") return;;
    esac
  done
}

# ------------------------------------------------------------- main menu ----
print_plan() {
  local tot=0 f
  for f in "${SELECTED[@]}"; do tot=$(( tot + $(fsize "$f") )); done
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
    n=${#SELECTED[@]}; tot=0
    for f in "${SELECTED[@]}"; do tot=$(( tot + $(fsize "$f") )); done
    printf '%sVidCompress v%s%s  -  by %s\n' "$C_B" "$VERSION" "$C_0" "$CREATOR"
    printf '%s%s%s\n' "$C_D" "$WEBSITE" "$C_0"
    printf '%s------------------------------------------%s\n' "$C_D" "$C_0"
    printf ' Selected : %d file(s), %s\n' "$n" "$(human "$tot")"
    printf ' Preset   : %s\n' "$PRESET_NAME"
    printf ' Plan     : %s\n\n' "$(trunc "$(plan_line)")"
    echo " 1) Choose videos (browser / quick locations)"
    echo " 2) Queue (view / remove)"
    echo " 3) Choose preset"
    echo " 4) Advanced settings"
    echo " 5) Profiles (save / load)"
    echo " 6) Subtitle studio (SRT add / extract / remove)"
    echo " 7) Repair & sync (fix A/V drift for TVs)"
    echo " 8) Tools (info, estimate, GIF, audio, thumbs)"
    echo " 9) START compression"
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
  # remove the local build area with anything left in it (crashed jobs etc.)
  [[ -n $STAGE_ROOT && -d $STAGE_ROOT ]] && rm -rf -- "$STAGE_ROOT"
  wake_unlock
}
on_int() {
  printf '\n'; warn "Interrupted - cleaning up."
  [[ -n $CUR_TMP ]] && rm -f -- "$CUR_TMP"
  exit 130
}

main() {
  local STUDIO=0
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
  [[ $OUT_EXT == mkv ]] || OUT_EXT=mp4
  [[ $KEEP_SUBS =~ ^[01]$ ]] || KEEP_SUBS=1
  [[ $PARALLEL_JOBS =~ ^[1-8]$ ]] || PARALLEL_JOBS=1
  [[ $SUB_SIZE =~ ^[0-9]+$ ]] || SUB_SIZE=24
  [[ -n $SUB_LANG ]] || SUB_LANG=fa

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

  local OPT PRESET_ARG="" OV_T="" OV_C="" OV_R="" OV_F="" OV_S="" OV_K="" OV_A="" OV_O="" OV_J="" OV_TS="" OV_TE="" OV_D=0 AUTO=0
  while getopts "p:t:c:r:f:s:k:a:S:E:o:j:dyh" OPT; do
    case $OPT in
      p) PRESET_ARG=$OPTARG;; t) OV_T=$OPTARG;; c) OV_C=$OPTARG;; r) OV_R=$OPTARG;;
      f) OV_F=$OPTARG;; s) OV_S=$OPTARG;; k) OV_K=$OPTARG;; a) OV_A=$OPTARG;;
      S) OV_TS=$OPTARG;; E) OV_TE=$OPTARG;; o) OV_O=$OPTARG;; j) OV_J=$OPTARG;;
      d) OV_D=1;; y) AUTO=1;;
      h) usage; exit 0;; *) usage; exit 1;;
    esac
  done
  shift $(( OPTIND - 1 ))

  if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    err "ffmpeg/ffprobe not found."
    if [[ -t 0 ]] && yesno "Install now?" y; then do_setup; else echo "Run: vc --setup   (or: pkg install ffmpeg)"; exit 1; fi
    command -v ffmpeg >/dev/null 2>&1 || exit 1
  fi

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
  if [[ -n $OV_TS ]]; then TRIM_START=$(to_sec "$OV_TS") || { err "Bad -S time"; exit 1; }; fi
  if [[ -n $OV_TE ]]; then TRIM_END=$(to_sec "$OV_TE")   || { err "Bad -E time"; exit 1; }; fi
  (( OV_D )) && DELETE_ORIG=1
  for OPT in CRF TARGET_MB HEIGHT FPS ABR PARALLEL_JOBS; do
    [[ ${!OPT} =~ ^[0-9]+$ ]] || { err "Invalid numeric value for $OPT: ${!OPT}"; exit 1; }
  done
  (( PARALLEL_JOBS >= 1 && PARALLEL_JOBS <= 8 )) || { err "-j must be 1-8"; exit 1; }

  local f
  for a in "$@"; do
    if [[ -d $a ]]; then
      while IFS= read -r f; do add_sel "$f"; done < <(list_videos "$a")
    elif [[ -f $a ]]; then add_sel "$a"
    else err "Not found: $a"; fi
  done

  trap on_int INT TERM
  trap cleanup EXIT

  if [[ -n $REPAIR_ACTION ]]; then
    local rf
    case $REPAIR_ACTION in
      diagnose)
        (( ${#SELECTED[@]} )) || { err "Usage: vc --diagnose FILE"; exit 1; }
        for rf in "${SELECTED[@]}"; do diag_report "$rf" || true; done
        exit 0;;
      quickfix)
        (( ${#SELECTED[@]} )) || { err "Usage: vc --quickfix FILE"; exit 1; }
        REPAIR_AUTO=1
        for rf in "${SELECTED[@]}"; do quickfix_file "$rf"; done
        exit 0;;
      shift)
        (( ${#SELECTED[@]} == 1 )) || { err "Usage: vc --sync-shift MS FILE (exactly one file)"; exit 1; }
        REPAIR_AUTO=1
        sync_shift_file "${SELECTED[0]}" "$REPAIR_SHIFT_MS"
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
  main_menu
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
