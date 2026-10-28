#!/usr/bin/env bash
# =============================================================================
#  VidCompress (vc) - ffmpeg video compression toolkit for Termux
#  Creator : Alireza123456w6w
#  Website : offers-pishnahadat.vercel.app
# =============================================================================

VERSION="1.1"
CREATOR="Alireza123456w6w"
WEBSITE="offers-pishnahadat.vercel.app"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vidcompress"
CONF="$CONF_DIR/settings.conf"
PROF_DIR="$CONF_DIR/profiles"
LOG="$CONF_DIR/last_run.log"
VIDEO_EXT='mp4|mkv|mov|avi|webm|3gp|m4v|flv|ts|mpg|mpeg|wmv|mts|m2ts'
SETTING_VARS="CODEC CRF VBR SPEED HEIGHT FPS ABR AUDIO TARGET_MB DENOISE STRIP_META OUTDIR SUFFIX PRESET_NAME"
PRESET_LIST="balanced quality small tiny social compat fast target hardware"

# ------------------------------------------------------------------ colors ---
if [[ -t 1 ]]; then
  C_B=\( '\e[1m'; C_D= \)'\e[2m'; C_R=\( '\e[31m'; C_G= \)'\e[32m'
  C_Y=\( '\e[33m'; C_C= \)'\e[36m'; C_0=$'\e[0m'
else
  C_B=; C_D=; C_R=; C_G=; C_Y=; C_C=; C_0=
fi
ok()   { printf '%s\n' "${C_G}✔ \( * \){C_0}"; }
warn() { printf '%s\n' "${C_Y}! \( * \){C_0}" >&2; }
err()  { printf '%s\n' "${C_R}✘ \( * \){C_0}" >&2; }
info() { printf '%s\n' "\( {C_C} \)*${C_0}"; }

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
WAKE=0
EDUR=0
DUR=0
N_OK=0
N_FAIL=0
TOTAL_IN=0
TOTAL_OUT=0
NONINTERACTIVE=0

# --------------------------------------------------------- small utilities ---
fsize()     { stat -c %s -- "$1" 2>/dev/null || echo 0; }
clear_screen() { [[ -t 1 ]] && clear; return 0; }
pause()     { if [[ -t 0 && $NONINTERACTIVE -eq 0 ]]; then read -r -p "Press Enter to continue..." _ || true; fi; }
term_cols() { local c; c=\( (tput cols 2>/dev/null) || c= \){COLUMNS:-44}; echo "${c:-44}"; }

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
  if [[ $p == "\( sh"* ]]; then p="/sdcard \){p#"$sh"}"; fi
  printf '%s' "$p"
}
trunc() {
  local m=$(( $(term_cols) - 15 ))
  (( m < 12 )) && m=12
  if (( \( {#1} > m )); then printf '%s…' " \){1:0:m-1}"; else printf '%s' "$1"; fi
}
to_sec() {
  [[ $1 =\~ ^([0-9]+:){0,2}[0-9]+(\.[0-9]+)?$ ]] || return 1
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
ask_int() {
  local a
  while true; do
    a=$(ask "$1 ($2-$3)" "$4")
    if [[ \( a =\~ ^[0-9]+ \) ]] && (( a >= $2 && a <= $3 )); then printf '%s' "$a"; return; fi
    err "Enter a number between $2 and $3." >&2
  done
}
yesno() {
  local a; a=$(ask "$1 (y/n)" "${2:-y}")
  [[ ${a,,} == y* ]]
}
have_enc() { ffmpeg -hide_banner -encoders 2>/dev/null | grep -qw -- "$1"; }
hw_encoder_name() { case $CODEC in hw265) echo hevc_mediacodec;; hw264) echo h264_mediacodec;; esac; }

# ----------------------------------------------------------------- presets ---
preset_desc() {
  case $1 in
    balanced) echo "H.265, CRF 26, 720p, AAC 96k - best all-round (default)";;
    quality)  echo "H.265, CRF 22, original resolution - near-transparent";;
    small)    echo "H.265, CRF 30, 480p, 30 fps - small files";;
    tiny)     echo "H.265, CRF 33, 360p, 24 fps - smallest, for sharing";;
    social)   echo "H.264, 720p, 30 fps - fast, plays everywhere (chat apps)";;
    compat)   echo "H.264, CRF 23, original resolution - max compatibility";;
    fast)     echo "H.264 veryfast, 720p - quick encode for slow phones";;
    target)   echo "H.265 two-pass, 720p, \~95 MB (change size in Settings)";;
    hardware) echo "Phone's hardware H.265 encoder - very fast, experimental";;
  esac
}
apply_preset() {
  PRESET_NAME=$1
  CODEC=x265; CRF=26; VBR=1800; SPEED=medium; HEIGHT=720; FPS=0
  AUDIO=aac; ABR=96; TARGET_MB=0
  case $1 in
    balanced) ;;
    quality)  CRF=22; SPEED=slow; HEIGHT=0; ABR=128;;
    small)    CRF=30; HEIGHT=480; FPS=30; ABR=64;;
    tiny)     CRF=33; HEIGHT=360; FPS=24; ABR=48;;
    social)   CODEC=x264; CRF=26; SPEED=veryfast; FPS=30;;
    compat)   CODEC=x264; CRF=23; HEIGHT=0; ABR=128;;
    fast)     CODEC=x264; CRF=28; SPEED=veryfast;;
    target)   TARGET_MB=95;;
    hardware) CODEC=hw265;;
    *) return 1;;
  esac
}
set_defaults() {
  apply_preset balanced
  DENOISE=0; STRIP_META=0; OUTDIR=""; SUFFIX="_compressed"
  DELETE_ORIG=0; TRIM_START=""; TRIM_END=""
}

# ------------------------------------------------------ settings & profiles ---
write_settings() { local v; for v in $SETTING_VARS; do printf '%s=%q\n' "\( v" " \){!v}"; done > "$1"; }
save_settings()  { write_settings "$CONF"; }
load_conf()      { [[ -f $1 ]] && source "$1"; return 0; }

# ------------------------------------------------------------------ labels ---
codec_label() {
  case $CODEC in
    x265)  echo "H.265 / HEVC (libx265)";;
    x264)  echo "H.264 / AVC (libx264)";;
    hw265) echo "H.265 hardware (MediaCodec, experimental)";;
    hw264) echo "H.264 hardware (MediaCodec, experimental)";;
  esac
}
mode_label() {
  if (( TARGET_MB > 0 )); then echo "Target size \~${TARGET_MB} MB (two-pass)"
  elif [[ $CODEC == hw* ]]; then echo "Bitrate ${VBR} kbps"
  else echo "CRF $CRF (lower = better quality)"; fi
}
res_label()     { if (( HEIGHT > 0 )); then echo "max ${HEIGHT}p (never upscaled)"; else echo "keep original"; fi; }
fps_label()     { if (( FPS > 0 )); then echo "max $FPS fps"; else echo "keep original"; fi; }
audio_label()   { case $AUDIO in copy) echo "copy (no re-encode)";; none) echo "remove audio";; *) echo "AAC ${ABR} kbps";; esac; }
denoise_label() { case $DENOISE in 1) echo light;; 2) echo medium;; *) echo off;; esac; }
yn_label()      { if (( $1 )); then echo yes; else echo no; fi; }
out_label()     { if [[ -n $OUTDIR ]]; then pretty "$OUTDIR"; else echo "same folder as source"; fi; }
trim_label() {
  if [[ -n $TRIM_START || -n $TRIM_END ]]; then
    local e="end"; [[ -n \( TRIM_END ]] && e=" \){TRIM_END}s"
    echo "${TRIM_START:-0}s -> $e"
  else echo off; fi
}
plan_line() {
  local r="orig"; (( HEIGHT > 0 )) && r="<=${HEIGHT}p"
  local m="CRF $CRF"
  (( TARGET_MB > 0 )) && m="\~${TARGET_MB}MB"
  [[ $CODEC == hw* && \( TARGET_MB -eq 0 ]] && m=" \){VBR}k"
  echo "$CODEC | $m | $r | $(audio_label)"
}

# --------------------------------------------------------------- probing -----
probe() {
  local f=$1 k v
  SRC_VCODEC=""; SRC_W=""; SRC_H=""; SRC_FPS=0; SRC_VBR=""; SRC_ACODEC=""; SRC_ABR=""
  [[ -f $f ]] || { err "Not a file: $f"; return 1; }
  DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null | head -n1)
  [[ \( DUR =\~ ^[0-9]+(\.[0-9]+)? \) ]] || { err "Cannot read duration: $(basename -- "$f")"; return 1; }
  while IFS='=' read -r k v; do
    case $k in
      codec_name)   SRC_VCODEC=$v;;
      width)        SRC_W=$v;;
      height)       SRC_H=$v;;
      r_frame_rate) SRC_FPS=$(awk -F/ -v r="$v" 'BEGIN{ split(r,a,"/"); if (a[2]>0) printf "%.2f", a[1]/a[2]; else print a[1] }');;
      bit_rate)     [[ \( v =\~ ^[0-9]+ \) ]] && SRC_VBR=$(( v / 1000 ));;
    esac
  done < <(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate,bit_rate -of default=nw=1 "$f" 2>/dev/null)
  [[ -n $SRC_VCODEC ]] || { err "No video stream: $(basename -- "$f")"; return 1; }
  while IFS='=' read -r k v; do
    case $k in
      codec_name) SRC_ACODEC=$v;;
      bit_rate)   [[ \( v =\~ ^[0-9]+ \) ]] && SRC_ABR=$(( v / 1000 ));;
    esac
  done < <(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,bit_rate -of default=nw=1 "$f" 2>/dev/null)
  return 0
}

calc_edur() {
  IN_OPTS=()
  EDUR=$(awk -v d="\( DUR" -v s=" \){TRIM_START:-0}" -v e="${TRIM_END:-0}" \
    'BEGIN{ if (e>0 && e<d) d=e; d-=s; if (d<0) d=0; printf "%.3f", d }')
  awk -v d="$EDUR" 'BEGIN{ exit !(d>=0.2) }' || return 1
  if [[ -n $TRIM_START || -n \( TRIM_END ]]; then IN_OPTS=(-ss " \){TRIM_START:-0}" -t "$EDUR"); fi
  return 0
}

calc_bitrate() {
  local a=0
  case $AUDIO in aac) a=\( ABR;; copy) a= \){SRC_ABR:-128};; none) a=0;; esac
  awk -v mb="$TARGET_MB" -v d="$EDUR" -v a="$a" \
    'BEGIN{ v = mb*8000*0.97/d - a; if (v < 40) exit 1; printf "%d", v }'
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
  esac
  if (( FPS > 0 )) && awk -v s="$SRC_FPS" -v t="$FPS" 'BEGIN{ exit !(s > t+0.5) }'; then
    f+=("fps=$FPS")
  fi
  (IFS=,; printf '%s' "${f[*]}")
}
build_venc() {
  local pass=$1 br=$2 xp="log-level=error"
  VENC=()
  case $CODEC in
    x265)
      VENC+=(-c:v libx265 -preset "$SPEED" -tag:v hvc1 -pix_fmt yuv420p)
      if [[ -n \( br ]]; then VENC+=(-b:v " \){br}k"); else VENC+=(-crf "$CRF"); fi
      case $pass in
        p1) xp+=":pass=1:stats=$TMPD/x265.stats";;
        p2) xp+=":pass=2:stats=$TMPD/x265.stats";;
      esac
      VENC+=(-x265-params "$xp");;
    x264)
      VENC+=(-c:v libx264 -preset "$SPEED" -pix_fmt yuv420p)
      if [[ -n \( br ]]; then VENC+=(-b:v " \){br}k"); else VENC+=(-crf "$CRF"); fi
      case $pass in
        p1) VENC+=(-pass 1 -passlogfile "$TMPD/x264");;
        p2) VENC+=(-pass 2 -passlogfile "$TMPD/x264");;
      esac;;
    hw265) VENC+=(-c:v hevc_mediacodec -b:v "${br:-$VBR}k" -tag:v hvc1);;
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
run_ffmpeg() {
  local label=$1 pi=$2 pt=$3 rc cols w
  shift 3
  cols=\( (term_cols); w= \)(( cols - 34 )); (( w < 8 )) && w=8; (( w > 28 )) && w=28
  ffmpeg -nostdin -hide_banner -loglevel error -progress pipe:1 -nostats -y "$@" 2>>"$LOG" |
  {
    cur=0; spd=""
    while IFS='=' read -r key val; do
      case $key in
        out_time_us|out_time_ms) [[ \( val =\~ ^[0-9]+ \) ]] && cur=$val;;
        speed) spd=${val//[x ]/}; [[ \( spd =\~ ^[0-9.]+ \) ]] || spd="";;
        progress)
          read -r pct eta < <(awk -v c="$cur" -v d="$EDUR" -v pi="$pi" -v pt="$pt" -v s="$spd" 'BEGIN{
              p = c/1e6/d; if (p > 1) p = 1; if (p < 0) p = 0;
              pct = int(((pi-1) + p) / pt * 100);
              if (s+0 > 0) { r = ((1-p) + (pt-pi)) * d / s;
                printf "%d %02d:%02d:%02d\n", pct, r/3600, (r%3600)/60, r%60 }
              else printf "%d --:--:--\n", pct }')
          filled=$(( pct * w / 100 ))
          printf -v b1 '%*s' "\( filled" ''; printf -v b2 '%*s' " \)(( w - filled ))" ''
          sp=\( {spd:+ \){spd}x}
          printf '\r\033[K%s[%s%s] %3d%% %s ETA %s' "${label:+\( label }" " \){b1// /#}" "${b2// /.}" "\( pct" " \){sp:---}" "$eta"
          ;;
      esac
    done
  }
  rc=${PIPESTATUS[0]}
  printf '\r\033[K'
  return "$rc"
}

# -------------------------------------------------------------- file naming ---
unique_out() {
  local src=$1 dir base out n=0
  dir=\( {OUTDIR:- \)(dirname -- "$src")}
  mkdir -p -- "$dir" 2>/dev/null
  base=$(basename -- "\( src"); base= \){base%.*}
  out="\( dir/ \){base}${SUFFIX}.mp4"
  while [[ -e \( out ]]; do n= \)(( n + 1 )); out="\( dir/ \){base}${SUFFIX}_$n.mp4"; done
  printf '%s' "$out"
}
add_result() { RESULTS+=("\( (printf '%s\t%s\t%s\t%s\t%s\t%s' " \)@")"); }

# ------------------------------------------------------- compress one file ---
compress_file() {
  local src=$1 name dst tmp in_sz out_sz saved passes=1 br="" vf rc=0 odur status t0=$SECONDS
  name=$(basename -- "$src")
  if ! probe "$src"; then
    add_result "\( name" "-" "-" "-" "-" "FAILED (unreadable)"; N_FAIL= \)(( N_FAIL + 1 )); return 1
  fi
  in_sz=$(fsize "$src")
  if ! calc_edur; then
    err "Trim range is outside the video."
    add_result "\( name" " \)(human "\( in_sz")" "-" "-" "-" "FAILED (trim)"; N_FAIL= \)(( N_FAIL + 1 )); return 1
  fi
  printf '  %s%sx%s %s %s fps | %s | %s%s\n' "$C_D" "$SRC_W" "$SRC_H" "$SRC_VCODEC" "$SRC_FPS" \
    "$(fmt_time "\( EDUR")" " \)(human "$in_sz")" "$C_0"

  if (( TARGET_MB > 0 )); then
    if (( in_sz <= TARGET_MB * 1000000 )) && [[ -z $TRIM_START$TRIM_END ]]; then
      warn "Already under ${TARGET_MB} MB - skipped."
      add_result "\( name" " \)(human "$in_sz")" "-" "-" "-" "SKIPPED (under target)"; return 0
    fi
    if ! br=$(calc_bitrate); then
      err "Target ${TARGET_MB} MB is too small for a video this long."
      add_result "\( name" " \)(human "\( in_sz")" "-" "-" "-" "FAILED (target too small)"; N_FAIL= \)(( N_FAIL + 1 )); return 1
    fi
    passes=2
  fi

  dst=$(unique_out "$src")
  TMPD=$(mktemp -d) || { err "Cannot create temp dir"; return 1; }
  CUR_TMP="$TMPD"
  : > "$LOG"
  vf=$(build_vf); VFARG=(); [[ -n $vf ]] && VFARG=(-vf "$vf")
  build_aenc

  if (( passes == 2 )); then
    build_venc p1 "$br"
    info "Pass 1/2 ..."
    run_ffmpeg "P1" 1 2 "${IN_OPTS[@]}" -i "\( src" -map 0:v:0 -map '0:a?' " \){VFARG[@]}" "${VENC[@]}" -an -f null /dev/null
    rc=$?
    if (( rc == 0 )); then
      build_venc p2 "$br"
      info "Pass 2/2 ..."
      run_ffmpeg "P2" 2 2 "${IN_OPTS[@]}" -i "\( src" -map 0:v:0 -map '0:a?' " \){VFARG[@]}" "\( {VENC[@]}" " \){AENC[@]}" -movflags +faststart "$dst"
      rc=$?
    fi
  else
    build_venc single "$br"
    run_ffmpeg "" 1 1 "${IN_OPTS[@]}" -i "\( src" -map 0:v:0 -map '0:a?' " \){VFARG[@]}" "\( {VENC[@]}" " \){AENC[@]}" -movflags +faststart "$dst"
    rc=$?
  fi

  if (( rc != 0 )) || [[ ! -s $dst ]]; then
    err "Encoding failed for $name"
    [[ -f $dst ]] && rm -f -- "$dst"
    add_result "\( name" " \)(human "\( in_sz")" "-" "-" " \)(fmt_time $(( SECONDS - t0 )))" "FAILED"
    N_FAIL=$(( N_FAIL + 1 ))
    rm -rf "$TMPD"; CUR_TMP=""; return 1
  fi

  out_sz=$(fsize "$dst")
  saved=$(awk -v i="$in_sz" -v o="$out_sz" 'BEGIN{ if(i>0) printf "%.0f%%", (i-o)*100/i; else print "-" }')
  status="OK"
  if (( DELETE_ORIG )); then
    rm -f -- "$src" && status="OK (orig deleted)" || status="OK (could not delete orig)"
  fi
  add_result "\( name" " \)(human "\( in_sz")" " \)(human "\( out_sz")" " \){saved}" "$(fmt_time $(( SECONDS - t0 )))" "$status"
  N_OK=$(( N_OK + 1 ))
  TOTAL_IN=$(( TOTAL_IN + in_sz ))
  TOTAL_OUT=$(( TOTAL_OUT + out_sz ))
  ok "$name → $(human "$out_sz") ($saved)"
  rm -rf "$TMPD"; CUR_TMP=""
  return 0
}

wake_lock() {
  if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock; WAKE=1
  fi
}
wake_unlock() { if (( WAKE )) && command -v termux-wake-unlock >/dev/null 2>&1; then termux-wake-unlock; WAKE=0; fi; }
notify() {
  if command -v termux-notification >/dev/null 2>&1; then
    termux-notification --title "VidCompress" --content "$*" --id vc 2>/dev/null || true
  fi
}

print_summary() {
  echo
  printf '%s========== Summary ==========%s\n' "$C_B" "$C_0"
  printf ' Success : %d    Failed : %d\n' "$N_OK" "$N_FAIL"
  if (( TOTAL_IN > 0 )); then
    printf ' Total in : %s\n' "$(human "$TOTAL_IN")"
    printf ' Total out: %s  (saved %s)\n' "$(human "$TOTAL_OUT")" \
      "$(awk -v i="$TOTAL_IN" -v o="$TOTAL_OUT" 'BEGIN{ printf "%.0f%%", (i-o)*100/i }')"
  fi
  echo
  if (( ${#RESULTS[@]} )); then
    printf '%-28s %9s %9s %6s %8s  %s\n' "File" "In" "Out" "Saved" "Time" "Status"
    printf '%s\n' "------------------------------------------------------------------------"
    local r
    for r in "${RESULTS[@]}"; do
      IFS=$'\t' read -r n i o s t st <<<"$r"
      printf '%-28s %9s %9s %6s %8s  %s\n' "$(trunc "$n")" "$i" "$o" "$s" "$t" "$st"
    done
  fi
}

run_batch() {
  local f
  N_OK=0; N_FAIL=0; TOTAL_IN=0; TOTAL_OUT=0; RESULTS=()
  wake_lock
  for f in "${SELECTED[@]}"; do
    echo
    info ">>> $(basename -- "$f")"
    compress_file "$f"
  done
  wake_unlock
  print_summary
  notify "Done: $N_OK ok, $N_FAIL failed"
}

estimate_size() {
  local src=$1 full br= vf tmp sz est sstart slen
  probe "$src" || return
  full=$DUR
  [[ -n $TRIM_START || -n $TRIM_END ]] && calc_edur && full=$EDUR
  if (( TARGET_MB > 0 )); then
    info "Target mode: \~${TARGET_MB} MB (exact size depends on content)"
    return
  fi
  [[ $CODEC == hw* ]] && br=$VBR
  slen=$(awk -v d="$full" 'BEGIN{ printf "%.1f", (d > 25) ? 20 : d }')
  sstart=$(awk -v d="\( full" -v t=" \){TRIM_START:-0}" 'BEGIN{ s=d/2-10; if (s<0) s=0; printf "%.1f", t+s }')
  info "Encoding a ${slen}s test sample from the middle of: $(basename -- "$src")"
  TMPD=$(mktemp -d) || return
  : > "$LOG"
  EDUR=$slen; tmp="$TMPD/sample.mp4"
  local vf; vf=$(build_vf); VFARG=(); [[ -n $vf ]] && VFARG=(-vf "$vf")
  build_aenc; build_venc single "$br"
  run_ffmpeg "" 1 1 -ss "$sstart" -t "$slen" -i "\( src" -map 0:v:0 -map '0:a?' " \){VFARG[@]}" "\( {VENC[@]}" " \){AENC[@]}" -f mp4 "$tmp"
  if [[ -s $tmp ]]; then
    sz=$(fsize "$tmp")
    est=$(awk -v s="$sz" -v f="$full" -v l="$slen" 'BEGIN{ printf "%d", s*f/l }')
    ok "Estimated output: \~$(human "$est")  (original: \( (human " \)(fsize "$src")"))  - rough, about +/-20%"
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
pick_from_dir() {
  local dir=$1 files=() ans toks tok lo hi n added f i
  mapfile -t files < <(list_videos "$dir" | head -n 60)
  if (( ${#files[@]} == 0 )); then warn "No videos in $(pretty "$dir")"; return 1; fi
  while true; do
    printf '\n%s%s%s  (newest first)\n' "\( C_B" " \)(pretty "$dir")" "$C_0"
    for i in "${!files[@]}"; do
      printf ' %2d) %8s  %s\n' \( (( i + 1 )) " \)(human "\( (fsize " \){files[i]}")")" "\( (trunc " \)(basename -- "${files[i]}")")"
    done
    echo "Numbers (e.g. 1 3 5-7), a = all, b = back"
    read -r -p "> " ans || return 1
    case ${ans,,} in
      b|"") return 1;;
      a) for f in "${files[@]}"; do add_sel "$f"; done; ok "Added ${#files[@]} video(s)."; return 0;;
    esac
    read -ra toks <<<"$ans"; added=0
    for tok in "${toks[@]}"; do
      if [[ \( tok =\~ ^[0-9]+ \) ]]; then lo=$tok; hi=$tok
      elif [[ \( tok =\~ ^([0-9]+)-([0-9]+) \) ]]; then lo=\( {BASH_REMATCH[1]}; hi= \){BASH_REMATCH[2]}
      else continue; fi
      for (( n = lo; n <= hi; n++ )); do
        if (( n >= 1 && n <= \( {#files[@]} )); then add_sel " \){files[n-1]}"; added=$(( added + 1 )); fi
      done
    done
    if (( added > 0 )); then ok "Added $added video(s)."; return 0; else warn "Nothing matched."; fi
  done
}
add_path() {
  local p=$1
  p=\( {p#[\'\"]}; p= \){p%[\'\"]}; p=${p/#\\~/$HOME}
  if [[ -d $p ]]; then pick_from_dir "$p"
  elif [[ -f $p ]]; then add_sel "$p"; ok "Added: $(basename -- "$p")"
  else err "Not found: $p"; fi
}
choose_videos() {
  local cands=() d ans s="$HOME/storage/shared"
  if [[ ! -d $HOME/storage ]]; then warn "No storage access yet. Run: termux-setup-storage  (or: vc --setup)"; fi
  for d in "$s/DCIM/Camera" "$s/Download" "$s/Movies" "$s/DCIM" "$s/Pictures/Screenshots" \
           "$s/Telegram/Telegram Video" "$s/Android/media/org.telegram.messenger/Telegram/Telegram Video" \
           "$s/Android/media/coal ac=2; (( ABR <= 48 )) && ac=1
          AENC=(-c:a aac -b:a "${ABR}k" -ac "$ac");;
  esac
}

# --------------------------------------------------- progress-bar runner -----
run_ffmpeg() {
  local label=$1 pi=$2 pt=$3 rc cols w
  shift 3
  cols=$(term_cols); w=$(( cols - 34 )); (( w < 8 )) && w=8; (( w > 28 )) && w=28
  ffmpeg -nostdin -hide_banner -loglevel error -progress pipe:1 -nostats -y "$@" 2>>"$LOG" |
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
unique_out() {
  local src=$1 dir base out n=0
  dir=${OUTDIR:-$(dirname -- "$src")}
  mkdir -p -- "$dir" 2>/dev/null
  base=$(basename -- "$src"); base=${base%.*}
  out="$dir/${base}${SUFFIX}.mp4"
  while [[ -e $out ]]; do n=$(( n + 1 )); out="$dir/${base}${SUFFIX}_$n.mp4"; done
  printf '%s' "$out"
}
add_result() { RESULTS+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$@")"); }

# ------------------------------------------------------- compress one file ---
compress_file() {
  local src=$1 name dst tmp in_sz out_sz saved passes=1 br="" vf rc=0 odur status t0=$SECONDS
  name=$(basename -- "$src")
  if ! probe "$src"; then
    add_result "$name" "-" "-" "-" "-" "FAILED (unreadable)"; N_FAIL=$(( N_FAIL + 1 )); return 1
  fi
  in_sz=$(fsize "$src")
  if ! calc_edur; then
    err "Trim range is outside the video."
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (trim)"; N_FAIL=$(( N_FAIL + 1 )); return 1
  fi
  printf '  %s%sx%s %s %s fps | %s | %s%s\n' "$C_D" "$SRC_W" "$SRC_H" "$SRC_VCODEC" "$SRC_FPS" \
    "$(fmt_time "$EDUR")" "$(human "$in_sz")" "$C_0"

  if (( TARGET_MB > 0 )); then
    if (( in_sz <= TARGET_MB * 1000000 )) && [[ -z $TRIM_START$TRIM_END ]]; then
      warn "Already under ${TARGET_MB} MB - skipped."
      add_result "$name" "$(human "$in_sz")" "-" "-" "-" "SKIPPED (under target)"; return 0
    fi
    if ! br=$(calc_bitrate); then
      err "Target ${TARGET_MB} MB is too small for a video this long."
      add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (target too small)"; N_FAIL=$(( N_FAIL + 1 )); return 1
    fi
    echo "  Video bitrate: ${br} kbps"
  elif [[ $CODEC == hw* ]]; then
    br=$VBR
  fi
  [[ -n $br && $CODEC == x* ]] && passes=2

  TMPD=$(mktemp -d) || { err "Cannot create temp dir."; return 1; }
  dst=$(unique_out "$src"); tmp="$dst.part"; CUR_TMP=$tmp
  vf=$(build_vf); VFARG=(); [[ -n $vf ]] && VFARG=(-vf "$vf")
  build_aenc
  META=(); (( STRIP_META )) && META=(-map_metadata -1 -map_chapters -1)

  if (( passes == 2 )); then
    build_venc p1 "$br"
    run_ffmpeg "pass 1/2" 1 2 "${IN_OPTS[@]}" -i "$src" -map 0:v:0 "${VFARG[@]}" "${VENC[@]}" -an -f null /dev/null
    rc=$?
    if (( rc == 0 )); then
      build_venc p2 "$br"
      run_ffmpeg "pass 2/2" 2 2 "${IN_OPTS[@]}" -i "$src" -map 0:v:0 -map '0:a?' "${VFARG[@]}" "${VENC[@]}" \
        "${AENC[@]}" "${META[@]}" -movflags +faststart -f mp4 "$tmp"
      rc=$?
    fi
  else
    build_venc single "$br"
    run_ffmpeg "" 1 1 "${IN_OPTS[@]}" -i "$src" -map 0:v:0 -map '0:a?' "${VFARG[@]}" "${VENC[@]}" \
      "${AENC[@]}" "${META[@]}" -movflags +faststart -f mp4 "$tmp"
    rc=$?
  fi
  rm -rf "$TMPD"; TMPD=""

  if (( rc != 0 )) || [[ ! -s $tmp ]]; then
    err "ffmpeg failed (exit $rc). Last log lines:"
    tail -n 6 "$LOG" | sed 's/^/    /' >&2
    rm -f -- "$tmp"; CUR_TMP=""
    add_result "$name" "$(human "$in_sz")" "-" "-" "$(fmt_time $(( SECONDS - t0 )))" "FAILED"
    N_FAIL=$(( N_FAIL + 1 )); return 1
  fi
  mv -f -- "$tmp" "$dst"; CUR_TMP=""

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
  if (( DELETE_ORIG )) && [[ $status == OK && -z $TRIM_START$TRIM_END ]]; then
    rm -f -- "$src" && ok "Original deleted."
  fi
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$dst" >/dev/null 2>&1 & }
  N_OK=$(( N_OK + 1 )); TOTAL_IN=$(( TOTAL_IN + in_sz )); TOTAL_OUT=$(( TOTAL_OUT + out_sz ))
  add_result "$name" "$(human "$in_sz")" "$(human "$out_sz")" "${saved}" "$(fmt_time $(( SECONDS - t0 )))" "$status"
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

print_summary() {
  local r name old new pct tm st
  printf '\n%s== Summary ==%s\n' "$C_B" "$C_0"
  for r in "${RESULTS[@]}"; do
    IFS=$'\t' read -r name old new pct tm st <<<"$r"
    printf '%s\n    %s -> %s  %s  [%s]  %s\n' "$(trunc "$name")" "$old" "$new" "$pct" "$tm" "$st"
  done
  if (( N_OK > 0 )); then
    printf '\n%sTotal:%s %s -> %s  (saved %s)\n' "$C_B" "$C_0" "$(human "$TOTAL_IN")" "$(human "$TOTAL_OUT")" \
      "$(human $(( TOTAL_IN - TOTAL_OUT )))"
  fi
  printf 'Done: %d ok, %d failed.  Log: %s\n' "$N_OK" "$N_FAIL" "$(pretty "$LOG")"
}

run_batch() {
  (( ${#SELECTED[@]} )) || { err "No videos selected."; return 1; }
  if [[ $CODEC == hw* ]] && ! have_enc "$(hw_encoder_name)"; then
    err "Hardware encoder '$(hw_encoder_name)' is not available in this ffmpeg build."
    err "Pick x265 or x264 instead (Settings > 1)."
    return 1
  fi
  mkdir -p "$CONF_DIR"; : > "$LOG"
  RESULTS=(); N_OK=0; N_FAIL=0; TOTAL_IN=0; TOTAL_OUT=0
  wake_lock
  local i=0 n=${#SELECTED[@]} f
  for f in "${SELECTED[@]}"; do
    i=$(( i + 1 ))
    printf '\n%s[%d/%d] %s%s\n' "$C_B" "$i" "$n" "$(trunc "$(basename -- "$f")")" "$C_0"
    compress_file "$f"
  done
  wake_unlock
  print_summary
  notify "Finished: $N_OK ok, $N_FAIL failed"
  (( N_FAIL == 0 ))
}

# ------------------------------------------------------ size estimate (test) ---
estimate_size() {
  (( ${#SELECTED[@]} )) || { warn "Select a video first."; return; }
  local src=${SELECTED[0]} slen sstart full tmp sz est br=""
  probe "$src" || return
  calc_edur || { err "Trim range is outside the video."; return; }
  full=$EDUR
  if (( TARGET_MB > 0 )); then info "Target-size mode: output will be about ${TARGET_MB} MB."; return; fi
  [[ $CODEC == hw* ]] && br=$VBR
  slen=$(awk -v d="$full" 'BEGIN{ printf "%.1f", (d > 25) ? 20 : d }')
  sstart=$(awk -v d="$full" -v t="${TRIM_START:-0}" 'BEGIN{ s=d/2-10; if (s<0) s=0; printf "%.1f", t+s }')
  info "Encoding a ${slen}s test sample from the middle of: $(basename -- "$src")"
  TMPD=$(mktemp -d) || return
  : > "$LOG"
  EDUR=$slen; tmp="$TMPD/sample.mp4"
  local vf; vf=$(build_vf); VFARG=(); [[ -n $vf ]] && VFARG=(-vf "$vf")
  build_aenc; build_venc single "$br"
  run_ffmpeg "" 1 1 -ss "$sstart" -t "$slen" -i "$src" -map 0:v:0 -map '0:a?' "${VFARG[@]}" "${VENC[@]}" "${AENC[@]}" -f mp4 "$tmp"
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
      a) for f in "${files[@]}"; do add_  VENC+=(-x265-params "$xp");;
    x264)
      VENC+=(-c:v libx264 -preset "$SPEED" -pix_fmt yuv420p)
      if [[ -n $br ]]; then VENC+=(-b:v "${br}k"); else VENC+=(-crf "$CRF"); fi
      case $pass in
        p1) VENC+=(-pass 1 -passlogfile "$TMPD/x264");;
        p2) VENC+=(-pass 2 -passlogfile "$TMPD/x264");;
      esac;;
    hw265) VENC+=(-c:v hevc_mediacodec -b:v "${br:-$VBR}k" -tag:v hvc1);;
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
  cols=$(term_cols); w=$(( cols - 34 )); (( w < 8 )) && w=8; (( w > 28 )) && w=28
  ffmpeg -nostdin -hide_banner -loglevel error -progress pipe:1 -nostats -y "$@" 2>>"$LOG" |
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
unique_out() {
  local src=$1 dir base out n=0
  dir=${OUTDIR:-$(dirname -- "$src")}
  mkdir -p -- "$dir" 2>/dev/null
  base=$(basename -- "$src"); base=${base%.*}
  out="$dir/${base}${SUFFIX}.mp4"
  while [[ -e $out ]]; do n=$(( n + 1 )); out="$dir/${base}${SUFFIX}_$n.mp4"; done
  printf '%s' "$out"
}
add_result() { RESULTS+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$@")"); }

# ------------------------------------------------------- compress one file ---
compress_file() {
  local src=$1 name dst tmp in_sz out_sz saved passes=1 br="" vf rc=0 odur status t0=$SECONDS
  name=$(basename -- "$src")
  if ! probe "$src"; then
    add_result "$name" "-" "-" "-" "-" "FAILED (unreadable)"; N_FAIL=$(( N_FAIL + 1 )); return 1
  fi
  in_sz=$(fsize "$src")
  if ! calc_edur; then
    err "Trim range is outside the video."
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (trim)"; N_FAIL=$(( N_FAIL + 1 )); return 1
  fi
  printf '  %s%sx%s %s %s fps | %s | %s%s\n' "$C_D" "$SRC_W" "$SRC_H" "$SRC_VCODEC" "$SRC_FPS" \
    "$(fmt_time "$EDUR")" "$(human "$in_sz")" "$C_0"

  if (( TARGET_MB > 0 )); then
    if (( in_sz <= TARGET_MB * 1000000 )) && [[ -z $TRIM_START$TRIM_END ]]; then
      warn "Already under ${TARGET_MB} MB - skipped."
      add_result "$name" "$(human "$in_sz")" "-" "-" "-" "SKIPPED (under target)"; return 0
    fi
    if ! br=$(calc_bitrate); then
      err "Target ${TARGET_MB} MB is too small for a video this long."
      add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (target too small)"; N_FAIL=$(( N_FAIL + 1 )); return 1
    fi
    echo "  Video bitrate: ${br} kbps"
  elif [[ $CODEC == hw* ]]; then
    br=$VBR
  fi
  [[ -n $br && $CODEC == x* ]] && passes=2

  TMPD=$(mktemp -d) || { err "Cannot create temp dir."; return 1; }
  dst=$(unique_out "$src"); tmp="$dst.part"; CUR_TMP=$tmp
  vf=$(build_vf); VFARG=(); [[ -n $vf ]] && VFARG=(-vf "$vf")
  build_aenc
  META=(); (( STRIP_META )) && META=(-map_metadata -1 -map_chapters -1)

  if (( passes == 2 )); then
    build_venc p1 "$br"
    run_ffmpeg "pass 1/2" 1 2 "${IN_OPTS[@]}" -i "$src" -map 0:v:0 "${VFARG[@]}" "${VENC[@]}" -an -f null /dev/null
    rc=$?
    if (( rc == 0 )); then
      build_venc p2 "$br"
      run_ffmpeg "pass 2/2" 2 2 "${IN_OPTS[@]}" -i "$src" -map 0:v:0 -map '0:a?' "${VFARG[@]}" "${VENC[@]}" \
        "${AENC[@]}" "${META[@]}" -movflags +faststart -f mp4 "$tmp"
      rc=$?
    fi
  else
    build_venc single "$br"
    run_ffmpeg "" 1 1 "${IN_OPTS[@]}" -i "$src" -map 0:v:0 -map '0:a?' "${VFARG[@]}" "${VENC[@]}" \
      "${AENC[@]}" "${META[@]}" -movflags +faststart -f mp4 "$tmp"
    rc=$?
  fi
  rm -rf "$TMPD"; TMPD=""

  if (( rc != 0 )) || [[ ! -s $tmp ]]; then
    err "ffmpeg failed (exit $rc). Last log lines:"
    tail -n 6 "$LOG" | sed 's/^/    /' >&2
    rm -f -- "$tmp"; CUR_TMP=""
    add_result "$name" "$(human "$in_sz")" "-" "-" "$(fmt_time $(( SECONDS - t0 )))" "FAILED"
    N_FAIL=$(( N_FAIL + 1 )); return 1
  fi
  mv -f -- "$tmp" "$dst"; CUR_TMP=""

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
  if (( DELETE_ORIG )) && [[ $status == OK && -z $TRIM_START$TRIM_END ]]; then
    rm -f -- "$src" && ok "Original deleted."
  fi
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$dst" >/dev/null 2>&1 & }
  N_OK=$(( N_OK + 1 )); TOTAL_IN=$(( TOTAL_IN + in_sz )); TOTAL_OUT=$(( TOTAL_OUT + out_sz ))
  add_result "$name" "$(human "$in_sz")" "$(human "$out_sz")" "${saved}" "$(fmt_time $(( SECONDS - t0 )))" "$status"
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

print_summary() {
  local r name old new pct tm st
  printf '\n%s== Summary ==%s\n' "$C_B" "$C_0"
  for r in "${RESULTS[@]}"; do
    IFS=$'\t' read -r name old new pct tm st <<<"$r"
    printf '%s\n    %s -> %s  %s  [%s]  %s\n' "$(trunc "$name")" "$old" "$new" "$pct" "$tm" "$st"
  done
  if (( N_OK > 0 )); then
    printf '\n%sTotal:%s %s -> %s  (saved %s)\n' "$C_B" "$C_0" "$(human "$TOTAL_IN")" "$(human "$TOTAL_OUT")" \
      "$(human $(( TOTAL_IN - TOTAL_OUT )))"
  fi
  printf 'Done: %d ok, %d failed.  Log: %s\n' "$N_OK" "$N_FAIL" "$(pretty "$LOG")"
}

run_batch() {
  (( ${#SELECTED[@]} )) || { err "No videos selected."; return 1; }
  if [[ $CODEC == hw* ]] && ! have_enc "$(hw_encoder_name)"; then
    err "Hardware encoder '$(hw_encoder_name)' is not available in this ffmpeg build."
    err "Pick x265 or x264 instead (Settings > 1)."
    return 1
  fi
  mkdir -p "$CONF_DIR"; : > "$LOG"
  RESULTS=(); N_OK=0; N_FAIL=0; TOTAL_IN=0; TOTAL_OUT=0
  wake_lock
  local i=0 n=${#SELECTED[@]} f
  for f in "${SELECTED[@]}"; do
    i=$(( i + 1 ))
    printf '\n%s[%d/%d] %s%s\n' "$C_B" "$i" "$n" "$(trunc "$(basename -- "$f")")" "$C_0"
    compress_file "$f"
  done
  wake_unlock
  print_summary
  notify "Finished: $N_OK ok, $N_FAIL failed"
  (( N_FAIL == 0 ))
}

# ------------------------------------------------------ size estimate (test) ---
estimate_size() {
  (( ${#SELECTED[@]} )) || { warn "Select a video first."; return; }
  local src=${SELECTED[0]} slen sstart full tmp sz est br=""
  probe "$src" || return
  calc_edur || { err "Trim range is outside the video."; return; }
  full=$EDUR
  if (( TARGET_MB > 0 )); then info "Target-size mode: output will be about ${TARGET_MB} MB."; return; fi
  [[ $CODEC == hw* ]] && br=$VBR
  slen=$(awk -v d="$full" 'BEGIN{ printf "%.1f", (d > 25) ? 20 : d }')
  sstart=$(awk -v d="$full" -v t="${TRIM_START:-0}" 'BEGIN{ s=d/2-10; if (s<0) s=0; printf "%.1f", t+s }')
  info "Encoding a ${slen}s test sample from the middle of: $(basename -- "$src")"
  TMPD=$(mktemp -d) || return
  : > "$LOG"
  EDUR=$slen; tmp="$TMPD/sample.mp4"
  local vf; vf=$(build_vf); VFARG=(); [[ -n $vf ]] && VFARG=(-vf "$vf")
  build_aenc; build_venc single "$br"
  run_ffmpeg "" 1 1 -ss "$sstart" -t "$slen" -i "$src" -map 0:v:0 -map '0:a?' "${VFARG[@]}" "${VENC[@]}" "${AENC[@]}" -f mp4 "$tmp"
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
pick_from_dir(v "${br}k"); else VENC+=(-crf "$CRF"); fi
      case $pass in
        p1) VENC+=(-pass 1 -passlogfile "$TMPD/x264");;
        p2) VENC+=(-pass 2 -passlogfile "$TMPD/x264");;
      esac;;
    hw265) VENC+=(-c:v hevc_mediacodec -b:v "${br:-$VBR}k" -tag:v hvc1);;
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
  cols=$(term_cols); w=$(( cols - 34 )); (( w < 8 )) && w=8; (( w > 28 )) && w=28
  ffmpeg -nostdin -hide_banner -loglevel error -progress pipe:1 -nostats -y "$@" 2>>"$LOG" |
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
unique_out() {
  local src=$1 dir base out n=0
  dir=${OUTDIR:-$(dirname -- "$src")}
  mkdir -p -- "$dir" 2>/dev/null
  base=$(basename -- "$src"); base=${base%.*}
  out="$dir/${base}${SUFFIX}.mp4"
  while [[ -e $out ]]; do n=$(( n + 1 )); out="$dir/${base}${SUFFIX}_$n.mp4"; done
  printf '%s' "$out"
}
add_result() { RESULTS+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$@")"); }

# ------------------------------------------------------- compress one file ---
compress_file() {
  local src=$1 name dst tmp in_sz out_sz saved passes=1 br="" vf rc=0 odur status t0=$SECONDS
  name=$(basename -- "$src")
  if ! probe "$src"; then
    add_result "$name" "-" "-" "-" "-" "FAILED (unreadable)"; N_FAIL=$(( N_FAIL + 1 )); return 1
  fi
  in_sz=$(fsize "$src")
  if ! calc_edur; then
    err "Trim range is outside the video."
    add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (trim)"; N_FAIL=$(( N_FAIL + 1 )); return 1
  fi
  printf '  %s%sx%s %s %s fps | %s | %s%s\n' "$C_D" "$SRC_W" "$SRC_H" "$SRC_VCODEC" "$SRC_FPS" \
    "$(fmt_time "$EDUR")" "$(human "$in_sz")" "$C_0"

  if (( TARGET_MB > 0 )); then
    if (( in_sz <= TARGET_MB * 1000000 )) && [[ -z $TRIM_START$TRIM_END ]]; then
      warn "Already under ${TARGET_MB} MB - skipped."
      add_result "$name" "$(human "$in_sz")" "-" "-" "-" "SKIPPED (under target)"; return 0
    fi
    if ! br=$(calc_bitrate); then
      err "Target ${TARGET_MB} MB is too small for a video this long."
      add_result "$name" "$(human "$in_sz")" "-" "-" "-" "FAILED (target too small)"; N_FAIL=$(( N_FAIL + 1 )); return 1
    fi
    echo "  Video bitrate: ${br} kbps"
  elif [[ $CODEC == hw* ]]; then
    br=$VBR
  fi
  [[ -n $br && $CODEC == x* ]] && passes=2

  TMPD=$(mktemp -d) || { err "Cannot create temp dir."; return 1; }
  dst=$(unique_out "$src"); tmp="$dst.part"; CUR_TMP=$tmp
  vf=$(build_vf); VFARG=(); [[ -n $vf ]] && VFARG=(-vf "$vf")
  build_aenc
  META=(); (( STRIP_META )) && META=(-map_metadata -1 -map_chapters -1)

  if (( passes == 2 )); then
    build_venc p1 "$br"
    run_ffmpeg "pass 1/2" 1 2 "${IN_OPTS[@]}" -i "$src" -map 0:v:0 "${VFARG[@]}" "${VENC[@]}" -an -f null /dev/null
    rc=$?
    if (( rc == 0 )); then
      build_venc p2 "$br"
      run_ffmpeg "pass 2/2" 2 2 "${IN_OPTS[@]}" -i "$src" -map 0:v:0 -map '0:a?' "${VFARG[@]}" "${VENC[@]}" \
        "${AENC[@]}" "${META[@]}" -movflags +faststart -f mp4 "$tmp"
      rc=$?
    fi
  else
    build_venc single "$br"
    run_ffmpeg "" 1 1 "${IN_OPTS[@]}" -i "$src" -map 0:v:0 -map '0:a?' "${VFARG[@]}" "${VENC[@]}" \
      "${AENC[@]}" "${META[@]}" -movflags +faststart -f mp4 "$tmp"
    rc=$?
  fi
  rm -rf "$TMPD"; TMPD=""

  if (( rc != 0 )) || [[ ! -s $tmp ]]; then
    err "ffmpeg failed (exit $rc). Last log lines:"
    tail -n 6 "$LOG" | sed 's/^/    /' >&2
    rm -f -- "$tmp"; CUR_TMP=""
    add_result "$name" "$(human "$in_sz")" "-" "-" "$(fmt_time $(( SECONDS - t0 )))" "FAILED"
    N_FAIL=$(( N_FAIL + 1 )); return 1
  fi
  mv -f -- "$tmp" "$dst"; CUR_TMP=""

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
  if (( DELETE_ORIG )) && [[ $status == OK && -z $TRIM_START$TRIM_END ]]; then
    rm -f -- "$src" && ok "Original deleted."
  fi
  command -v termux-media-scan >/dev/null 2>&1 && { timeout 10 termux-media-scan "$dst" >/dev/null 2>&1 & }
  N_OK=$(( N_OK + 1 )); TOTAL_IN=$(( TOTAL_IN + in_sz )); TOTAL_OUT=$(( TOTAL_OUT + out_sz ))
  add_result "$name" "$(human "$in_sz")" "$(human "$out_sz")" "${saved}" "$(fmt_time $(( SECONDS - t0 )))" "$status"
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

print_summary() {
  local r name old new pct tm st
  printf '\n%s== Summary ==%s\n' "$C_B" "$C_0"
  for r in "${RESULTS[@]}"; do
    IFS=$'\t' read -r name old new pct tm st <<<"$r"
    printf '%s\n    %s -> %s  %s  [%s]  %s\n' "$(trunc "$name")" "$old" "$new" "$pct" "$tm" "$st"
  done
  if (( N_OK > 0 )); then
    printf '\n%sTotal:%s %s -> %s  (saved %s)\n' "$C_B" "$C_0" "$(human "$TOTAL_IN")" "$(human "$TOTAL_OUT")" \
      "$(human $(( TOTAL_IN - TOTAL_OUT )))"
  fi
  printf 'Done: %d ok, %d failed.  Log: %s\n' "$N_OK" "$N_FAIL" "$(pretty "$LOG")"
}

run_batch() {
  (( ${#SELECTED[@]} )) || { err "No videos selected."; return 1; }
  if [[ $CODEC == hw* ]] && ! have_enc "$(hw_encoder_name)"; then
    err "Hardware encoder '$(hw_encoder_name)' is not available in this ffmpeg build."
    err "Pick x265 or x264 instead (Settings > 1)."
    return 1
  fi
  mkdir -p "$CONF_DIR"; : > "$LOG"
  RESULTS=(); N_OK=0; N_FAIL=0; TOTAL_IN=0; TOTAL_OUT=0
  wake_lock
  local i=0 n=${#SELECTED[@]} f
  for f in "${SELECTED[@]}"; do
    i=$(( i + 1 ))
    printf '\n%s[%d/%d] %s%s\n' "$C_B" "$i" "$n" "$(trunc "$(basename -- "$f")")" "$C_0"
    compress_file "$f"
  done
  wake_unlock
  print_summary
  notify "Finished: $N_OK ok, $N_FAIL failed"
  (( N_FAIL == 0 ))
}

# ------------------------------------------------------ size estimate (test) ---
estimate_size() {
  (( ${#SELECTED[@]} )) || { warn "Select a video first."; return; }
  local src=${SELECTED[0]} slen sstart full tmp sz est br=""
  probe "$src" || return
  calc_edur || { err "Trim range is outside the video."; return; }
  full=$EDUR
  if (( TARGET_MB > 0 )); then info "Target-size mode: output will be about ${TARGET_MB} MB."; return; fi
  [[ $CODEC == hw* ]] && br=$VBR
  slen=$(awk -v d="$full" 'BEGIN{ printf "%.1f", (d > 25) ? 20 : d }')
  sstart=$(awk -v d="$full" -v t="${TRIM_START:-0}" 'BEGIN{ s=d/2-10; if (s<0) s=0; printf "%.1f", t+s }')
  info "Encoding a ${slen}s test sample from the middle of: $(basename -- "$src")"
  TMPD=$(mktemp -d) || return
  : > "$LOG"
  EDUR=$slen; tmp="$TMPD/sample.mp4"
  local vf; vf=$(build_vf); VFARG=(); [[ -n $vf ]] && VFARG=(-vf "$vf")
  build_aenc; build_venc single "$br"
  run_ffmpeg "" 1 1 -ss "$sstart" -t "$slen" -i "$src" -map 0:v:0 -map '0:a?' "${VFARG[@]}" "${VENC[@]}" "${AENC[@]}" -f mp4 "$tmp"
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
add_path() {
  local p=$1
  p=${p#[\'\"]}; p=${p%[\'\"]}; p=${p/#\~/$HOME}
  if [[ -d $p ]]; then pick_from_dir "$p"
  elif [[ -f $p ]]; then add_sel "$p"; ok "Added: $(basename -- "$p")"
  else err "Not found: $p"; fi
}
choose_videos() {
  local cands=() d ans s="$HOME/storage/shared"
  if [[ ! -d $HOME/storage ]]; then warn "No storage access yet. Run: termux-setup-storage  (or: vc --setup)"; fi
  for d in "$s/DCIM/Camera" "$s/Download" "$s/Movies" "$s/DCIM" "$s/Pictures/Screenshots" \
           "$s/Telegram/Telegram Video" "$s/Android/media/org.telegram.messenger/Telegram/Telegram Video" \
           "$s/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video" "$s" "$PWD"; do
    [[ -d $d ]] && cands+=("$d")
  done
  while true; do
    printf '\n%sChoose a folder%s\n' "$C_B" "$C_0"
    local i
    for i in "${!cands[@]}"; do printf ' %2d) %s\n' $(( i + 1 )) "$(trunc "$(pretty "${cands[i]}")")"; done
    echo "  p) type/paste a path (file or folder)     b) back"
    read -r -p "> " ans || return
    case $ans in
      b|B|"") return;;
      p|P) ans=$(ask "Path" ""); [[ -n $ans ]] && add_path "$ans"; return;;
      *[!0-9]*) add_path "$ans"; return;;
      *) if (( ans >= 1 && ans <= ${#cands[@]} )); then pick_from_dir "${cands[ans-1]}" && return; fi;;
    esac
  done
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
  done
}
check_deps() {
  local c e
  echo
  for c in ffmpeg ffprobe awk; do
    if command -v "$c" >/dev/null 2>&1; then ok "$c found"; else err "$c missing"; fi
  done
  command -v ffmpeg >/dev/null 2>&1 && info "$(ffmpeg -version 2>/dev/null | head -n1)"
  for e in libx265 libx264 aac hevc_mediacodec h264_mediacodec; do
    if have_enc "$e"; then ok "encoder: $e"; else warn "encoder missing: $e"; fi
  done
  for c in termux-wake-lock termux-notification termux-media-scan; do
    if command -v "$c" >/dev/null 2>&1; then ok "optional: $c"; else info "optional (Termux:API): $c not available"; fi
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
  cp -f -- "${BASH_SOURCE[0]}" "$dest" && chmod +x "$dest" && ok "Installed. Run it with:  vc" || err "Install failed ($dest)"
}

# ---------------------------------------------------------------- settings ---
set_codec() {
  local c old=$CODEC
  echo " 1) x265  H.265/HEVC   - smallest files (default)"
  echo " 2) x264  H.264/AVC    - plays everywhere, ~40% bigger"
  echo " 3) hw265 hardware H.265 (MediaCodec) - fast, experimental"
  echo " 4) hw264 hardware H.264 (MediaCodec) - fast, experimental"
  c=$(ask "Choose" "")
  case $c in 1) CODEC=x265;; 2) CODEC=x264;; 3) CODEC=hw265;; 4) CODEC=hw264;; *) return;; esac
  if [[ $CODEC == hw* ]] && ! have_enc "$(hw_encoder_name)"; then
    warn "This ffmpeg build has no $(hw_encoder_name). Keeping $old."; CODEC=$old; return
  fi
  if   [[ $old == x265 && $CODEC == x264 ]]; then CRF=$(( CRF - 5 ))
  elif [[ $old == x264 && $CODEC == x265 ]]; then CRF=$(( CRF + 5 )); fi
  (( CRF < 0 )) && CRF=0; (( CRF > 51 )) && CRF=51
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
       else info "x265: 22 high / 26 balanced / 30 small   |   x264: 18 / 23 / 27"
            CRF=$(ask_int "CRF" 0 51 "$CRF"); fi;;
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
  echo " 1) off  2) light  3) medium   (denoise makes noisy/dark footage compress much smaller)"
  c=$(ask "Choose" "")
  case $c in 1) DENOISE=0;; 2) DENOISE=1;; 3) DENOISE=2;; *) return;; esac
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
    printf '\n  s) save as default     b) back\n'
    read -r -p "Edit: " c || exit 0
    case $c in
      1) set_codec;; 2) set_mode;; 3) set_res;; 4) set_fps;; 5) set_speed;; 6) set_audio;;
      7) set_denoise;; 8) set_trim;; 9) set_outdir;; 10) set_suffix;;
      11) STRIP_META=$(( 1 - STRIP_META ));;
      12) if (( DELETE_ORIG )); then DELETE_ORIG=0
          else warn "Originals will be DELETED after successful compression (not for trimmed clips)."
               yesno "Enable?" n && DELETE_ORIG=1; fi;;
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
    printf ' %d) %-9s %s\n' "$i" "$p" "$(trunc "$(preset_desc "$p")")"
  done
  echo
  c=$(ask "Choose (blank = back)" "")
  if [[ $c =~ ^[0-9]+$ ]] && (( c >= 1 && c <= ${#names[@]} )); then
    apply_preset "${names[c-1]}"; ok "Preset '${names[c-1]}' applied."
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
           if [[ -n $n ]]; then write_settings "$PROF_DIR/$n.conf"; ok "Saved profile '$n'."; sleep 1; else err "Invalid name."; fi;;
      d|D) n=$(ask "Number to delete" "")
           if [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#files[@]} )); then rm -f -- "$PROF_DIR/${files[n-1]}"; ok "Deleted."; fi;;
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
    echo " 3) Check installation / encoders"
    echo " 4) Setup (install ffmpeg, storage access)"
    echo " 5) Install 'vc' command"
    echo " 6) Show last log"
    echo " b) back"
    read -r -p "> " c || exit 0
    case $c in
      1) show_info; pause;;
      2) estimate_size; pause;;
      3) check_deps; pause;;
      4) do_setup; pause;;
      5) do_install; pause;;
      6) if [[ -s $LOG ]]; then tail -n 40 "$LOG"; else echo "(log is empty)"; fi; pause;;
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
  printf '  Denoise    : %s   Trim: %s\n' "$(denoise_label)" "$(trim_label)"
  printf '  Output     : %s%s.mp4\n' "$(out_label)/" "<name>$SUFFIX"
  (( DELETE_ORIG )) && printf '  %sOriginals will be deleted after success.%s\n' "$C_Y" "$C_0"
  echo
}
start_flow() {
  if (( ${#SELECTED[@]} == 0 )); then warn "Select at least one video first (option 1)."; pause; return; fi
  print_plan
  yesno "Start compression?" y || return
  run_batch
  pause
}
main_menu() {
  local c n tot f
  while true; do
    clear_screen
    n=${#SELECTED[@]}; tot=0
    for f in "${SELECTED[@]}"; do tot=$(( tot + $(fsize "$f") )); done
    printf '%sVidCompress v%s%s  -  ffmpeg video compressor\n' "$C_B" "$VERSION" "$C_0"
    printf '%s------------------------------------------%s\n' "$C_D" "$C_0"
    printf ' Selected : %d file(s), %s\n' "$n" "$(human "$tot")"
    printf ' Preset   : %s\n' "$PRESET_NAME"
    printf ' Plan     : %s\n\n' "$(trunc "$(plan_line)")"
    echo " 1) Choose videos"
    echo " 2) Choose preset"
    echo " 3) Advanced settings"
    echo " 4) Profiles (save / load)"
    echo " 5) Tools (info, estimate, setup)"
    echo " 6) START compression"
    echo " c) Clear selection"
    echo " 0) Quit"
    read -r -p "> " c || exit 0
    case $c in
      1) choose_videos;;
      2) preset_menu;;
      3) settings_menu;;
      4) profile_menu;;
      5) tools_menu;;
      6) start_flow;;
      c|C) SELECTED=();;
      0|q|Q) exit 0;;
    esac
  done
}

# --------------------------------------------------------------------- CLI ---
usage() {
  cat <<EOF
VidCompress v$VERSION - ffmpeg video compression toolkit for Termux

Usage:
  vc                          interactive menu
  vc [options] FILE|DIR ...   preload files/folders (menu opens unless -y)

Options:
  -p PRESET   balanced | quality | small | tiny | social | compat | fast | target | hardware
  -t MB       target size in MB (two-pass), e.g. -t 95
  -c CRF      constant quality (x265: 22-30, x264: 18-27; lower = better)
  -r PIXELS   max short side: 1080, 720, 480 ... (0 = keep original)
  -f FPS      max frame rate (0 = keep)
  -s SPEED    ultrafast ... medium ... veryslow
  -k CODEC    x265 | x264 | hw265 | hw264
  -a AUDIO    copy | none | <kbps>   e.g. -a 64
  -S TIME     trim start (90, 1:30, 0:01:30)
  -E TIME     trim end
  -o DIR      output folder (default: next to the source)
  -d          delete originals after verified success
  -y          start immediately, no menu
  -h          this help

Other commands:
  vc --setup      install ffmpeg and storage access
  vc --install    install this script as the 'vc' command
  vc --version

Examples:
  vc -y -p target -t 95 movie.mp4          # under 100 MB, 720p
  vc -y -p small -o ~/storage/movies/out ~/storage/dcim/Camera
  vc -y -k x264 -c 23 -r 0 -a copy clip.mov
EOF
}

cleanup() {
  [[ -n $TMPD ]] && rm -rf "$TMPD"
  wake_unlock
}
on_int() {
  printf '\n'; warn "Interrupted - cleaning up."
  [[ -n $CUR_TMP ]] && rm -f -- "$CUR_TMP"
  exit 130
}

main() {
  case ${1:-} in
    --setup)   do_setup; exit;;
    --install) do_install; exit;;
    --version) echo "VidCompress $VERSION"; exit;;
    --help)    usage; exit;;
  esac

  mkdir -p "$CONF_DIR" "$PROF_DIR"
  set_defaults
  load_conf "$CONF"

  local OPT PRESET_ARG="" OV_T="" OV_C="" OV_R="" OV_F="" OV_S="" OV_K="" OV_A="" OV_O="" OV_TS="" OV_TE="" OV_D=0 AUTO=0
  while getopts "p:t:c:r:f:s:k:a:S:E:o:dyh" OPT; do
    case $OPT in
      p) PRESET_ARG=$OPTARG;; t) OV_T=$OPTARG;; c) OV_C=$OPTARG;; r) OV_R=$OPTARG;;
      f) OV_F=$OPTARG;; s) OV_S=$OPTARG;; k) OV_K=$OPTARG;; a) OV_A=$OPTARG;;
      S) OV_TS=$OPTARG;; E) OV_TE=$OPTARG;; o) OV_O=$OPTARG;; d) OV_D=1;; y) AUTO=1;;
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
  [[ -n $OV_K ]] && { case $OV_K in x265|x264|hw265|hw264) CODEC=$OV_K;; *) err "Unknown codec: $OV_K"; exit 1;; esac; PRESET_NAME=custom; }
  [[ -n $OV_C ]] && { CRF=$OV_C; TARGET_MB=0; PRESET_NAME=custom; }
  [[ -n $OV_T ]] && { TARGET_MB=$OV_T; PRESET_NAME=custom; }
  [[ -n $OV_R ]] && { HEIGHT=$OV_R; PRESET_NAME=custom; }
  [[ -n $OV_F ]] && { FPS=$OV_F; PRESET_NAME=custom; }
  [[ -n $OV_S ]] && { SPEED=$OV_S; PRESET_NAME=custom; }
  if [[ -n $OV_A ]]; then
    case $OV_A in copy|none) AUDIO=$OV_A;; *[!0-9]*) err "Bad -a value"; exit 1;; *) AUDIO=aac; ABR=$OV_A;; esac
    PRESET_NAME=custom
  fi
  [[ -n $OV_O ]] && OUTDIR=${OV_O/#\~/$HOME}
  if [[ -n $OV_TS ]]; then TRIM_START=$(to_sec "$OV_TS") || { err "Bad -S time"; exit 1; }; fi
  if [[ -n $OV_TE ]]; then TRIM_END=$(to_sec "$OV_TE")   || { err "Bad -E time"; exit 1; }; fi
  (( OV_D )) && DELETE_ORIG=1
  for OPT in CRF TARGET_MB HEIGHT FPS ABR; do
    [[ ${!OPT} =~ ^[0-9]+$ ]] || { err "Invalid numeric value for $OPT: ${!OPT}"; exit 1; }
  done

  local a
  for a in "$@"; do
    if [[ -d $a ]]; then
      while IFS= read -r f; do add_sel "$f"; done < <(list_videos "$a")
    elif [[ -f $a ]]; then add_sel "$a"
    else err "Not found: $a"; fi
  done

  trap on_int INT TERM
  trap cleanup EXIT

  if (( AUTO )); then
    NONINTERACTIVE=1
    (( ${#SELECTED[@]} )) || { err "No input files given."; exit 1; }
    print_plan
    run_batch
    exit $?
  fi
  main_menu
}

main "$@"
