#!/usr/bin/env bash
# =============================================================================
#  VidCompress Manager 1.1  |  Creator: W6W  |  offers-pishnahadat.vercel.app
#
#  Install, update, repair, roll back and uninstall VidCompress (vc) - from a
#  touch-friendly menu or from the command line.
#
#  One-line install (no menu, installs / updates vc):
#     curl -fsSL https://raw.githubusercontent.com/Alireza123456w6w/V.C.-a-video-compresser-for-termux/main/install.sh | bash
#  Open the menu straight from the web:
#     curl -fsSL <same url> | bash -s -- --menu
#  After the first install the manager lives on your phone as:   vcman   (menu)   vcdel   (uninstall)
#
#  Commands:
#     (none)               menu in a terminal, quick install when piped
#     --menu               menu
#     --install            install or reinstall vc (+ vcman, vcdel)
#     --update             update only if a newer version exists
#     --check              only check for an update   (exit 0 = up to date, 10 = update available, 2 = offline)
#     --status             health check of the whole installation
#     --repair             re-download and reinstall everything, fix permissions
#     --rollback [N]       go back to a previous vc version (N-th newest backup)
#     --deps [GROUP]       install the extra tools via  vc --setup   (all|core|w6w|perf|repair|extras)
#     --selftest [full]    run  vc --selftest
#     --uninstall          remove vc.  Add:  --commands-only (default) | --purge | --purge-key
#  Options:  -y/--yes  --dry-run  --branch NAME  --sha256 HASH  -h/--help  -v/--version
#  Environment:  VC_BRANCH  VC_REPO  VC_RAW_BASE  VC_SHA256  VC_BIN_DIR
# =============================================================================

MGR_VERSION="1.1"
CREATOR="W6W"
WEBSITE="offers-pishnahadat.vercel.app"
REPO_DEFAULT="Alireza123456w6w/V.C.-a-video-compresser-for-termux"

REPO=${VC_REPO:-$REPO_DEFAULT}
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vidcompress"
MGR_CONF="$CONF_DIR/manager.conf"
BACKUP_DIR="$CONF_DIR/backups"
LOG_FILE="$CONF_DIR/manager.log"
KEEP_BACKUPS=5
OPT_PKGS=(gpac untrunc openssl-tool xz-utils less util-linux termux-api file ffmpeg)   # packages "vc --setup" may have added

# ------------------------------------------------------------------ source ---
SAVED_BRANCH=""
[[ -r $MGR_CONF ]] && SAVED_BRANCH=$(sed -n 's/^BRANCH=\([A-Za-z0-9._\/-]*\)$/\1/p' "$MGR_CONF" 2>/dev/null | head -1)
BRANCH=${VC_BRANCH:-${SAVED_BRANCH:-main}}
set_raw_base() { RAW_BASE=${VC_RAW_BASE:-https://raw.githubusercontent.com/$REPO/$BRANCH}; }
set_raw_base

# ------------------------------------------------------------------- paths ---
if [[ -n ${VC_BIN_DIR:-} ]]; then BIN_DIR=$VC_BIN_DIR
elif [[ -n ${PREFIX:-} && -d ${PREFIX}/bin && -w ${PREFIX}/bin ]]; then BIN_DIR=$PREFIX/bin
elif [[ $(id -u 2>/dev/null) == 0 ]]; then BIN_DIR=/usr/local/bin
else BIN_DIR=$HOME/.local/bin; fi

# ------------------------------------------------------------------ colors ---
if [[ -t 1 ]]; then
  C_B=$'\e[1m'; C_D=$'\e[2m'; C_R=$'\e[31m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_C=$'\e[36m'; C_0=$'\e[0m'
else
  C_B=; C_D=; C_R=; C_G=; C_Y=; C_C=; C_0=
fi
ok()   { printf '%s\n' "${C_G}✔ $*${C_0}"; }
warn() { printf '%s\n' "${C_Y}! $*${C_0}" >&2; }
err()  { printf '%s\n' "${C_R}✘ $*${C_0}" >&2; }
info() { printf '%s\n' "${C_C}$*${C_0}"; }
dim()  { printf '%s\n' "${C_D}$*${C_0}"; }
step() { printf '%s\n' "${C_B}▶ [$1/$2] $3${C_0}"; }
row()  { printf '  %-15s %s\n' "$1" "$2"; }

banner() {
  printf '%s\n' "${C_B}══════════════════════════════════════════════${C_0}"
  printf '%s\n' "${C_B}  VidCompress Manager${C_0} v$MGR_VERSION  ·  by $CREATOR"
  printf '%s\n' "${C_D}  $WEBSITE${C_0}"
  printf '%s\n' "${C_B}══════════════════════════════════════════════${C_0}"
}

# --------------------------------------------------------------- terminal ----
TTY=""; INTERACTIVE=0
if [[ -t 0 ]]; then TTY=/dev/stdin
elif ( : </dev/tty ) 2>/dev/null; then TTY=/dev/tty; fi
[[ -n $TTY ]] && INTERACTIVE=1

ASSUME_YES=0; DRY=0
ask() {   # $1 prompt  $2 default  -> REPLY
  local a=""
  if (( INTERACTIVE )); then printf '%s' "$1" >&2; IFS= read -r a < "$TTY" || a=""; fi
  REPLY=${a:-${2:-}}
}
confirm() {   # $1 prompt  $2 default y|n   (--yes answers yes)
  local def=${2:-n} hint="y/N"
  [[ $def == y ]] && hint="Y/n"
  (( ASSUME_YES )) && return 0
  (( INTERACTIVE )) || { [[ $def == y ]]; return; }
  ask "$1 [$hint] " "$def"
  [[ ${REPLY,,} == y* ]]
}
pause() { (( INTERACTIVE )) && { printf '\n' >&2; ask "${C_D}Press Enter to continue...${C_0}" ""; }; }
clear_screen() { [[ -t 1 ]] && printf '\033[2J\033[H'; }

# ------------------------------------------------------------- work folder ---
WORK=$(mktemp -d 2>/dev/null) || { err "Cannot create a temporary folder."; exit 1; }
cleanup() { [[ -n ${WORK:-} && -d $WORK ]] && rm -rf -- "$WORK"; }
trap cleanup EXIT
trap 'echo; warn "Interrupted."; exit 130' INT TERM

# ----------------------------------------------------------------- helpers ---
is_termux() { [[ ${PREFIX:-} == *com.termux* || -n ${TERMUX_VERSION:-} ]]; }
human() { awk -v b="${1:-0}" 'BEGIN { split("B KB MB GB", u, " "); i = 1; while (b >= 1024 && i < 4) { b /= 1024; i++ } if (i == 1) printf "%d %s", b, u[i]; else printf "%.1f %s", b, u[i] }'; }
free_bytes() { df -Pk -- "$1" 2>/dev/null | awk 'NR==2 && $4 ~ /^[0-9]+$/ { printf "%.0f", $4 * 1024; f = 1 } END { if (!f) printf "0" }'; }
path_bytes() { du -sk -- "$1" 2>/dev/null | awk '{ printf "%.0f", $1 * 1024 }'; }
sha_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }
logf() { [[ -d $CONF_DIR ]] && printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE" 2>/dev/null; return 0; }
ver_of_file() { sed -n 's/^VERSION="\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -1; }
local_ver() { [[ -f $BIN_DIR/vc ]] && ver_of_file "$BIN_DIR/vc"; }
ver_gt() { [[ $1 != "$2" && $(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1) == "$1" ]]; }   # $1 newer than $2
in_path() { case ":$PATH:" in *":$BIN_DIR:"*) return 0;; esac; return 1; }
is_vc_file()  { [[ -f $1 ]] && grep -q 'VidCompress' "$1" 2>/dev/null && ! grep -q 'VidCompress Manager' "$1" 2>/dev/null; }
is_mgr_file() { [[ -f $1 ]] && grep -q 'VidCompress Manager' "$1" 2>/dev/null; }

# ------------------------------------------------------ package manager ------
PM=none; SUDO=""
detect_pm() {
  if is_termux && command -v pkg >/dev/null 2>&1; then PM=pkg
  elif command -v apt-get >/dev/null 2>&1; then PM=apt
  elif command -v dnf >/dev/null 2>&1; then PM=dnf
  elif command -v pacman >/dev/null 2>&1; then PM=pacman
  elif command -v apk >/dev/null 2>&1; then PM=apk
  fi
  if [[ $PM != pkg && $PM != none && $(id -u 2>/dev/null) != 0 ]] && command -v sudo >/dev/null 2>&1; then SUDO=sudo; fi
}
pm_install() {
  case $PM in
    pkg)    pkg install -y "$@";;
    apt)    $SUDO apt-get install -y "$@";;
    dnf)    $SUDO dnf install -y "$@";;
    pacman) $SUDO pacman -S --noconfirm "$@";;
    apk)    $SUDO apk add "$@";;
    *)      return 1;;
  esac
}
have_pkg() { is_termux && dpkg -s "$1" >/dev/null 2>&1; }
ensure_core() {   # curl + ffmpeg
  local need=()
  command -v curl >/dev/null 2>&1   || need+=(curl)
  command -v ffmpeg >/dev/null 2>&1 || need+=(ffmpeg)
  (( ${#need[@]} == 0 )) && return 0
  detect_pm
  if [[ $PM == none ]]; then warn "Please install by hand: ${need[*]}"; return 1; fi
  if (( DRY )); then info "[dry-run] would install: ${need[*]}"; return 0; fi
  info "Installing: ${need[*]}"
  if ! pm_install "${need[@]}"; then
    [[ $PM == pkg ]] && { warn "Refreshing the package lists and trying again..."; pkg update -y >/dev/null 2>&1; pm_install "${need[@]}"; } || true
  fi
  local p missing=()
  for p in "${need[@]}"; do command -v "$p" >/dev/null 2>&1 || missing+=("$p"); done
  if (( ${#missing[@]} )); then warn "Could not install: ${missing[*]}  (check your internet, then run again)"; return 1; fi
  return 0
}

# --------------------------------------------------------------- download ----
fetch() { curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 600 -o "$2" "$1" 2>"$WORK/curl.err"; }
REMOTE_VER=""; LATEST_VER=""; LATEST_STATE=""
validate_script() {   # $1 file  $2 label  $3 marker text that must appear in it
  local f=$1 got
  [[ -s $f ]] || { err "The downloaded $2 is empty."; return 1; }
  [[ $(head -c 2 "$f" 2>/dev/null) == '#!' ]] || { err "The downloaded $2 is not a script (wrong URL or branch \"$BRANCH\"?)."; return 1; }
  grep -q "$3" "$f" || { err "The downloaded file does not look like $2."; return 1; }
  bash -n "$f" 2>/dev/null || { err "The downloaded $2 has a syntax error - NOT installing it."; return 1; }
  return 0
}
fetch_vc() {   # -> $WORK/vc.new validated, REMOTE_VER set
  local frc
  fetch "$RAW_BASE/vc.sh" "$WORK/vc.new"; frc=$?
  if (( frc != 0 )); then
    err "Download failed: $RAW_BASE/vc.sh"
    [[ -s $WORK/curl.err ]] && dim "  $(tail -n 1 "$WORK/curl.err")"
    if (( frc == 22 )); then err "GitHub answered \"not found\": is the file really named vc.sh, and is the branch \"$BRANCH\" right? (Advanced -> change branch)"
    else err "Check your internet connection."; fi
    return 2
  fi
  validate_script "$WORK/vc.new" "vc.sh" "VidCompress" || return 1
  REMOTE_VER=$(ver_of_file "$WORK/vc.new")
  [[ -n $REMOTE_VER ]] || { err "Cannot read the version number from vc.sh."; return 1; }
  if [[ -n ${VC_SHA256:-} ]]; then
    command -v sha256sum >/dev/null 2>&1 || { err "sha256sum is missing, cannot verify the download."; return 1; }
    [[ $(sha_of "$WORK/vc.new") == "${VC_SHA256,,}" ]] || { err "SHA-256 does not match - the download was NOT installed."; return 1; }
    ok "SHA-256 verified."
  fi
  return 0
}
remote_version_quick() {   # newest vc version from the first 128 KB.   return 0 ok | 1 no connection | 3 file not found on GitHub
  local data rc code
  data=$(curl -sSL --connect-timeout 6 --max-time 10 -r 0-131071 -w '\n__HTTP__%{http_code}' "$RAW_BASE/vc.sh" 2>/dev/null); rc=$?
  (( rc == 0 )) || return 1
  code=${data##*__HTTP__}; data=${data%$'\n'__HTTP__*}
  case $code in 404|403|410) return 3;; esac
  [[ $code == 2* || $code == 0 || $code == 000 ]] || return 1
  printf '%s\n' "$data" | sed -n 's/^VERSION="\([^"]*\)".*/\1/p' | head -1
}
refresh_latest() {   # sets LATEST_VER and LATEST_STATE: current | update | new | offline | notfound
  local rc lv
  LATEST_VER=$(remote_version_quick); rc=$?
  LATEST_STATE=""
  if (( rc == 1 )); then LATEST_STATE="offline"; return 1; fi
  if (( rc == 3 )) || [[ -z $LATEST_VER ]]; then LATEST_STATE="notfound"; return 1; fi
  lv=$(local_ver)
  if [[ -z $lv ]]; then LATEST_STATE="new"
  elif ver_gt "$LATEST_VER" "$lv"; then LATEST_STATE="update"
  else LATEST_STATE="current"; fi
  return 0
}

# ---------------------------------------------------------- file placement ---
put_file() {   # $1 source  $2 destination   (atomic: build next to it, then rename)
  local tmp="$2.new.$$"
  if (( DRY )); then info "[dry-run] would write $2"; return 0; fi
  mkdir -p "$(dirname -- "$2")" 2>/dev/null
  if install -m 755 "$1" "$tmp" 2>/dev/null || { cp -f "$1" "$tmp" 2>/dev/null && chmod 755 "$tmp"; }; then
    mv -f "$tmp" "$2" 2>/dev/null && return 0
  fi
  rm -f "$tmp" 2>/dev/null
  return 1
}
BACKUPS=()
list_backups() { BACKUPS=(); local f; while IFS= read -r f; do [[ -n $f ]] && BACKUPS+=("$f"); done < <(ls -1t "$BACKUP_DIR"/vc-*.sh 2>/dev/null); }
backup_vc() {
  [[ -f $BIN_DIR/vc ]] || return 0
  (( DRY )) && { info "[dry-run] would back up the current vc"; return 0; }
  mkdir -p "$BACKUP_DIR" 2>/dev/null || return 1
  local v dest i; v=$(local_ver); v=${v:-unknown}
  dest="$BACKUP_DIR/vc-$v-$(date +%Y%m%d-%H%M%S).sh"
  cp -f "$BIN_DIR/vc" "$dest" 2>/dev/null || return 1
  chmod 755 "$dest" 2>/dev/null
  list_backups
  for (( i = KEEP_BACKUPS; i < ${#BACKUPS[@]}; i++ )); do rm -f -- "${BACKUPS[i]}"; done
  BACKUP_LAST=$dest
  return 0
}
install_helpers() {   # vcman (this manager) + vcdel (uninstall shortcut)
  local src="" tmp="$WORK/vcman.new"
  if [[ -f ${BASH_SOURCE[0]:-} ]] && is_mgr_file "${BASH_SOURCE[0]}"; then src=${BASH_SOURCE[0]}
  else
    if fetch "$RAW_BASE/install.sh" "$tmp" && validate_script "$tmp" "install.sh" "VidCompress Manager"; then src=$tmp
    else warn "Could not get the manager script - vcman / vcdel were not installed (vc itself is fine)."; return 1; fi
  fi
  put_file "$src" "$BIN_DIR/vcman" || { warn "Cannot write $BIN_DIR/vcman"; return 1; }
  if (( ! DRY )); then
    cat > "$WORK/vcdel.new" <<'VCDEL'
#!/usr/bin/env bash
# vcdel - uninstall VidCompress (opens the uninstall menu of vcman)
exec "$(dirname -- "$(readlink -f -- "$0")")/vcman" --uninstall "$@"
VCDEL
    put_file "$WORK/vcdel.new" "$BIN_DIR/vcdel" || { warn "Cannot write $BIN_DIR/vcdel"; return 1; }
  fi
  return 0
}

# ----------------------------------------------------------------- install ---
check_system() {
  mkdir -p "$BIN_DIR" 2>/dev/null
  [[ -d $BIN_DIR && -w $BIN_DIR ]] || { err "Cannot write to $BIN_DIR (run as root or set VC_BIN_DIR)."; return 1; }
  command -v curl >/dev/null 2>&1 || { err "curl is missing: pkg install curl"; return 1; }
  local fr; fr=$(free_bytes "$BIN_DIR")
  if (( fr > 0 && fr < 20971520 )); then err "Not enough free space in $BIN_DIR ($(human "$fr") free, 20 MB needed)."; return 1; fi
  return 0
}
verify_install() {   # installed vc must be byte-identical to the download and report the version
  local out
  cmp -s "$WORK/vc.new" "$BIN_DIR/vc" || return 1
  out=$("$BIN_DIR/vc" --version 2>&1 | head -1)
  [[ $out == *"$REMOTE_VER"* ]] || warn "vc printed an unexpected version line: $out"
  return 0
}
do_install() {   # $1 = install | update | repair
  local mode=${1:-install} oldv status=0
  step 1 5 "Checking your system"
  check_system || return 1
  ensure_core || warn "Continuing - vc needs ffmpeg to work (vc --setup can install it)."
  step 2 5 "Downloading vc.sh  ($BRANCH)"
  fetch_vc; status=$?
  if (( status != 0 )); then
    if [[ $mode == repair && -f $BIN_DIR/vc ]]; then warn "Offline repair: only fixing permissions and the helper commands."
      chmod 755 "$BIN_DIR/vc" 2>/dev/null; install_helpers; return 0
    fi
    return $status
  fi
  oldv=$(local_ver)
  info "  remote version: $REMOTE_VER${oldv:+   installed: $oldv}"
  if [[ -n $oldv && $mode == update ]] && ! ver_gt "$REMOTE_VER" "$oldv"; then
    ok "vc $oldv is already the newest version."
    install_helpers >/dev/null 2>&1
    return 0
  fi
  if [[ -n $oldv && $mode == install && $oldv == "$REMOTE_VER" ]] && cmp -s "$WORK/vc.new" "$BIN_DIR/vc"; then
    info "  The same version is already installed - reinstalling to be sure."
  fi
  step 3 5 "Installing vc"
  backup_vc || warn "Could not back up the old version."
  put_file "$WORK/vc.new" "$BIN_DIR/vc" || { err "Could not write $BIN_DIR/vc"; return 1; }
  step 4 5 "Installing the manager (vcman) and the uninstall shortcut (vcdel)"
  install_helpers
  step 5 5 "Verifying"
  if (( ! DRY )); then
    if verify_install; then
      mkdir -p "$CONF_DIR" 2>/dev/null; logf "$mode: vc ${oldv:-none} -> $REMOTE_VER (branch $BRANCH)"
      hash -r 2>/dev/null
    else
      err "The installed file does not match the download."
      if [[ -n ${BACKUP_LAST:-} && -f $BACKUP_LAST ]]; then cp -f "$BACKUP_LAST" "$BIN_DIR/vc" && warn "The previous version was restored."; fi
      return 1
    fi
  fi
  echo
  if [[ -n $oldv && $oldv != "$REMOTE_VER" ]]; then ok "vc updated: $oldv -> $REMOTE_VER"
  elif [[ -n $oldv ]]; then ok "vc $REMOTE_VER reinstalled."
  else ok "vc $REMOTE_VER installed."; fi
  dim "   vc      -> the tool            vcman -> this manager (menu)"
  dim "   vcdel   -> uninstall           by $CREATOR - $WEBSITE"
  in_path || warn "$BIN_DIR is not in your PATH. Add it:  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
  if is_termux && [[ ! -d $HOME/storage/shared ]]; then warn "Storage access is not set up yet: run  termux-setup-storage  and tap Allow."; fi
  return 0
}
do_check() {
  local lv; lv=$(local_ver)
  if ! refresh_latest; then
    if [[ $LATEST_STATE == notfound ]]; then err "vc.sh was not found on GitHub (branch \"$BRANCH\") - check the file name and the branch."; else err "Cannot reach GitHub (offline?)."; fi
    return 2
  fi
  if [[ -z $lv ]]; then info "vc is not installed. Latest version: $LATEST_VER"; return 10; fi
  if [[ $LATEST_STATE == update ]]; then info "Update available: $lv -> $LATEST_VER   (run: vcman --update)"; return 10; fi
  ok "vc $lv is up to date."; return 0
}
do_rollback() {   # $1 = optional number
  local n=${1:-} i ch f v
  list_backups
  (( ${#BACKUPS[@]} )) || { err "No backups found in $BACKUP_DIR (they are made on every update)."; return 1; }
  if [[ -z $n ]]; then
    echo "Previous versions:"
    for i in "${!BACKUPS[@]}"; do
      f=${BACKUPS[i]}; v=$(ver_of_file "$f")
      printf '  %d) %s   %s   %s\n' $((i + 1)) "${v:-?}" "$(date -r "$f" '+%F %T' 2>/dev/null)" "$(human "$(path_bytes "$f")")"
    done
    (( INTERACTIVE )) || { err "Give a number: vcman --rollback N"; return 1; }
    ask "Restore which one? [1-${#BACKUPS[@]}, Enter = cancel] " ""; n=$REPLY
    [[ -n $n ]] || { info "Cancelled."; return 0; }
  fi
  [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#BACKUPS[@]} )) || { err "Invalid choice."; return 1; }
  f=${BACKUPS[n-1]}
  bash -n "$f" 2>/dev/null || { err "That backup is damaged (syntax check failed)."; return 1; }
  confirm "Restore vc $(ver_of_file "$f") ?" y || { info "Cancelled."; return 0; }
  backup_vc
  put_file "$f" "$BIN_DIR/vc" || { err "Could not restore."; return 1; }
  logf "rollback to $(ver_of_file "$f")"
  ok "vc $(ver_of_file "$f") restored."
}
do_deps() {   # $1 group
  local g=${1:-all}
  [[ -x $BIN_DIR/vc ]] || { err "vc is not installed yet. Install it first."; return 1; }
  info "Running:  vc --setup $g"
  (( DRY )) && { info "[dry-run] skipped"; return 0; }
  "$BIN_DIR/vc" --setup "$g"
}
deps_menu() {
  local ch
  echo
  echo "${C_B}Optional tools${C_0}  (installed through  vc --setup)"
  echo " 1) core     ffmpeg, ffprobe, awk, find         (required)"
  echo " 2) w6w      openssl, xz, tar, less             (.w6w vault)"
  echo " 3) perf     util-linux / taskset               (pin to the fast CPU cores)"
  echo " 4) repair   gpac (MP4Box), untrunc             (extra repair for broken MP4)"
  echo " 5) extras   termux-api, termux-tools, file     (notifications, open files)"
  echo " a) everything"
  echo " 0) back"
  ask "Choose: " ""; ch=$REPLY
  case ${ch,,} in
    1) do_deps core;; 2) do_deps w6w;; 3) do_deps perf;; 4) do_deps repair;; 5) do_deps extras;; a) do_deps all;; *) return 0;;
  esac
}

# ------------------------------------------------------------------ status ---
show_status() {
  local lv ff enc="" e name hints=() p cnt fr
  lv=$(local_ver)
  banner
  echo "${C_B}System${C_0}"
  if is_termux; then row "Platform" "Termux on Android $(getprop ro.build.version.release 2>/dev/null)  ($(uname -m))"
  else row "Platform" "$(uname -sm)"; fi
  fr=$(free_bytes "$HOME"); row "Free space" "$(human "$fr")  (home folder)"
  if is_termux; then
    if [[ -d $HOME/storage/shared ]]; then row "Storage" "${C_G}✔ access granted${C_0}"
    else row "Storage" "${C_Y}✘ not set up${C_0}"; hints+=("run  termux-setup-storage  and tap Allow"); fi
  fi
  echo; echo "${C_B}Installation${C_0}"
  if [[ -n $lv ]]; then row "vc" "${C_G}✔ $lv${C_0}  ($BIN_DIR/vc)"
  else row "vc" "${C_R}✘ not installed${C_0}"; hints+=("install vc:  vcman --install"); fi
  if is_mgr_file "$BIN_DIR/vcman"; then row "vcman" "${C_G}✔${C_0} manager"; else row "vcman" "${C_Y}✘ missing${C_0}"; hints+=("run  --repair  to restore vcman / vcdel"); fi
  [[ -x $BIN_DIR/vcdel ]] && row "vcdel" "${C_G}✔${C_0} uninstall shortcut" || row "vcdel" "${C_Y}✘ missing${C_0}"
  in_path && row "PATH" "${C_G}✔${C_0} $BIN_DIR" || { row "PATH" "${C_Y}✘ $BIN_DIR is not in PATH${C_0}"; hints+=("add $BIN_DIR to PATH"); }
  if [[ -n $lv && -n $LATEST_STATE ]]; then
    case $LATEST_STATE in
      update)  row "Latest" "${C_Y}$LATEST_VER - update available${C_0}";;
      current) row "Latest" "${C_G}$LATEST_VER - up to date${C_0}";;
      offline) row "Latest" "${C_D}offline${C_0}";;
      notfound) row "Latest" "${C_Y}vc.sh not found on branch \"$BRANCH\"${C_0}";;
    esac
  fi
  list_backups; row "Backups" "${#BACKUPS[@]} previous version(s)"
  echo; echo "${C_B}Engine${C_0}"
  if command -v ffmpeg >/dev/null 2>&1; then
    ff=$(ffmpeg -version 2>/dev/null | head -1 | awk '{print $3}'); row "ffmpeg" "${C_G}✔ $ff${C_0}"
    e=$(ffmpeg -hide_banner -encoders 2>/dev/null)
    for name in libx265:x265 libx264:x264 libsvtav1:AV1 libvpx-vp9:VP9 libopus:Opus; do
      if grep -q " ${name%%:*} " <<<"$e"; then enc+="${C_G}${name##*:}✔${C_0} "; else enc+="${C_D}${name##*:}✘${C_0} "; fi
    done
    row "Encoders" "$enc"
  else row "ffmpeg" "${C_R}✘ missing${C_0}"; hints+=("install ffmpeg:  vc --setup core"); fi
  command -v ffprobe >/dev/null 2>&1 || row "ffprobe" "${C_R}✘ missing${C_0}"
  echo; echo "${C_B}Optional tools${C_0}"
  cnt=0
  for p in openssl:".w6w vault" xz:".w6w vault" tar:".w6w vault" MP4Box:"extra MP4 repair" untrunc:"cut-off MP4 repair" taskset:"fast-core pinning" termux-notification:"notifications" termux-open:"open files"; do
    name=${p%%:*}
    if command -v "$name" >/dev/null 2>&1; then printf '  %s✔%s %-20s %s\n' "$C_G" "$C_0" "$name" "${C_D}${p#*:}${C_0}"
    else printf '  %s✘%s %-20s %s\n' "$C_D" "$C_0" "$name" "${C_D}${p#*:}${C_0}"; cnt=$((cnt + 1)); fi
  done
  (( cnt )) && hints+=("missing optional tools:  vcman --deps all")
  echo; echo "${C_B}Your data${C_0}  ($CONF_DIR)"
  if [[ -d $CONF_DIR ]]; then
    row "Size" "$(human "$(path_bytes "$CONF_DIR")")"
    [[ -f $CONF_DIR/settings.conf ]] && row "Settings" "saved" || row "Settings" "${C_D}defaults${C_0}"
    cnt=$(ls -1 "$CONF_DIR/profiles" 2>/dev/null | wc -l | tr -d ' '); row "Profiles" "$cnt"
    [[ -s $CONF_DIR/w6w.key ]] && row ".w6w key" "${C_Y}present${C_0} - needed to open your .w6w vaults, back it up: vc --w6w key export" || row ".w6w key" "${C_D}none${C_0}"
  else row "Folder" "${C_D}not created yet${C_0}"; fi
  echo
  if (( ${#hints[@]} )); then echo "${C_B}Suggestions${C_0}"; for p in "${hints[@]}"; do echo "  • $p"; done
  else ok "Everything looks good."; fi
}

# --------------------------------------------------------------- uninstall ---
SKIPPED=0
remove_file() {   # $1 path  $2 check function (only remove files that really are ours)
  local f=$1 chk=${2:-}
  [[ -e $f || -L $f ]] || return 0
  if [[ -n $chk ]] && ! $chk "$f"; then warn "Skipped $f (it is not a VidCompress file)."; SKIPPED=$((SKIPPED + 1)); return 0; fi
  if (( DRY )); then info "[dry-run] would remove $f"; else rm -f -- "$f" && info "  removed $f"; fi
}
is_vcdel_file() { [[ -f $1 ]] && grep -q 'vcman' "$1" 2>/dev/null; }
safe_rm_dir() {   # only folders named like ours, never HOME or /
  local p=$1
  [[ -n $p && $p == /* && $p != / && $p != "$HOME" && $p != "$HOME/" ]] || return 1
  case ${p##*/} in vidcompress|.vc-tmp) ;; *) warn "Refusing to delete $p"; return 1;; esac
  [[ -d $p ]] || return 0
  if (( DRY )); then info "[dry-run] would remove folder $p"; else rm -rf -- "$p" && info "  removed folder $p"; fi
}
clean_config() {   # $1 = keep_key | all
  local mode=$1
  [[ -d $CONF_DIR && ${CONF_DIR##*/} == vidcompress ]] || return 0
  if [[ $mode == all ]]; then safe_rm_dir "$CONF_DIR"; return; fi
  if (( DRY )); then
    info "[dry-run] would remove everything in $CONF_DIR except w6w.key / w6w.key.bak"
  else
    find "$CONF_DIR" -mindepth 1 -maxdepth 1 ! -name 'w6w.key' ! -name 'w6w.key.bak' -exec rm -rf -- {} + 2>/dev/null
    info "  cleaned $CONF_DIR (the .w6w key was kept)"
    rmdir "$CONF_DIR" 2>/dev/null
  fi
}
uninstall_summary() {
  local f n=0 have_key=0
  echo "${C_B}What is installed${C_0}"
  for f in "$BIN_DIR/vc" "$BIN_DIR/vcdel" "$BIN_DIR/vcman" "$HOME/bin/vc"; do [[ -e $f ]] && { row "Command" "$f"; n=$((n + 1)); }; done
  (( n )) || row "Commands" "${C_D}none found in $BIN_DIR${C_0}"
  if [[ -d $CONF_DIR ]]; then
    row "Your data" "$CONF_DIR  ($(human "$(path_bytes "$CONF_DIR")"))"
    [[ -s $CONF_DIR/w6w.key ]] && have_key=1
    list_backups; (( ${#BACKUPS[@]} )) && row "Backups" "${#BACKUPS[@]} old vc version(s)"
  else row "Your data" "${C_D}none${C_0}"; fi
  (( have_key )) && echo "  ${C_Y}⚠ A .w6w device key exists. Without it your .w6w vaults can NEVER be opened again.${C_0}"
  [[ -d $HOME/.vc-tmp ]] && row "Temp" "$HOME/.vc-tmp"
}
run_uninstall() {   # $1: 1 = commands only | 2 = + data (key kept) | 3 = + data and key
  local level=$1
  (( DRY )) && info "${C_B}-- dry run: nothing will be deleted --${C_0}"
  remove_file "$BIN_DIR/vc" is_vc_file
  remove_file "$HOME/bin/vc" is_vc_file         # very old installs
  remove_file "$BIN_DIR/vcdel" is_vcdel_file
  safe_rm_dir "$HOME/.vc-tmp"
  if (( level == 2 )); then clean_config keep_key; fi
  if (( level == 3 )); then clean_config all; fi
  remove_file "$BIN_DIR/vcman" is_mgr_file      # last: this very script
  hash -r 2>/dev/null
  echo
  if (( DRY )); then info "Dry run finished."; return 0; fi
  if (( SKIPPED )); then ok "VidCompress was removed ($SKIPPED file(s) that are not ours were left alone)."; else ok "VidCompress was removed."; fi
  case $level in
    1) dim "   Your settings, profiles and .w6w key are still in $CONF_DIR (reinstall any time).";;
    2) dim "   Settings and logs were deleted. The .w6w key was kept: $CONF_DIR/w6w.key";;
    3) dim "   Everything was deleted, including the .w6w key.";;
  esac
  dim "   Packages such as ffmpeg were not touched. (Menu: Uninstall -> remove helper packages)"
}
remove_packages_menu() {
  local p list=() ch
  is_termux || { warn "Package removal is only offered in Termux. Use your own package manager."; return 0; }
  for p in "${OPT_PKGS[@]}"; do have_pkg "$p" && list+=("$p"); done
  (( ${#list[@]} )) || { info "None of the helper packages are installed."; return 0; }
  echo "${C_B}Helper packages that vc --setup may have installed${C_0}"
  echo "${C_Y}Other apps can use them too. ffmpeg is the biggest one - remove it only if you are sure.${C_0}"
  for p in "${list[@]}"; do
    if confirm "Remove $p ?" n; then
      if (( DRY )); then info "[dry-run] would run: pkg uninstall -y $p"; else pkg uninstall -y "$p" >/dev/null 2>&1 && ok "removed $p" || warn "could not remove $p"; fi
    fi
  done
}
uninstall_menu() {
  local ch typed
  while true; do
    clear_screen; banner; echo "${C_B}Uninstall${C_0}"; echo
    uninstall_summary; echo
    echo " 1) Remove the commands only            (keeps settings, profiles, .w6w key, backups)"
    echo " 2) Remove commands + settings + logs    (keeps the .w6w key)   ${C_G}recommended clean-up${C_0}"
    echo " 3) Remove EVERYTHING incl. the .w6w key (cannot be undone)"
    echo " 4) Remove helper packages (ffmpeg, openssl, gpac ...)"
    echo " 5) Dry run - only show what would be removed"
    echo " 0) Back"
    ask "Choose: " ""; ch=$REPLY
    case $ch in
      1) if confirm "Remove the vc commands?" n; then run_uninstall 1; exit 0; fi;;
      2) if confirm "Remove the vc commands, settings, profiles, logs and backups? (the .w6w key stays)" n; then run_uninstall 2; exit 0; fi;;
      3) echo "${C_R}This deletes your .w6w device key. Every .w6w vault made with it becomes unreadable.${C_0}"
         if [[ -s $CONF_DIR/w6w.key ]] && confirm "Save a backup copy of the key in your home folder first?" y; then
           ( umask 077; cp -f "$CONF_DIR/w6w.key" "$HOME/w6w.key.backup" ) && ok "Key backup: $HOME/w6w.key.backup"
         fi
         ask "Type DELETE to continue: " ""; typed=$REPLY
         if [[ $typed == DELETE ]]; then run_uninstall 3; exit 0; else info "Cancelled."; pause; fi;;
      4) remove_packages_menu; pause;;
      5) DRY=1 run_uninstall 2; pause;;
      0|"") return 0;;
    esac
  done
}
uninstall_cli() {
  local level=${UN_LEVEL:-1}
  uninstall_summary; echo
  if (( level == 3 )) && (( ! ASSUME_YES )); then err "--purge-key deletes your .w6w key. Add --yes if you really mean it."; return 1; fi
  if (( INTERACTIVE )) && (( ! ASSUME_YES )) && (( ! DRY )) && [[ -z ${UN_LEVEL:-} ]]; then uninstall_menu; return; fi
  if (( ! DRY )) && (( ! ASSUME_YES )) && (( INTERACTIVE )); then confirm "Continue (level $level)?" n || { info "Cancelled."; return 0; }; fi
  if (( ! DRY )) && (( ! ASSUME_YES )) && (( ! INTERACTIVE )); then err "Not a terminal: add --yes to uninstall without questions."; return 1; fi
  run_uninstall "$level"
}

# -------------------------------------------------------------------- menu ---
advanced_menu() {
  local ch b v f
  while true; do
    clear_screen; banner; echo "${C_B}Advanced${C_0}"; echo
    row "Source" "$REPO  (branch: $BRANCH)"
    row "Install dir" "$BIN_DIR"
    row "Data dir" "$CONF_DIR"; echo
    echo " 1) Change the source branch / tag (saved)"
    echo " 2) Verify the installed vc against GitHub (SHA-256)"
    echo " 3) Update this manager (vcman) itself"
    echo " 4) Show the manager log"
    echo " 5) Delete old backups"
    echo " 0) Back"
    ask "Choose: " ""; ch=$REPLY
    case $ch in
      1) ask "Branch or tag name [$BRANCH]: " "$BRANCH"; b=$REPLY
         if [[ $b =~ ^[A-Za-z0-9._/-]+$ ]]; then
           BRANCH=$b; set_raw_base; mkdir -p "$CONF_DIR"; printf 'BRANCH=%s\n' "$BRANCH" > "$MGR_CONF"; ok "Saved. Next install uses: $BRANCH"
         else err "Invalid name."; fi; pause;;
      2) if [[ ! -f $BIN_DIR/vc ]]; then err "vc is not installed."
         elif fetch_vc; then
           info "  installed : $(sha_of "$BIN_DIR/vc")"; info "  on GitHub : $(sha_of "$WORK/vc.new")"
           if cmp -s "$BIN_DIR/vc" "$WORK/vc.new"; then ok "Identical to the current vc.sh on GitHub."; else warn "Different from GitHub (older version, or edited by you)."; fi
         fi; pause;;
      3) f="$WORK/vcman.new"
         if fetch "$RAW_BASE/install.sh" "$f" && validate_script "$f" "install.sh" "VidCompress Manager"; then
           v=$(sed -n 's/^MGR_VERSION="\([^"]*\)".*/\1/p' "$f" | head -1)
           if [[ -n $v ]] && ver_gt "$v" "$MGR_VERSION"; then put_file "$f" "$BIN_DIR/vcman" && ok "Manager updated to $v. Restart it: vcman"; exit 0
           else ok "The manager ($MGR_VERSION) is already the newest."; fi
         else err "Could not download the manager."; fi; pause;;
      4) if [[ -s $LOG_FILE ]]; then tail -n 30 "$LOG_FILE"; else echo "(log is empty)"; fi; pause;;
      5) list_backups
         if (( ${#BACKUPS[@]} )) && confirm "Delete ${#BACKUPS[@]} backup(s)?" n; then rm -f -- "${BACKUPS[@]}"; ok "Deleted."; else info "Nothing deleted."; fi; pause;;
      0|"") return 0;;
    esac
  done
}
menu_header() {
  local lv; lv=$(local_ver)
  banner
  if [[ -n $lv ]]; then row "Installed" "vc ${C_B}$lv${C_0}   ($BIN_DIR/vc)"; else row "Installed" "${C_Y}vc is not installed${C_0}"; fi
  case $LATEST_STATE in
    update)  row "Latest" "${C_Y}$LATEST_VER  ←  update available${C_0}";;
    current) row "Latest" "${C_G}$LATEST_VER  (up to date)${C_0}";;
    new)     row "Latest" "$LATEST_VER";;
    offline) row "Latest" "${C_D}offline - could not check${C_0}";;
    notfound) row "Latest" "${C_Y}vc.sh not found on branch \"$BRANCH\" (Advanced -> change branch)${C_0}";;
    *)       row "Latest" "${C_D}not checked${C_0}";;
  esac
  command -v ffmpeg >/dev/null 2>&1 && row "ffmpeg" "${C_G}✔${C_0} $(ffmpeg -version 2>/dev/null | head -1 | awk '{print $3}')" || row "ffmpeg" "${C_R}✘ missing${C_0}"
  (( DRY )) && echo "${C_Y}  dry-run mode: nothing is changed${C_0}"
  echo
}
main_menu() {
  local ch label
  (( INTERACTIVE )) || { err "No terminal available for the menu. Use a command, e.g.:  --install  --status  --uninstall --yes"; return 1; }
  info "Checking for updates..."; refresh_latest
  while true; do
    clear_screen; menu_header
    label="Install vc"; [[ -f $BIN_DIR/vc ]] && label="Update / reinstall vc"
    [[ $LATEST_STATE == update ]] && label="$label  ${C_Y}(update available)${C_0}"
    echo " 1) $label"
    echo " 2) Install optional tools        (vc --setup)"
    echo " 3) Status & health check"
    echo " 4) Repair the installation"
    echo " 5) Roll back to a previous version"
    echo " 6) Check for updates"
    echo " 7) Run vc self-test"
    echo " 8) Advanced"
    echo " 9) Uninstall..."
    echo " o) Open vc"
    echo " 0) Quit"
    ask "Choose: " ""; ch=$REPLY
    case ${ch,,} in
      1) if [[ -f $BIN_DIR/vc && $LATEST_STATE == current ]] && ! confirm "vc is already the newest version. Reinstall anyway?" n; then :
         else do_install install; refresh_latest; fi; pause;;
      2) if [[ -x $BIN_DIR/vc ]]; then deps_menu; else err "Install vc first (option 1)."; fi; pause;;
      3) clear_screen; show_status; pause;;
      4) do_install repair; refresh_latest; pause;;
      5) do_rollback ""; pause;;
      6) do_check; refresh_latest; pause;;
      7) if [[ -x $BIN_DIR/vc ]]; then ask "Quick test or full test? [Q/f] " "q"; [[ ${REPLY,,} == f* ]] && "$BIN_DIR/vc" --selftest full || "$BIN_DIR/vc" --selftest; else err "Install vc first."; fi; pause;;
      8) advanced_menu;;
      9) uninstall_menu;;
      o) if [[ -x $BIN_DIR/vc ]]; then "$BIN_DIR/vc"; else err "vc is not installed."; pause; fi;;
      0|q) break;;
    esac
  done
  echo; dim "by $CREATOR - $WEBSITE"
}

# -------------------------------------------------------------------- help ---
usage() {
  cat <<EOF
VidCompress Manager $MGR_VERSION  -  install / update / repair / roll back / uninstall vc

Usage:  vcman [command] [options]        (or:  curl -fsSL <install.sh url> | bash [-s -- options])

Commands:
  (none)             menu in a terminal, quick install when piped
  --menu             open the menu
  --install          install or reinstall vc (+ vcman, vcdel)
  --update           update only if a newer version exists
  --check            check for an update (exit 0 = up to date, 10 = update available, 2 = offline)
  --status           health check (platform, ffmpeg, encoders, tools, your data)
  --repair           re-download and reinstall everything, fix permissions
  --rollback [N]     restore a previous vc version (backups are made on every update)
  --deps [GROUP]     install extra tools through vc --setup  (all|core|w6w|perf|repair|extras)
  --selftest [full]  run vc --selftest
  --uninstall        remove vc:   --commands-only (default)  keeps your settings and .w6w key
                                  --purge        also deletes settings, profiles, logs, backups (key is kept)
                                  --purge-key    deletes EVERYTHING including the .w6w key (needs --yes)

Options:
  -y, --yes          do not ask questions
  --dry-run          show what would happen, change nothing
  --branch NAME      install from another branch or tag (default: $BRANCH)
  --sha256 HASH      refuse the download unless vc.sh has this SHA-256
  -v, --version      manager version        -h, --help   this text

Environment: VC_BRANCH, VC_REPO, VC_RAW_BASE, VC_SHA256, VC_BIN_DIR

Examples:
  curl -fsSL https://raw.githubusercontent.com/$REPO_DEFAULT/main/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/$REPO_DEFAULT/main/install.sh | bash -s -- --menu
  vcman --update            vcman --status            vcman --rollback 1
  vcman --uninstall --purge --yes
EOF
}

# -------------------------------------------------------------------- main ---
CMD=""; DEPS=0; DEPS_GROUP=all; ROLLBACK_N=""; SELFTEST_ARG=""; UN_LEVEL=""
while (( $# )); do
  case $1 in
    --menu|menu)                 CMD=menu;;
    --install|install)           CMD=install;;
    --update|update|--upgrade)   CMD=update;;
    --check|check)               CMD=check;;
    --status|status|--doctor|doctor) CMD=status;;
    --repair|repair)             CMD=repair;;
    --rollback|rollback)         CMD=rollback; if [[ ${2:-} =~ ^[0-9]+$ ]]; then ROLLBACK_N=$2; shift; fi;;
    --deps|deps)                 DEPS=1; DEPS_GROUP=all
                                 case ${2:-} in all|core|w6w|perf|repair|extras) DEPS_GROUP=$2; shift;; esac
                                 [[ -z $CMD ]] && CMD=deps;;
    --selftest|selftest)         CMD=selftest; if [[ ${2:-} == full ]]; then SELFTEST_ARG=full; shift; fi;;
    --uninstall|uninstall|--remove) CMD=uninstall;;
    --commands-only)             UN_LEVEL=1;;
    --purge)                     UN_LEVEL=2;;
    --purge-key)                 UN_LEVEL=3;;
    -y|--yes)                    ASSUME_YES=1;;
    --dry-run)                   DRY=1;;
    --branch)                    [[ ${2:-} =~ ^[A-Za-z0-9._/-]+$ ]] || { err "--branch needs a valid name."; exit 1; }
                                 BRANCH=$2; set_raw_base; shift;;
    --sha256)                    [[ ${2:-} =~ ^[0-9A-Fa-f]{64}$ ]] || { err "--sha256 needs a 64-character hash."; exit 1; }
                                 VC_SHA256=$2; shift;;
    -v|--version|--manager-version) echo "VidCompress Manager $MGR_VERSION"; exit 0;;
    -h|--help)                   usage; exit 0;;
    *) err "Unknown option: $1"; echo; usage; exit 1;;
  esac
  shift
done

if [[ -z $CMD ]]; then
  if [[ -t 0 ]]; then CMD=menu; else CMD=install; fi     # a terminal gets the menu, a pipe gets the quick install
fi

case $CMD in
  menu)      main_menu; exit $?;;
  install)   banner; do_install install; rc=$?
             if (( rc == 0 && DEPS )); then do_deps "$DEPS_GROUP"; fi
             if (( rc == 0 )); then echo; info "Next:  vc            open the tool"; dim "       vc --setup     install the extra tools (w6w vault, repair ...)"; dim "       vcman          open this manager"; fi
             exit $rc;;
  update)    banner; do_install update; exit $?;;
  repair)    banner; do_install repair; exit $?;;
  check)     do_check; exit $?;;
  status)    refresh_latest; show_status; exit 0;;
  rollback)  banner; do_rollback "$ROLLBACK_N"; exit $?;;
  deps)      do_deps "$DEPS_GROUP"; exit $?;;
  selftest)  [[ -x $BIN_DIR/vc ]] || { err "vc is not installed."; exit 1; }; "$BIN_DIR/vc" --selftest $SELFTEST_ARG; exit $?;;
  uninstall) banner; uninstall_cli; exit $?;;
esac
