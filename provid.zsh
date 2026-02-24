#!/bin/zsh
# ==============================================================================
# provid.zsh - Professional Video Organizer v3.1 (Standalone)
# ==============================================================================
# Organizes video files by resolution, orientation, and frame rate.
# Detects iPhone models, GPS data, and duplicates.
# ALL tools accept drag-and-drop of a folder OR individual video files.
# Includes Exiff: interactive EXIF forensics / authenticity analysis.
# ==============================================================================

# shellcheck disable=all
# shellcheck shell=zsh

set -o pipefail

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH

EXIFTOOL="exiftool"
MEDIAINFO="mediainfo"
BC="bc"

# ==============================================================================
# UI / STYLING
# ==============================================================================

autoload -Uz colors && colors
BLUE="${fg[blue]}"
GREEN="${fg[green]}"
CYAN="${fg[cyan]}"
RED="${fg[red]}"
YELLOW="${fg[yellow]}"
MAGENTA="${fg[magenta]}"
WHITE="${fg[white]}"
RESET="${reset_color}"
HEADER="${fg_bold[cyan]}"
SUCCESS="${fg_bold[green]}"
ERROR="${fg_bold[red]}"
ORANGE=$'\e[38;5;214m'

CHECK="✅"
CROSS="❌"
INFO="ℹ️"
WARNING="⚠️"
IPHONE="📱"
CAMERA="📷"
GPS="🌍"
GLOBE="🌍"
EDIT="✂️"

typeset -g EXIFTOOL_ARGS=(-a -G1 -s -api QuickTimeUTC=1)
typeset -g MEDIAINFO_ARGS=(--Output=General)

get_video_duration() {
    local file="$1"
    mediainfo --Inform="Video;%Duration%" "$file" 2>/dev/null \
        | awk '{printf "%.2f\n", $1/1000}'
}

# ==============================================================================
# DRAG-AND-DROP PATH HELPERS
# ==============================================================================

# sanitize_dropped_path <raw-token>
# Cleans a single drag-and-drop token: unescapes shell quoting, expands ~,
# decodes %20, trims whitespace, collapses double-slashes, strips trailing /.
sanitize_dropped_path() {
    # ${(Q)} removes one level of shell quoting/backslash-escaping —
    # exactly what the terminal inserts when files are dragged.
    local _sdp_in="$1"
    local raw="${(Q)_sdp_in}"
    raw="${raw/#\~/$HOME}"        # expand leading ~
    raw="${raw//%20/ }"           # decode %20 URL encoding
    # Trim leading whitespace (EXTENDED_GLOB: # = zero-or-more, ## = one-or-more)
    raw="${raw##[[:space:]]#}"
    # Trim trailing whitespace
    raw="${raw%%[[:space:]]#}"
    # Collapse runs of double (or more) slashes, but preserve leading //
    while [[ "$raw" == ?*'//'* ]]; do raw="${raw//\/\//\/}"; done
    # Remove trailing slash (except the root directory)
    [[ "$raw" != "/" ]] && raw="${raw%/}"
    printf '%s' "$raw"
}

# _VIDEO_EXTS: all recognised video extensions (lowercase)
# Used in collect_video_inputs and the main file scanner.
_VIDEO_EXTS=(
    mov mp4 m4v 3gp 3g2 hevc heic
    avi mkv webm mts m2ts flv wmv asf
    rm rmvb vob ts mpg mpeg ogv f4v
)

# _is_video_ext <ext-lowercase>  →  returns 0 (true) if it's a video extension
_is_video_ext() {
    local e="$1"
    local x
    for x in "${_VIDEO_EXTS[@]}"; do
        [[ "$x" == "$e" ]] && return 0
    done
    return 1
}

# collect_video_inputs <raw-input-line> <output-array-name>
# Splits a drag-and-drop input line (may contain multiple quoted/escaped paths),
# expands folders recursively, validates individual files, deduplicates.
# Populates the named array with absolute video file paths.
# Sets the global _COLLECT_BASE_DIR to the first relevant directory.
typeset -g _COLLECT_BASE_DIR=""

collect_video_inputs() {
    local raw_line="$1"
    local -n _cvi_out="$2"   # nameref to caller's array (zsh 5.1+)
    _cvi_out=()
    _COLLECT_BASE_DIR=""

    # ${(z)} splits on shell words, respecting quoting and backslash-escaping.
    local -a tokens
    tokens=(${(z)raw_line})

    local _cvi_first_base=""
    local -A _cvi_seen   # for deduplication

    for tok in "${tokens[@]}"; do
        [[ -z "$tok" ]] && continue
        local p
        p=$(sanitize_dropped_path "$tok")
        [[ -z "$p" ]] && continue

        if [[ -d "$p" ]]; then
            [[ -z "$_cvi_first_base" ]] && _cvi_first_base="$p"
            local _found=0
            while IFS= read -r -d $'\0' vf; do
                if [[ -z "${_cvi_seen[$vf]}" ]]; then
                    _cvi_seen[$vf]=1
                    _cvi_out+=("$vf")
                    ((_found++))
                fi
            done < <(find "$p" -type f \( \
                -iname "*.mov" -o -iname "*.mp4"  -o -iname "*.m4v"  \
                -o -iname "*.3gp"  -o -iname "*.3g2"  -o -iname "*.hevc" \
                -o -iname "*.heic" -o -iname "*.avi"  -o -iname "*.mkv"  \
                -o -iname "*.webm" -o -iname "*.mts"  -o -iname "*.m2ts" \
                -o -iname "*.flv"  -o -iname "*.wmv"  -o -iname "*.asf"  \
                -o -iname "*.rm"   -o -iname "*.rmvb" -o -iname "*.vob"  \
                -o -iname "*.ts"   -o -iname "*.mpg"  -o -iname "*.mpeg" \
                -o -iname "*.ogv"  -o -iname "*.f4v"  \
            \) -print0 2>/dev/null | sort -z)
            printf "${GREEN}📁 Folder: %s${RESET} — ${CYAN}%d video(s) found${RESET}\n" \
                "${p##*/}" "$_found"

        elif [[ -f "$p" ]]; then
            local ext="${(L)${p##*.}}"   # lowercase extension
            if _is_video_ext "$ext"; then
                if [[ -z "${_cvi_seen[$p]}" ]]; then
                    _cvi_seen[$p]=1
                    _cvi_out+=("$p")
                    [[ -z "$_cvi_first_base" ]] && _cvi_first_base="${p:h}"
                    printf "${GREEN}📹 File:   %s${RESET}\n" "${p##*/}"
                fi
            else
                printf "${YELLOW}⚠️  Skipped (not a recognised video): %s${RESET}\n" \
                    "${p##*/}" >&2
            fi
        else
            printf "${RED}❌ Not found or unreadable: %s${RESET}\n" "$p" >&2
        fi
    done

    _COLLECT_BASE_DIR="$_cvi_first_base"
}

# prompt_and_collect <prompt-message> <output-array-name>
# Shows a drag-and-drop prompt, reads input, calls collect_video_inputs.
# Re-prompts once if nothing is collected.
prompt_and_collect() {
    local prompt_msg="$1"
    local out_name="$2"

    printf "%s\n" "$prompt_msg"
    local _pac_raw
    read -r _pac_raw

    collect_video_inputs "$_pac_raw" "$out_name"

    # If empty, give one retry
    local -n _pac_ref="$out_name"
    if [[ ${#_pac_ref[@]} -eq 0 ]]; then
        printf "${YELLOW}⚠️  Nothing found. Try again:${RESET}\n"
        read -r _pac_raw
        collect_video_inputs "$_pac_raw" "$out_name"
    fi
}

# ==============================================================================
# DUPLICATE DETECTION
# ==============================================================================

typeset -gA file_hashes

is_duplicate() {
    local file="$1"
    local filesize
    filesize=$(stat -f "%z" "$file" 2>/dev/null)
    local partial_hash
    partial_hash=$(head -c 1048576 "$file" | shasum -a 256 | awk '{print $1}')
    local file_key="${filesize}_${partial_hash}"
    if [[ -n "${file_hashes[$file_key]}" ]]; then
        return 0
    else
        file_hashes[$file_key]="$file"
        return 1
    fi
}

handle_duplicate() {
    local file="$1"
    local base_dir="$2"
    local dup_dir="${base_dir}/Duplicates"
    [[ ! -d "$dup_dir" ]] && mkdir -p "$dup_dir"
    local filename="${file:t}"
    local dest="${dup_dir}/${filename}"
    local counter=1
    local name="${filename%.*}"
    local ext="${filename##*.}"
    while [[ -e "$dest" ]]; do
        dest="${dup_dir}/${name}_${counter}.${ext}"
        ((counter++))
    done
    if mv "$file" "$dest" 2>/dev/null; then
        printf "${YELLOW}👯 Duplicate moved: ${file:t} → Duplicates/${dest:t}${RESET}\n"
        ((stats[total_success]++))
    else
        ((stats[total_failure]++))
        printf "${ERROR}❌ Failed to move duplicate: ${file:t}${RESET}\n" >&2
    fi
}

# ==============================================================================
# SESSION MANAGEMENT
# ==============================================================================

typeset -g SESSION_STATE_FILE="$HOME/.promov_session"
typeset -gA SESSION_PROCESSED_FILES

save_session_state() {
    local input_folder="$1" mode="$2" prefix="$3" processed_count="$4"
    local temp_state_file="${SESSION_STATE_FILE}.tmp"
    cat > "$temp_state_file" << EOF
# ProMov Session State - $(date)
SESSION_INPUT_FOLDER="$input_folder"
SESSION_MODE="$mode"
SESSION_PREFIX="$prefix"
SESSION_PROCESSED_COUNT="$processed_count"
TIMESTAMP="$(date +%s)"
EOF
    for hash in "${(@k)file_hashes}"; do
        echo "SESSION_PROCESSED_FILES[$hash]=1" >> "$temp_state_file"
    done
    mv "$temp_state_file" "$SESSION_STATE_FILE" 2>/dev/null
}

check_for_resume() {
    [[ ! -f "$SESSION_STATE_FILE" ]] && return 1
    source "$SESSION_STATE_FILE" 2>/dev/null
    if [[ -n "$SESSION_MODE" && -n "$SESSION_INPUT_FOLDER" ]]; then
        if [[ $FORCE_RESUME -eq 1 ]]; then return 0; fi
        printf "\n${CYAN}🔄 Previous session detected for: ${SESSION_INPUT_FOLDER}${RESET}\n"
        read -r answer?"${WHITE}Resume it? (Y/n): ${RESET}"
        [[ "${answer:-Y}" =~ ^[Yy]$ ]] && return 0
    fi
    return 1
}

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

[[ $EUID -eq 0 ]] && { printf "%s\n" "${CROSS} Don't run as root" >&2; exit 1; }
[[ -z "$TMPDIR" ]] && export TMPDIR="/tmp"

# --- Command Line Arguments ---
zmodload zsh/zutil
zparseopts -D -E -F -- \
    h=help    -help=help    \
    v=verbose -verbose=verbose \
    d=debug   -debug=debug  \
    f=force   -force=force  \
    r=resume  -resume=resume \
    n=dryrun  -dry-run=dryrun \
    b=backup  -backup=backup \
    p=preview -preview=preview \
    -no-cache=nocache \
    || { printf "%s\n" "Error parsing options" >&2; exit 1; }

if [[ -n "$help" ]]; then
    cat << EOF
ProVid - Professional Video Organizer v3.1
Usage: $(basename "$0") [options]

Options:
  -h, --help      Show this help message and exit
  -v, --verbose   Enable verbose output
  -d, --debug     Enable debug output (very detailed)
  -f, --force     Force operations without prompting
  -r, --resume    Resume previous session if available
  -n, --dry-run   Simulate operations without making changes
  -b, --backup    Copy files instead of moving (keeps originals)
  -p, --preview   Show summary of changes before processing
  --no-cache      Skip metadata cache (re-read all files)

Description:
  ProVid organizes video files by resolution, orientation, and frame rate.
  ALL modes accept a folder or individual video files via drag-and-drop.
  Detects iPhone models and GPS data. Duplicate files are auto-detected.
EOF
    exit 0
fi

# --- Feature Flags ---
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_FATAL=4
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO

if [[ -n "$debug" ]]; then
    CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
    printf "%s\n" "${BLUE}${INFO} Debug mode enabled${RESET}"
elif [[ -n "$verbose" ]]; then
    CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
    printf "%s\n" "${BLUE}${INFO} Verbose mode enabled${RESET}"
fi

FORCE_RESUME=0
[[ -n "$resume" ]] && { FORCE_RESUME=1; printf "%s\n" "${BLUE}${INFO} Resume mode enabled${RESET}"; }

FORCE_MODE=0
[[ -n "$force" ]] && { FORCE_MODE=1; printf "%s\n" "${YELLOW}${WARNING} Force mode (skipping confirmations)${RESET}"; }

DRY_RUN=0
[[ -n "$dryrun" ]] && { DRY_RUN=1; printf "%s\n" "${CYAN}🔍 Dry-run mode (no changes made)${RESET}"; }

BACKUP_MODE=0
[[ -n "$backup" ]] && { BACKUP_MODE=1; printf "%s\n" "${GREEN}💾 Backup mode (files copied, not moved)${RESET}"; }

PREVIEW_MODE=0
[[ -n "$preview" ]] && { PREVIEW_MODE=1; printf "%s\n" "${CYAN}👁️ Preview mode${RESET}"; }

USE_CACHE=1
CACHE_FILE="$HOME/.promov_metadata_cache"
[[ -n "$nocache" ]] && { USE_CACHE=0; printf "%s\n" "${YELLOW}${WARNING} Cache disabled${RESET}"; }

typeset -g PROCESSING_START_TIME=0
typeset -g TOTAL_PROCESSING_TIME=0
typeset -g FILES_PROCESSED_FOR_ETA=0
typeset -g TOOL_MODE=0
typeset -g start_time=$SECONDS

# --- Zsh Options ---
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt EXTENDED_GLOB    # enables ## (one-or-more) and # (zero-or-more) in globs
setopt NO_NOMATCH

# --- Stats / Tracking ---
typeset -A move_history
typeset -A stats
stats[total_processed]=0
stats[apple_detected]=0
stats[gps_found]=0
stats[total_success]=0
stats[total_failure]=0
stats[skipped_count]=0
stats[fps_30]=0
stats[fps_60]=0
stats[W30]=0
stats[V30]=0
stats[W60]=0
stats[V60]=0
stats[camera_lens]=0
typeset -A resolution_counters
typeset -A resolution_summary
typeset -A checksum_cache
typeset -A original_paths
typeset -A original_filenames_map
typeset -a summary

TEMP_DIR="${TMPDIR}/promov_$RANDOM"
mkdir -p "$TEMP_DIR"
mkdir -p "$TEMP_DIR/logs"

# ==============================================================================
# LOGGING
# ==============================================================================

log() {
    local level=$1
    local message=$2
    if (( level >= CURRENT_LOG_LEVEL )); then
        local color="" emoji=""
        case $level in
            $LOG_LEVEL_INFO)  color="$BLUE";   emoji="$INFO" ;;
            $LOG_LEVEL_WARN)  color="$YELLOW"; emoji="$WARNING" ;;
            $LOG_LEVEL_ERROR) color="$RED";    emoji="$CROSS" ;;
            $LOG_LEVEL_FATAL) color="$ERROR";  emoji="$CROSS" ;;
        esac
        if (( level >= LOG_LEVEL_WARN )); then
            printf "${color}${emoji} %s${RESET}\n" "$message" >&2
        fi
    fi
}

# ==============================================================================
# PROGRESS BAR
# ==============================================================================

display_progress_bar() {
    local current=$1 total=$2 filename="$3"
    local width=25
    local percent=$((current * 100 / total))
    local num_filled=$((percent * width / 100))
    local bar="" i
    for ((i=0; i<width; i++)); do
        (( i < num_filled )) && bar+="█" || bar+="░"
    done
    local eta_str=""
    if (( FILES_PROCESSED_FOR_ETA > 0 && PROCESSING_START_TIME > 0 )); then
        local elapsed=$((SECONDS - PROCESSING_START_TIME))
        local avg_time=$((elapsed / FILES_PROCESSED_FOR_ETA))
        local remaining=$((total - current))
        local eta_seconds=$((avg_time * remaining))
        if (( eta_seconds > 3600 )); then
            eta_str=$(printf "%dh %dm" $((eta_seconds/3600)) $(((eta_seconds%3600)/60)))
        elif (( eta_seconds > 60 )); then
            eta_str=$(printf "%dm %ds" $((eta_seconds/60)) $((eta_seconds%60)))
        else
            eta_str=$(printf "%ds" $eta_seconds)
        fi
        eta_str=" ~${eta_str} left"
    fi
    local display_name="${filename##*/}"
    [[ ${#display_name} -gt 28 ]] && display_name="${display_name:0:25}..."
    printf "\r${BLUE}[%s] %d/%d (%d%%)${eta_str} ${WHITE}%s${RESET}     " \
        "$bar" "$current" "$total" "$percent" "$display_name"
}

# ==============================================================================
# METADATA CACHE
# ==============================================================================

typeset -gA metadata_cache

load_metadata_cache() {
    [[ $USE_CACHE -eq 0 || ! -f "$CACHE_FILE" ]] && return
    while IFS='|' read -r filepath mtime resolution orientation fps \
                              has_apple has_gps has_lens; do
        [[ -z "$filepath" ]] && continue
        metadata_cache["$filepath"]="${mtime}|${resolution}|${orientation}|${fps}|${has_apple}|${has_gps}|${has_lens}"
    done < "$CACHE_FILE"
    log $LOG_LEVEL_DEBUG "Loaded ${#metadata_cache[@]} cache entries"
}

save_metadata_cache() {
    [[ $USE_CACHE -eq 0 ]] && return
    local temp_cache="${CACHE_FILE}.tmp"
    : > "$temp_cache"
    local filepath
    for filepath in "${(@k)metadata_cache}"; do
        printf '%s|%s\n' "$filepath" "${metadata_cache[$filepath]}" >> "$temp_cache"
    done
    mv "$temp_cache" "$CACHE_FILE" 2>/dev/null
    log $LOG_LEVEL_DEBUG "Saved ${#metadata_cache[@]} cache entries"
}

get_cached_metadata() {
    local filepath="$1"
    [[ $USE_CACHE -eq 0 ]] && return 1
    local cached="${metadata_cache[$filepath]}"
    [[ -z "$cached" ]] && return 1
    local cached_mtime="${cached%%|*}"
    local current_mtime
    current_mtime=$(stat -f %m "$filepath" 2>/dev/null)
    if [[ "$cached_mtime" == "$current_mtime" ]]; then
        printf '%s' "${cached#*|}"
        return 0
    fi
    return 1
}

cache_metadata() {
    [[ $USE_CACHE -eq 0 ]] && return
    local filepath="$1" resolution="$2" orientation="$3" fps="$4" \
          has_apple="$5" has_gps="$6" has_lens="$7"
    local mtime
    mtime=$(stat -f %m "$filepath" 2>/dev/null)
    metadata_cache["$filepath"]="${mtime}|${resolution}|${orientation}|${fps}|${has_apple}|${has_gps}|${has_lens}"
}

# ==============================================================================
# CLEANUP / ROLLBACK
# ==============================================================================

cleanup_and_exit() {
    printf "\n"
    if [[ $TOOL_MODE -eq 0 ]]; then
        show_final_stats
        delete_empty_directories
    fi
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        printf "%s\n" "${BLUE}🧹 Temporary files cleaned up.${RESET}"
    fi
    printf "%s\n" "${SUCCESS}${CHECK} Session complete.${RESET}"
}

rollback() {
    printf "\n%s\n" "${ERROR}🔙 Initiating rollback...${RESET}" >&2
    local recovery_log="$TEMP_DIR/recovery_log_$(date +%Y%m%d_%H%M%S).txt"
    touch "$recovery_log" 2>/dev/null
    {
        printf "Recovery initiated at $(date)\n"
        printf "Total operations to recover: ${#move_history[@]}\n"
    } >> "$recovery_log" 2>/dev/null
    local success_count=0 fail_count=0 new_path orig_path
    if (( ${#move_history[@]} > 0 )); then
        for new_path in "${(@k)move_history}"; do
            orig_path="${move_history[$new_path]}"
            if [[ -f "$new_path" ]]; then
                local orig_dir="${orig_path%/*}"
                [[ ! -d "$orig_dir" ]] && mkdir -p "$orig_dir" 2>/dev/null
                if mv "$new_path" "$orig_path" 2>/dev/null; then
                    printf "%s\n" "${SUCCESS}✅ Rolled back: ${new_path:t}${RESET}" >&2
                    ((success_count++))
                else
                    printf "%s\n" "${ERROR}❌ Failed to rollback: ${new_path:t}${RESET}" >&2
                    ((fail_count++))
                fi
            else
                ((fail_count++))
            fi
        done
    else
        printf "%s\n" "${BLUE}ℹ️ No moves to revert.${RESET}" >&2
    fi
    exit 3
}

# ==============================================================================
# DEPENDENCY CHECK
# ==============================================================================

check_dependencies() {
    local missing=()
    local tool
    for tool in exiftool mediainfo bc shasum stat; do
        command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
    done
    if (( ${#missing[@]} )); then
        printf "%s\n" "${RED}${CROSS} Missing required tools:${RESET}" >&2
        for tool in "${missing[@]}"; do printf "  - %s\n" "$tool" >&2; done
        printf "\n%s\n" "${CYAN}Install: brew install exiftool mediainfo bc${RESET}" >&2
        exit 1
    fi
    local exif_ver
    exif_ver=$(exiftool -ver 2>/dev/null)
    if [[ -n "$exif_ver" && "${exif_ver%.*}" -lt "12" ]]; then
        printf "%s\n" "${YELLOW}⚠️ ExifTool v$exif_ver found. v12+ recommended.${RESET}"
    fi
    printf "%s\n" "${SUCCESS}${CHECK} Dependencies satisfied${RESET}"
}

# ==============================================================================
# FORENSIC AUDIT (used by Exiff / OG/Edits tool)
# ==============================================================================

run_comprehensive_audit() {
    local target="$1"
    printf "\n${ORANGE}🛡️  STARTING FORENSIC METADATA AUDIT...${RESET}\n"

    exiftool -api QuickTimeUTC=1 -n \
      -if '$Make eq "Apple" and $Model =~ /iPhone/ and $Software =~ /^[0-9]+\.[0-9]/ and not defined $CompressorName and abs($FileModifyDate - $CreateDate) < 3600' \
      -csv -r \
      -FileName -Make -Model -Software -CompressorName \
      -CreateDate -FileModifyDate \
      -ImageWidth -ImageHeight -AspectRatio \
      -VideoFrameRate -Duration -AvgBitrate \
      -GPSLatitude -GPSLongitude -FileSize \
      "$target" > "${target}/audit_STRICT_originals.csv"

    exiftool -api QuickTimeUTC=1 -n \
      -if '$Software =~ /QuickTime/ or defined $CompressorName or abs($FileModifyDate - $CreateDate) > 3600' \
      -csv -r \
      -FileName -Make -Model -Software -CompressorName \
      -CreateDate -FileModifyDate \
      -ImageWidth -ImageHeight -AspectRatio \
      -VideoFrameRate -Duration -AvgBitrate \
      -GPSLatitude -GPSLongitude -FileSize \
      "$target" > "${target}/audit_EDIT_indicators.csv"

    exiftool -api QuickTimeUTC=1 -n \
      -if '$ImageWidth % 16 != 0 or $ImageHeight % 16 != 0 or ($ImageWidth/$ImageHeight != 16/9 and $ImageWidth/$ImageHeight != 4/3 and $ImageWidth/$ImageHeight != 3/4 and $ImageWidth/$ImageHeight != 9/16)' \
      -csv -r \
      -FileName -Make -Model -Software -CompressorName \
      -CreateDate -FileModifyDate \
      -ImageWidth -ImageHeight -AspectRatio \
      -VideoFrameRate -Duration -AvgBitrate \
      -GPSLatitude -GPSLongitude -FileSize \
      "$target" > "${target}/audit_UNUSUAL_dimensions.csv"

    exiftool -api QuickTimeUTC=1 -n \
      -if 'not defined $Make or $Make ne "Apple"' \
      -csv -r \
      -FileName -Make -Model -Software -CompressorName \
      -CreateDate -FileModifyDate \
      -ImageWidth -ImageHeight -AspectRatio \
      -VideoFrameRate -Duration -AvgBitrate \
      -GPSLatitude -GPSLongitude -FileSize \
      "$target" > "${target}/audit_NON_APPLE_metadata.csv"

    printf "${SUCCESS}✅ Forensic CSVs exported to: %s${RESET}\n" "$target"
}

# ==============================================================================
# PATH NORMALIZER  (legacy — used by Exiff folder resolution)
# ==============================================================================

normalize_path() {
    local input_path="$1"
    if [[ -z "$input_path" ]]; then
        printf "%s\n" "${ERROR}${CROSS} Error: No folder path provided${RESET}" >&2
        exit 1
    fi
    log $LOG_LEVEL_DEBUG "Original path: '$input_path'"
    # Sanitize through the drag-drop cleaner
    input_path=$(sanitize_dropped_path "$input_path")
    # Make absolute
    if [[ "$input_path" != /* && "$input_path" != /Volumes/* ]]; then
        input_path="$PWD/$input_path"
    fi
    # Collapse double-slashes (sanitize_dropped_path already does this, belt-and-braces)
    while [[ "$input_path" == *'//'* ]]; do input_path="${input_path//\/\//\/}"; done
    [[ "$input_path" != "/" ]] && input_path="${input_path%/}"
    log $LOG_LEVEL_DEBUG "Normalized path: '$input_path'"
    if [[ ! -d "$input_path" ]]; then
        if [[ $FORCE_MODE -eq 1 ]]; then
            mkdir -p "$input_path" 2>/dev/null \
                && printf "%s\n" "${SUCCESS}${CHECK} Directory created: $input_path${RESET}" \
                || { printf "%s\n" "${ERROR}${CROSS} Failed to create: '$input_path'${RESET}" >&2; exit 1; }
        else
            printf "%s\n" "${ERROR}${CROSS} Not a valid directory: '$input_path'${RESET}" >&2
            printf "%s\n" "${INFO} Use -f flag to create directories automatically${RESET}" >&2
            exit 1
        fi
    fi
    printf '%s' "$input_path"
}

# ==============================================================================
# TITLE SANITIZER
# ==============================================================================

sanitize_title() {
    local title="$1"
    # Remove filesystem-unsafe characters
    title="${title//[\/\:\*\?\"\<\>\|]/ }"
    # Collapse runs of whitespace to a single space
    # EXTENDED_GLOB is set: [[:space:]]## means "one or more whitespace chars"
    title="${title//[[:space:]]##/ }"
    title="${title## }"   # strip leading space (## = remove longest prefix " ")
    title="${title%% }"   # strip trailing space
    # Title-case each word
    printf '%s' "$title" | awk '{
        for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) tolower(substr($i,2))}
        print
    }'
}

# ==============================================================================
# iPHONE MODEL EXTRACTION
# ==============================================================================

extract_iphone_model() {
    local model_string="$1"
    local extracted_model=""
    local model_lower="${(L)model_string}"
    case "$model_lower" in
        (*"iphone 16 pro max"*) extracted_model="16 Pro Max" ;;
        (*"iphone 16 pro"*)     extracted_model="16 Pro" ;;
        (*"iphone 16 plus"*)    extracted_model="16 Plus" ;;
        (*"iphone 16"*)         extracted_model="16" ;;
        (*"iphone 15 pro max"*) extracted_model="15 Pro Max" ;;
        (*"iphone 15 pro"*)     extracted_model="15 Pro" ;;
        (*"iphone 15 plus"*)    extracted_model="15 Plus" ;;
        (*"iphone 15"*)         extracted_model="15" ;;
        (*"iphone 14 pro max"*) extracted_model="14 Pro Max" ;;
        (*"iphone 14 pro"*)     extracted_model="14 Pro" ;;
        (*"iphone 14 plus"*)    extracted_model="14 Plus" ;;
        (*"iphone 14"*)         extracted_model="14" ;;
        (*"iphone 13 pro max"*) extracted_model="13 Pro Max" ;;
        (*"iphone 13 pro"*)     extracted_model="13 Pro" ;;
        (*"iphone 13 mini"*)    extracted_model="13 Mini" ;;
        (*"iphone 13"*)         extracted_model="13" ;;
        (*"iphone 12 pro max"*) extracted_model="12 Pro Max" ;;
        (*"iphone 12 pro"*)     extracted_model="12 Pro" ;;
        (*"iphone 12 mini"*)    extracted_model="12 Mini" ;;
        (*"iphone 12"*)         extracted_model="12" ;;
        (*"iphone 11 pro max"*) extracted_model="11 Pro Max" ;;
        (*"iphone 11 pro"*)     extracted_model="11 Pro" ;;
        (*"iphone 11"*)         extracted_model="11" ;;
        (*"iphone xs max"*)     extracted_model="XS Max" ;;
        (*"iphone xs"*)         extracted_model="XS" ;;
        (*"iphone xr"*)         extracted_model="XR" ;;
        (*"iphone x"*)          extracted_model="X" ;;
        (*"iphone 8 plus"*)     extracted_model="8 Plus" ;;
        (*"iphone 8"*)          extracted_model="8" ;;
        (*"iphone 7 plus"*)     extracted_model="7 Plus" ;;
        (*"iphone 7"*)          extracted_model="7" ;;
        (*"iphone 6s plus"*)    extracted_model="6s Plus" ;;
        (*"iphone 6s"*)         extracted_model="6s" ;;
        (*"iphone 6 plus"*)     extracted_model="6 Plus" ;;
        (*"iphone 6"*)          extracted_model="6" ;;
        (*"iphone se"*)         extracted_model="SE" ;;
        (*"iphone 5s"*)         extracted_model="5s" ;;
        (*"iphone 5c"*)         extracted_model="5c" ;;
        (*"iphone 5"*)          extracted_model="5" ;;
        (*"iphone 4s"*)         extracted_model="4S" ;;
        (*"iphone 4"*)          extracted_model="4" ;;
        (*"iphone 3g"*)         extracted_model="3G" ;;
        (*"iphone"*)            extracted_model="📱" ;;
    esac
    printf '%s' "$extracted_model"
}

extract_iphone_model_simple() {
    local model_string="$1"
    local extracted_model=""
    local model_lower="${(L)model_string}"
    case "$model_lower" in
        (*"iphone 16"*) extracted_model="16" ;;
        (*"iphone 15"*) extracted_model="15" ;;
        (*"iphone 14"*) extracted_model="14" ;;
        (*"iphone 13"*) extracted_model="13" ;;
        (*"iphone 12"*) extracted_model="12" ;;
        (*"iphone 11"*) extracted_model="11" ;;
        (*"iphone xs"*) extracted_model="XS" ;;
        (*"iphone xr"*) extracted_model="XR" ;;
        (*"iphone x"*)  extracted_model="X" ;;
        (*"iphone 8"*)  extracted_model="8" ;;
        (*"iphone 7"*)  extracted_model="7" ;;
        (*"iphone 6s"*) extracted_model="6s" ;;
        (*"iphone 6"*)  extracted_model="6" ;;
        (*"iphone se"*) extracted_model="SE" ;;
        (*"iphone 5s"*) extracted_model="5s" ;;
        (*"iphone 5c"*) extracted_model="5c" ;;
        (*"iphone 5"*)  extracted_model="5" ;;
        (*"iphone 4s"*) extracted_model="4S" ;;
        (*"iphone 4"*)  extracted_model="4" ;;
        (*"iphone 3g"*) extracted_model="3G" ;;
        (*"iphone"*)    extracted_model="📱" ;;
    esac
    printf '%s' "$extracted_model"
}

check_iphone_metadata() {
    local file="$1" exif_meta="$2"
    local has_apple_info=0 has_gps_info=0
    local device_display="" gps_display=""
    local camera_status_icon_raw="${CROSS}" gps_status_icon_raw="${CROSS}"
    local iphone_model_short=""
    if [[ ! -r "$file" ]]; then
        printf "%s|%s|%s|%s|%s|%s|%s" \
            "0" "0" "" "" "" "$camera_status_icon_raw" "$gps_status_icon_raw"
        return
    fi
    local full_device_model=""
    local has_lens_iphone has_make_apple has_model_iphone has_any_iphone has_any_apple
    has_lens_iphone=$(echo "$exif_meta" | grep -qi 'LensModel.*iPhone' && echo "1" || echo "0")
    has_make_apple=$(echo "$exif_meta"  | grep -qi 'Make.*Apple'       && echo "1" || echo "0")
    has_model_iphone=$(echo "$exif_meta"| grep -qi 'Model.*iPhone'     && echo "1" || echo "0")
    has_any_iphone=$(echo "$exif_meta"  | grep -qi 'iPhone'            && echo "1" || echo "0")
    has_any_apple=$(echo "$exif_meta"   | grep -qi 'Apple'             && echo "1" || echo "0")

    if [[ "$has_lens_iphone" == "1" ]]; then
        full_device_model=$(echo "$exif_meta" | grep -i 'LensModel' | head -n1 | awk -F': ' '{print $2}')
        has_apple_info=1
    elif [[ "$has_make_apple" == "1" && "$has_model_iphone" == "1" ]]; then
        local make model
        make=$(echo "$exif_meta" | grep -i '^Make'  | head -n1 | awk -F': ' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        model=$(echo "$exif_meta"| grep -i '^Model' | head -n1 | awk -F': ' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        full_device_model="${make}${make:+ }${model}"
        has_apple_info=1
    elif [[ "$has_any_iphone" == "1" ]]; then
        full_device_model=$(echo "$exif_meta" | grep -i 'iPhone' | head -n1 | awk -F': ' '{print $2}')
        has_apple_info=1
    elif [[ "$has_any_apple" == "1" ]]; then
        full_device_model="Apple Device"
        has_apple_info=1
    fi

    if (( has_apple_info == 1 )); then
        camera_status_icon_raw="${CHECK}"
        if [[ -n "$full_device_model" ]]; then
            iphone_model_short=$(extract_iphone_model_simple "$full_device_model")
            if [[ -z "$iphone_model_short" && "$full_device_model" == *"iPhone"* ]]; then
                iphone_model_short=$(echo "$full_device_model" \
                    | grep -o 'iPhone [0-9XRS]*' | grep -o '[0-9XRS]*' | head -1)
                [[ -z "$iphone_model_short" ]] && iphone_model_short="📱"
            fi
            device_display="$full_device_model"
        fi
    fi
    if echo "$exif_meta" | grep -qi -E 'GPSCoordinates|GPSPosition|GPS|Latitude|Longitude'; then
        gps_display="${GLOBE}"
        has_gps_info=1
        gps_status_icon_raw="${CHECK}"
    fi
    printf "%s|%s|%s|%s|%s|%s|%s" \
        "$has_apple_info" "$has_gps_info" "$iphone_model_short" \
        "$device_display" "$gps_display" \
        "$camera_status_icon_raw" "$gps_status_icon_raw"
}

# ==============================================================================
# FOLDER STRUCTURE CREATION
# ==============================================================================

create_folder_structure() {
    local base="$1" mode="$2"
    if [[ ! -d "$base" ]]; then
        mkdir -p "$base" 2>/dev/null \
            || { printf "%s\n" "${ERROR}${CROSS} Cannot create base dir: $base${RESET}" >&2; return 1; }
    fi
    if [[ ! -w "$base" ]]; then
        printf "%s\n" "${ERROR}${CROSS} No write permission: $base${RESET}" >&2; return 1
    fi
    log $LOG_LEVEL_INFO "Creating folder structure for mode: $mode"
    local create_error=0
    case "$mode" in
        "VidRes"|"KeepName")
            local res
            for res in "4K" "1080p" "720p" "HD" "SD"; do
                mkdir -p "$base/$res" 2>/dev/null \
                    || { log $LOG_LEVEL_ERROR "Failed: $base/$res"; create_error=1; }
            done
            ;;
        "MaxVid")
            local res orient fps
            for res in "4K" "1080p" "720p" "HD" "SD"; do
                for orient in "W" "V"; do
                    for fps in "30" "60"; do
                        mkdir -p "$base/${res} ${orient} ${fps}" 2>/dev/null \
                            || { log $LOG_LEVEL_ERROR "Failed: $base/${res} ${orient} ${fps}"; create_error=1; }
                    done
                done
            done
            ;;
        "ProMax")
            local res orient
            for res in "4K" "1080p" "720p" "HD" "SD"; do
                for orient in "W" "V"; do
                    mkdir -p "$base/${res} ${orient}" 2>/dev/null \
                        || { log $LOG_LEVEL_ERROR "Failed: $base/${res} ${orient}"; create_error=1; }
                done
            done
            ;;
        "ProVid"|"EmojiVid")
            # Flat modes — no subfolders needed
            log $LOG_LEVEL_DEBUG "$mode mode — flat, no subfolders created"
            ;;
        *)
            log $LOG_LEVEL_ERROR "Unknown sorting mode: $mode"
            printf "%s\n" "${ERROR}${CROSS} Unknown mode: $mode${RESET}" >&2
            return 1
            ;;
    esac
    if [[ $create_error -eq 1 ]]; then
        printf "%s\n" "${ERROR}${CROSS} Some directories could not be created.${RESET}" >&2
        return 1
    fi
    return 0
}

# ==============================================================================
# VIDEO CLASSIFICATION
# ==============================================================================

classify_video() {
    local exif_data="$1" mi_width="$2" mi_height="$3" mi_fps="$4"
    local width height rotation fps

    width=$(echo "$exif_data"    | awk -F': ' '/ImageWidth/     {print $2; exit}')
    height=$(echo "$exif_data"   | awk -F': ' '/ImageHeight/    {print $2; exit}')
    rotation=$(echo "$exif_data" | awk -F': ' '/Rotation/       {print $2; exit}')
    fps=$(echo "$exif_data"      | awk -F': ' '/VideoFrameRate/ {print $2; exit}' | tr -d ' ')

    ! [[ "$width"  =~ ^[0-9]+$ ]] || (( width  == 0 )) && [[ "$mi_width"  =~ ^[0-9]+$ ]] && width="$mi_width"
    ! [[ "$height" =~ ^[0-9]+$ ]] || (( height == 0 )) && [[ "$mi_height" =~ ^[0-9]+$ ]] && height="$mi_height"
    [[ -z "$fps" || "$fps" == "0" ]] || ! [[ "$fps" =~ ^[0-9.]+$ ]] && [[ "$mi_fps" =~ ^[0-9.]+$ ]] && fps="$mi_fps"

    [[ "$width"    =~ ^[0-9]+$ ]] || width=0
    [[ "$height"   =~ ^[0-9]+$ ]] || height=0
    [[ "$rotation" =~ ^[0-9]+$ ]] || rotation=0

    if [[ "$rotation" -eq 90 || "$rotation" -eq 270 ]]; then
        local tmp=$width; width=$height; height=$tmp
    fi

    local resolution
    if   (( width >= 3840 || height >= 3840 || width >= 2160 || height >= 2160 )); then resolution="4K"
    elif (( width == 1920 || height == 1920 || width == 1080 || height == 1080 )); then resolution="1080p"
    elif (( width == 1280 || height == 1280 || width == 720  || height == 720  )); then resolution="720p"
    elif (( width > 1080  || height > 1080 ));                                       then resolution="HD"
    else                                                                                   resolution="SD"
    fi

    local orientation
    orientation=$([[ "$height" -gt "$width" ]] && echo "V" || echo "W")

    # BUCKET RULE: >45 fps → "60" bucket (59.94, 60.00, 120…); ≤45 → "30" bucket
    local framerate=30
    if [[ "$fps" =~ ^[0-9.]+$ ]]; then
        (( $(echo "$fps > 45" | bc -l 2>/dev/null) )) && framerate=60
    fi

    printf "%s|%s|%s|%s" "$resolution" "$orientation" "$framerate" "$fps"
}

get_framerate_category() {
    local raw_fps="$1"
    local framerate=30
    if [[ "$raw_fps" =~ ^[0-9.]+$ ]]; then
        (( $(echo "$raw_fps > 45" | bc -l 2>/dev/null) )) && framerate=60
    fi
    printf '%s' "$framerate"
}

convert_time_to_seconds() {
    local time_str="$1"
    local hours=0 minutes=0 seconds=0 milliseconds=0
    if   [[ "$time_str" =~ ([0-9]+):([0-9]+):([0-9]+)\.([0-9]+) ]]; then
        hours=${match[1]}; minutes=${match[2]}; seconds=${match[3]}; milliseconds=${match[4]}
    elif [[ "$time_str" =~ ([0-9]+):([0-9]+)\.([0-9]+) ]]; then
        minutes=${match[1]}; seconds=${match[2]}; milliseconds=${match[3]}
    elif [[ "$time_str" =~ ([0-9]+)\.([0-9]+) ]]; then
        seconds=${match[1]}; milliseconds=${match[2]}
    else
        [[ "$time_str" =~ ^[0-9.]+$ ]] && printf "%.2f" "$time_str" || printf "0.00"
        return
    fi
    local total
    total=$(echo "$hours * 3600 + $minutes * 60 + $seconds + $milliseconds / 1000.0" | bc -l 2>/dev/null)
    printf "%.2f" "$total"
}

# ==============================================================================
# EDIT DETECTION (ffprobe exact frame-rate)
# ==============================================================================

is_edited_fps() {
    local file="$1"
    command -v ffprobe >/dev/null 2>&1 || return 1
    local fraction
    fraction=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=avg_frame_rate \
        -of csv=p=0 "$file" 2>/dev/null)
    [[ "$fraction" == */* ]] || return 1
    local exact_fps
    exact_fps=$(awk -F/ '{if($2>0) printf "%.6f", $1/$2; else print "0.000000"}' \
        <<< "$fraction")
    [[ "$exact_fps" == "30.000000" || "$exact_fps" == "60.000000" ]]
}

# ==============================================================================
# SANITIZE FILENAME COMPONENT
# ==============================================================================

# sanitize_filename <raw-name>
# Removes/replaces characters that are unsafe in filenames.
# Collapses whitespace runs, trims edges, enforces max length.
sanitize_filename() {
    local name="$1"
    local max_len="${2:-200}"
    # Replace forbidden filesystem characters with underscore
    name="${name//[\/\\\:\*\?\"\<\>\|]/_}"
    # Collapse runs of whitespace (EXTENDED_GLOB: [[:space:]]## = 1-or-more)
    name="${name//[[:space:]]##/ }"
    # Collapse runs of underscores
    name="${name//_##/_}"
    # Trim leading/trailing whitespace and underscores
    name="${name##[[:space:]_]#}"
    name="${name%%[[:space:]_]#}"
    # Enforce max length (preserve extension if present)
    if [[ ${#name} -gt $max_len ]]; then
        local ext="${name##*.}"
        local base="${name%.*}"
        if [[ "$ext" != "$name" && ${#ext} -lt 10 ]]; then
            base="${base:0:$((max_len - ${#ext} - 1))}"
            name="${base}.${ext}"
        else
            name="${name:0:$max_len}"
        fi
    fi
    printf '%s' "$name"
}

# ==============================================================================
# PROCESS VIDEO (core rename/move logic)
# ==============================================================================

process_video() {
    local file="$1" index="$2" mode="$3"

    if is_duplicate "$file" 2>/dev/null; then
        if [[ $DRY_RUN -eq 1 ]]; then
            printf "${YELLOW}[DRY-RUN][DUPLICATE]${RESET} %s\n" "${file##*/}"
            ((stats[duplicates_found]++))
        else
            handle_duplicate "$file" "$inputFolder"
        fi
        return 0
    fi

    ((stats[total_processed]++))
    local exif_data
    exif_data=$($EXIFTOOL "${EXIFTOOL_ARGS[@]}" "$file")
    local mi_width mi_height mi_fps
    mi_width=$(mediainfo  --Inform="Video;%Width%"     "$file" 2>/dev/null)
    mi_height=$(mediainfo --Inform="Video;%Height%"    "$file" 2>/dev/null)
    mi_fps=$(mediainfo    --Inform="Video;%FrameRate%" "$file" 2>/dev/null)

    local classification_result actual_resolution orientation framerate_category exif_fps
    classification_result=$(classify_video "$exif_data" "$mi_width" "$mi_height" "$mi_fps")
    IFS='|' read -r actual_resolution orientation framerate_category exif_fps \
        <<< "$classification_result"

    if [[ -z "$actual_resolution" || "$actual_resolution" == "0" ]]; then
        log $LOG_LEVEL_WARN "Could not determine resolution for ${file##*/}, defaulting to SD"
        actual_resolution="SD"
        orientation="W"
    fi

    # --- Emoji indicators ---
    local temp_emojis=""
    if echo "$exif_data" | grep -qiE 'Make.*:.*Apple' || \
       echo "$exif_data" | grep -qiE 'Model.*:.*iPhone'; then
        temp_emojis+="$IPHONE"
        ((stats[apple_detected]++))
    fi
    if echo "$exif_data" | grep -qiE 'GPS(Coordinates|Position|Latitude|Longitude).*:.*[0-9]'; then
        temp_emojis+="$GPS"
        ((stats[gps_found]++))
    fi
    if echo "$exif_data" | grep -qiE 'LensModel.*:.*[A-Za-z0-9]'; then
        temp_emojis+="$CAMERA"
        ((stats[camera_lens]++))
    fi

    # Edit detection via ffprobe exact fraction
    local mediainfo_fps
    mediainfo_fps=$(mediainfo --Inform="Video;%FrameRate%" "$file" 2>/dev/null)
    is_edited_fps "$file" && temp_emojis+="$EDIT"

    # Bucket FPS for folder sorting (separate from edit detection)
    if [[ -n "$mediainfo_fps" && "$mediainfo_fps" =~ ^[0-9.]+$ ]]; then
        framerate_category=$(get_framerate_category "$mediainfo_fps")
    fi

    if [[ "$framerate_category" == "60" || "$framerate_category" -eq 60 ]]; then
        ((stats[fps_60]++))
    else
        ((stats[fps_30]++))
    fi
    local orient_fps_key="${orientation}${framerate_category}"
    stats[$orient_fps_key]=$(( ${stats[$orient_fps_key]:-0} + 1 ))

    # Build emoji string in canonical order
    local emoji_indicators=""
    [[ "$temp_emojis" == *"$IPHONE"* ]] && emoji_indicators+="$IPHONE"
    [[ "$temp_emojis" == *"$CAMERA"* ]] && emoji_indicators+="$CAMERA"
    [[ "$temp_emojis" == *"$GPS"*    ]] && emoji_indicators+="$GPS"
    [[ "$temp_emojis" == *"$EDIT"*   ]] && emoji_indicators+="$EDIT"

    local format_key="${actual_resolution}|${orientation}|${framerate_category}"
    local extension="${file##*.}"
    # Sanitize extension: allow only alphanumerics
    extension="${extension//[^a-zA-Z0-9]/}"
    [[ -z "$extension" ]] && extension="mov"

    # --- Build new filename ---
    local new_name_base counter_str
    if [[ "$mode" == "KeepName" ]]; then
        new_name_base="${file##*/}"
    elif [[ "$mode" == "EmojiVid" ]]; then
        ((resolution_counters[$format_key]++))
        counter_str=$(printf "%03d" ${resolution_counters[$format_key]})
        new_name_base=""
        [[ -n "$file_prefix"     ]] && new_name_base+="${file_prefix} "
        [[ -n "$emoji_indicators"]] && new_name_base+="${emoji_indicators} "
        new_name_base+="${counter_str}.${extension}"
    else
        ((resolution_counters[$format_key]++))
        counter_str=$(printf "%03d" ${resolution_counters[$format_key]})
        new_name_base=""
        [[ -n "$file_prefix"     ]] && new_name_base+="${file_prefix} "
        new_name_base+="${actual_resolution} ${orientation}${framerate_category} "
        [[ -n "$emoji_indicators"]] && new_name_base+="${emoji_indicators} "
        new_name_base+="${counter_str}.${extension}"
    fi

    # Sanitize the assembled name
    new_name_base=$(sanitize_filename "$new_name_base")
    # Guard against name ending with just a dot
    [[ "$new_name_base" == *. ]] && new_name_base+="${extension}"

    # --- Determine destination directory ---
    local dest_dir="$inputFolder"
    case "$mode" in
        "VidRes"|"KeepName") dest_dir="${inputFolder}/${actual_resolution}" ;;
        "MaxVid")  dest_dir="${inputFolder}/${actual_resolution} ${orientation} ${framerate_category}" ;;
        "ProMax")  dest_dir="${inputFolder}/${actual_resolution} ${orientation}" ;;
        "ProVid"|"EmojiVid") dest_dir="$inputFolder" ;;
    esac
    [[ ! -d "$dest_dir" ]] && mkdir -p "$dest_dir"

    local new_name="${dest_dir}/${new_name_base}"

    # --- Resolve collisions ---
    while [[ -e "$new_name" ]]; do
        ((resolution_counters[$format_key]++))
        counter_str=$(printf "%03d" ${resolution_counters[$format_key]})

        if [[ "$mode" == "KeepName" ]]; then
            local orig_name="${file##*/}"
            local orig_base="${orig_name%.*}"
            local orig_ext="${orig_name##*.}"
            new_name_base="${orig_base}_${counter_str}.${orig_ext}"
        elif [[ "$mode" == "EmojiVid" ]]; then
            new_name_base=""
            [[ -n "$file_prefix"     ]] && new_name_base+="${file_prefix} "
            [[ -n "$emoji_indicators"]] && new_name_base+="${emoji_indicators} "
            new_name_base+="${counter_str}.${extension}"
        else
            new_name_base=""
            [[ -n "$file_prefix"     ]] && new_name_base+="${file_prefix} "
            new_name_base+="${actual_resolution} ${orientation}${framerate_category} "
            [[ -n "$emoji_indicators"]] && new_name_base+="${emoji_indicators} "
            new_name_base+="${counter_str}.${extension}"
        fi
        new_name_base=$(sanitize_filename "$new_name_base")
        [[ "$new_name_base" == *. ]] && new_name_base+="${extension}"
        new_name="${dest_dir}/${new_name_base}"
    done

    # --- Move / Copy ---
    local output_color="$BLUE"
    [[ "$temp_emojis" == *"$IPHONE"* ]] && output_color="$GREEN"

    if [[ $DRY_RUN -eq 1 ]]; then
        printf "${CYAN}[DRY-RUN]${RESET} ${output_color}%s${RESET} → %s\n" \
            "${file##*/}" "$new_name_base"
        ((stats[total_success]++))
    elif [[ $BACKUP_MODE -eq 1 ]]; then
        if cp -p "$file" "$new_name" 2>/dev/null; then
            move_history[$new_name]="$file"
            ((stats[total_success]++))
            printf "${output_color}%s${RESET} → %s ${GREEN}(copied)${RESET}\n" \
                "${file##*/}" "$new_name_base"
        else
            ((stats[total_failure]++))
            printf "\n%s\n" "${ERROR}${CROSS} FAILED to copy ${file:t}${RESET}" >&2
        fi
    elif mv "$file" "$new_name" 2>/dev/null; then
        move_history[$new_name]="$file"
        ((stats[total_success]++))
        printf "${output_color}%s${RESET} → %s\n" "${file##*/}" "$new_name_base"
    else
        # Cross-device fallback: copy + verify + delete original
        if cp -p "$file" "$new_name" 2>/dev/null && [[ -f "$new_name" ]]; then
            if rm "$file" 2>/dev/null; then
                move_history[$new_name]="$file"
                ((stats[total_success]++))
                printf "${output_color}%s${RESET} → %s\n" "${file##*/}" "$new_name_base"
            else
                ((stats[total_failure]++))
                printf "\n%s\n" "${ERROR}${CROSS} Copied but could not remove original: ${file:t}${RESET}" >&2
            fi
        else
            ((stats[total_failure]++))
            printf "\n%s\n" "${ERROR}${CROSS} FAILED to move ${file:t}${RESET}" >&2
        fi
    fi
}

# ==============================================================================
# FINAL STATS
# ==============================================================================

show_final_stats() {
    local elapsed_secs=$(( SECONDS - start_time ))
    local hours=$(( elapsed_secs / 3600 ))
    local minutes=$(( (elapsed_secs % 3600) / 60 ))
    local secs=$(( elapsed_secs % 60 ))
    printf "\n%s\n" "${HEADER}📊 Final Statistics${RESET}"
    printf -- "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    printf "${BLUE}Total videos processed: %s${RESET}\n" "${stats[total_processed]}"
    printf "${GREEN}✅ Succeeded:           %s${RESET}\n" "${stats[total_success]:-0}"
    printf "${RED}❌ Failed:              %s${RESET}\n"  "${stats[total_failure]:-0}"
    printf "${BLUE}──────────────────────────${RESET}\n"
    printf "${GREEN}📱 Apple devices:       %s${RESET}\n" "${stats[apple_detected]:-0}"
    printf "${CYAN}📷 Camera Lens:         %s${RESET}\n" "${stats[camera_lens]:-0}"
    printf "${CYAN}🌍 GPS:                 %s${RESET}\n" "${stats[gps_found]:-0}"
    local fps30_total="${stats[fps_30]:-0}"
    local fps60_total="${stats[fps_60]:-0}"
    if [[ "$fps30_total" == "0" && "$fps60_total" == "0" ]]; then
        fps30_total=$(( ${stats[W30]:-0} + ${stats[V30]:-0} ))
        fps60_total=$(( ${stats[W60]:-0} + ${stats[V60]:-0} ))
    fi
    printf "${BLUE}🎞  30 FPS:             %s${RESET}\n" "$fps30_total"
    printf "${BLUE}⚡  60 FPS:             %s${RESET}\n" "$fps60_total"
    printf "${BLUE}──────────────────────────${RESET}\n"
    printf "${WHITE}⏱  Elapsed:            %02dh %02dm %02ds${RESET}\n" \
        "$hours" "$minutes" "$secs"
    printf -- "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

delete_empty_directories() {
    [[ -z "${inputFolder:-}" || ! -d "$inputFolder" ]] && return
    printf "%s\n" "${GREEN}🧹 Deleting empty directories...${RESET}" >&2
    find "$inputFolder" -name ".DS_Store" -type f -delete 2>/dev/null
    find "$inputFolder" -type d -empty -delete 2>/dev/null
    printf "%s\n" "${GREEN}${CHECK} Empty directories deleted.${RESET}" >&2
}

# ==============================================================================
# EMBEDDED TOOLS
# ==============================================================================

_vid_month_to_name() {
    local num=$1 short=$2
    case "$num" in
        1|01)  [[ $short == "true" ]] && echo "Jan" || echo "January"   ;;
        2|02)  [[ $short == "true" ]] && echo "Feb" || echo "February"  ;;
        3|03)  [[ $short == "true" ]] && echo "Mar" || echo "March"     ;;
        4|04)  [[ $short == "true" ]] && echo "Apr" || echo "April"     ;;
        5|05)  echo "May" ;;
        6|06)  [[ $short == "true" ]] && echo "Jun" || echo "June"      ;;
        7|07)  [[ $short == "true" ]] && echo "Jul" || echo "July"      ;;
        8|08)  [[ $short == "true" ]] && echo "Aug" || echo "August"    ;;
        9|09)  [[ $short == "true" ]] && echo "Sep" || echo "September" ;;
        10)    [[ $short == "true" ]] && echo "Oct" || echo "October"   ;;
        11)    [[ $short == "true" ]] && echo "Nov" || echo "November"  ;;
        12)    [[ $short == "true" ]] && echo "Dec" || echo "December"  ;;
        *)     echo "Unknown" ;;
    esac
}

_vid_create_backup() {
    local source="$1" base_name="$2"
    local desktop="$HOME/Desktop"
    local suffix_num=1
    local dest="${desktop}/${base_name}_backup"
    while [[ -d "$dest" ]]; do
        dest="${desktop}/${base_name}_backup_${suffix_num}"
        ((suffix_num++))
    done
    printf "${CYAN}📂 Creating backup → %s${RESET}\n" "$dest"
    if ditto "$source" "$dest" 2>/dev/null; then
        printf "${SUCCESS}✅ Backup created successfully${RESET}\n\n"
    else
        printf "${YELLOW}⚠️  Backup failed — continuing anyway${RESET}\n\n"
    fi
}

# ------------------------------------------------------------------------------
# TOOL: 1MinVid — Video Date Adjuster (1-minute increments)
# Accepts: folder OR individual video files via drag-and-drop
# ------------------------------------------------------------------------------
run_fixvid() {
    TOOL_MODE=1
    printf "\n${HEADER}🎬 1MinVid — Video Date Adjuster${RESET}\n"
    printf "${BLUE}Version 2.3 · 1-minute increments from 12:00 PM${RESET}\n\n"

    printf "${CYAN}📁 Drop a folder or video files here, then press Enter:${RESET}\n"
    local fv_raw
    read -r fv_raw

    local -a fv_files
    collect_video_inputs "$fv_raw" fv_files
    local target_dir="$_COLLECT_BASE_DIR"

    local fv_count=${#fv_files[@]}
    if (( fv_count == 0 )); then
        printf "${ERROR}❌ No video files found in input.${RESET}\n"
        exit 1
    fi
    printf "${GREEN}📹 %d video file(s) ready to process${RESET}\n\n" "$fv_count"

    # Create backup of the base directory
    _vid_create_backup "$target_dir" "$(basename "$target_dir")"

    # --- Date input ---
    printf "${CYAN}📅 Enter month (1-12):${RESET} "
    local fv_month
    read -r fv_month
    fv_month="${fv_month#0}"
    while [[ ! $fv_month =~ ^([1-9]|1[0-2])$ ]]; do
        printf "${RED}Invalid — enter 1-12:${RESET} "; read -r fv_month; fv_month="${fv_month#0}"
    done

    printf "${CYAN}📅 Enter day (1-31):${RESET} "
    local fv_day
    read -r fv_day
    fv_day="${fv_day#0}"
    while [[ ! $fv_day =~ ^([1-9]|[12][0-9]|3[01])$ ]]; do
        printf "${RED}Invalid — enter 1-31:${RESET} "; read -r fv_day; fv_day="${fv_day#0}"
    done

    printf "${CYAN}📅 Enter year (4 digits):${RESET} "
    local fv_year
    read -r fv_year
    while [[ ! $fv_year =~ ^[0-9]{4}$ ]]; do
        printf "${RED}Invalid year:${RESET} "; read -r fv_year
    done

    local fv_mf=$(printf "%02d" $fv_month)
    local fv_mname
    fv_mname=$(_vid_month_to_name "$fv_month" "false")

    printf "\n${SUCCESS}✅ Settings: %s %d, %d — starting at 12:00 PM${RESET}\n" \
        "$fv_mname" "$fv_day" "$fv_year"
    printf "${WHITE}Press Enter to start processing…${RESET}\n"; read -r

    # --- Process ---
    local fv_counter=0 fv_ok=0 fv_fail=0
    printf "\n${BLUE}🔄 Processing %d videos…${RESET}\n\n" "$fv_count"

    local fv_file
    for fv_file in "${fv_files[@]}"; do
        local fv_base="${fv_file##*/}"
        local fv_disp="${fv_base:0:50}"

        local fv_min=$(( 12 * 60 + fv_counter ))
        local fv_h=$(( fv_min / 60 % 24 ))
        local fv_m=$(( fv_min % 60 ))
        local fv_curday=$(( fv_day + fv_min / (24*60) ))
        local fv_dt="${fv_year}:${fv_mf}:$(printf '%02d' $fv_curday) $(printf '%02d' $fv_h):$(printf '%02d' $fv_m):00"

        local fv_tdisp
        if   (( fv_h == 0  )); then fv_tdisp="12:$(printf '%02d' $fv_m) AM"
        elif (( fv_h == 12 )); then fv_tdisp="12:$(printf '%02d' $fv_m) PM"
        elif (( fv_h < 12  )); then fv_tdisp="${fv_h}:$(printf '%02d' $fv_m) AM"
        else fv_tdisp="$((fv_h-12)):$(printf '%02d' $fv_m) PM"; fi

        printf "📹 %2d. %-40s → %s (%s)\n" $((fv_counter+1)) "$fv_disp" "$fv_dt" "$fv_tdisp"

        local -a fv_cmd=(-overwrite_original
            "-DateTimeOriginal=${fv_dt}" "-CreateDate=${fv_dt}"
            "-MediaCreateDate=${fv_dt}"  "-TrackCreateDate=${fv_dt}"
            "-CreationDate=${fv_dt}"     "-QuickTime:CreateDate=${fv_dt}"
            "-Keys:CreationDate=${fv_dt}" "-XMP:CreateDate=${fv_dt}"
            "-XMP:DateCreated=${fv_dt}"  "-Apple:CreationDate=${fv_dt}"
            "-ItemList:CreationDate=${fv_dt}"
        )
        local fv_out
        if fv_out=$(exiftool "${fv_cmd[@]}" "$fv_file" 2>&1); then
            printf "   ${SUCCESS}✅ Success${RESET}\n"
            ((fv_ok++))
        else
            printf "   ${ERROR}❌ Failed: %s${RESET}\n" "$fv_out"
            ((fv_fail++))
        fi
        ((fv_counter++))
    done

    printf "\n${SUCCESS}✅ Complete — %d processed (%d ok, %d failed)${RESET}\n" \
        "$fv_counter" "$fv_ok" "$fv_fail"
    printf "${BLUE}📁 Base folder: %s${RESET}\n\n" "$target_dir"
}

# ------------------------------------------------------------------------------
# TOOL: MetaMov — Video Date Adjuster (iPhone or Downloaded mode)
# Accepts: folder OR individual video files via drag-and-drop
# ------------------------------------------------------------------------------
run_metamov() {
    TOOL_MODE=1
    printf "\n${HEADER}🎬 MetaMov — Video Date Adjuster${RESET}\n"
    printf "${BLUE}Version 4.1 · Chronological sort + flexible increments${RESET}\n\n"

    printf "${CYAN}📁 Drop a folder or video files here, then press Enter:${RESET}\n"
    local mm_raw
    read -r mm_raw

    local -a mm_files
    collect_video_inputs "$mm_raw" mm_files
    local target_dir="$_COLLECT_BASE_DIR"

    local mm_count=${#mm_files[@]}
    if (( mm_count == 0 )); then
        printf "${ERROR}❌ No video files found in input.${RESET}\n"
        exit 1
    fi
    printf "${GREEN}📹 %d video file(s) ready to process${RESET}\n\n" "$mm_count"

    _vid_create_backup "$target_dir" "$(basename "$target_dir")"

    # --- Mode selection ---
    printf "${CYAN}📱 Select video type:${RESET}\n"
    printf "${GREEN}  1. iPhone/Personal  — chronological sort, 1-min increments${RESET}\n"
    printf "${BLUE}  2. Downloaded       — filename order, 5-min increments${RESET}\n\n"
    printf "Enter your choice (1 or 2): "
    local mm_type
    read -r mm_type
    while [[ ! $mm_type =~ ^[12]$ ]]; do
        printf "${RED}Invalid — enter 1 or 2:${RESET} "; read -r mm_type
    done

    local mm_mode mm_inc
    if [[ $mm_type == "1" ]]; then
        mm_mode="iphone"; mm_inc=1
        printf "${SUCCESS}✓ iPhone/Personal mode — 1-minute increments${RESET}\n\n"
    else
        mm_mode="downloaded"; mm_inc=5
        printf "${SUCCESS}✓ Downloaded mode — 5-minute increments${RESET}\n\n"
    fi

    # --- Extract original dates ---
    printf "${BLUE}📊 Extracting original metadata…${RESET}\n"
    typeset -A mm_orig_meta
    local mm_f mm_bn mm_od mm_field
    for mm_f in "${mm_files[@]}"; do
        mm_bn="${mm_f##*/}"
        mm_od=""
        for mm_field in DateTimeOriginal CreateDate ModifyDate FileModifyDate; do
            mm_od=$(exiftool -s -s -s -d "%Y:%m:%d %H:%M:%S" "-${mm_field}" "$mm_f" 2>/dev/null)
            [[ -n "$mm_od" ]] && break
        done
        mm_orig_meta[$mm_bn]="$mm_od"
        if [[ -n "$mm_od" ]]; then
            printf "   🔍 %s → %s\n" "$mm_bn" "$mm_od"
        else
            printf "   ❔ No original date: %s\n" "$mm_bn"
        fi
    done
    printf "${SUCCESS}✅ Metadata extraction complete${RESET}\n\n"

    # --- Chronological sort for iPhone mode ---
    if [[ $mm_mode == "iphone" ]]; then
        printf "${CYAN}📅 Sorting chronologically…${RESET}\n"
        local mm_tmp="/tmp/mm_sort_$$"
        for mm_f in "${mm_files[@]}"; do
            mm_bn="${mm_f##*/}"
            local mm_sk="${mm_orig_meta[$mm_bn]}"
            [[ -z "$mm_sk" ]] && mm_sk="1900:01:01 00:00:00"
            printf '%s|%s\n' "${mm_sk//[: -]/}" "$mm_f" >> "$mm_tmp"
        done
        mm_files=()
        local mm_fp
        while IFS='|' read -r _ mm_fp; do
            mm_files+=("$mm_fp")
        done < <(sort -n "$mm_tmp")
        rm -f "$mm_tmp"
        printf "${SUCCESS}✅ Sorted oldest → newest${RESET}\n\n"
    fi

    # --- Date input ---
    printf "${CYAN}Current date: $(date '+%B %d, %Y')${RESET}\n\n"

    printf "${CYAN}📅 Enter month (1-12):${RESET} "
    local mm_month
    read -r mm_month
    mm_month="${mm_month#0}"
    while [[ ! $mm_month =~ ^([1-9]|1[0-2])$ ]]; do
        printf "${RED}Invalid:${RESET} "; read -r mm_month; mm_month="${mm_month#0}"
    done

    printf "${CYAN}📅 Enter day (1-31):${RESET} "
    local mm_day
    read -r mm_day
    mm_day="${mm_day#0}"
    while [[ ! $mm_day =~ ^([1-9]|[12][0-9]|3[01])$ ]]; do
        printf "${RED}Invalid:${RESET} "; read -r mm_day; mm_day="${mm_day#0}"
    done

    printf "${CYAN}📅 Enter year (4 digits):${RESET} "
    local mm_year
    read -r mm_year
    while [[ ! $mm_year =~ ^[0-9]{4}$ ]]; do
        printf "${RED}Invalid year:${RESET} "; read -r mm_year
    done

    local mm_mf=$(printf "%02d" $mm_month)
    local mm_mname
    mm_mname=$(_vid_month_to_name "$mm_month" "false")

    printf "\n${SUCCESS}"
    printf "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n"
    printf "┃  CONFIRMATION                          ┃\n"
    printf "┃  Date   : %-28s┃\n" "${mm_mname} ${mm_day}, ${mm_year}"
    printf "┃  Mode   : %-28s┃\n" \
        "$([[ "$mm_mode" == "iphone" ]] && echo "iPhone/Personal (1-min)" || echo "Downloaded (5-min)")"
    printf "┃  Videos : %-28s┃\n" "$mm_count"
    printf "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\n${RESET}"
    printf "${WHITE}Press Enter to start processing…${RESET}\n"; read -r

    # --- Process ---
    local mm_counter=0 mm_ok=0 mm_fail=0
    printf "\n${BLUE}🔄 Processing %d videos…${RESET}\n\n" "$mm_count"

    local mm_file
    for mm_file in "${mm_files[@]}"; do
        local mm_base="${mm_file##*/}"
        local mm_disp="${mm_base:0:45}"

        local mm_minutes_add=$(( (mm_counter + 1) * mm_inc ))
        local mm_h=$(( (12 * 60 + mm_minutes_add) / 60 % 24 ))
        local mm_m=$(( (12 * 60 + mm_minutes_add) % 60 ))
        local mm_curday=$(( mm_day + (12 * 60 + mm_minutes_add) / (24*60) ))
        local mm_dt="${mm_year}:${mm_mf}:$(printf '%02d' $mm_curday) $(printf '%02d' $mm_h):$(printf '%02d' $mm_m):00"

        local mm_tdisp
        if   (( mm_h == 0  )); then mm_tdisp="12:$(printf '%02d' $mm_m) AM"
        elif (( mm_h == 12 )); then mm_tdisp="12:$(printf '%02d' $mm_m) PM"
        elif (( mm_h < 12  )); then mm_tdisp="${mm_h}:$(printf '%02d' $mm_m) AM"
        else mm_tdisp="$((mm_h-12)):$(printf '%02d' $mm_m) PM"; fi

        printf "📹 %2d. %-40s → %s (%s)\n" $((mm_counter+1)) "$mm_disp" "$mm_dt" "$mm_tdisp"

        local mm_out
        if mm_out=$(exiftool -overwrite_original -ignoreMinorErrors \
            "-AllDates=${mm_dt}"             \
            "-CreateDate=${mm_dt}"           \
            "-DateTimeOriginal=${mm_dt}"     \
            "-ModifyDate=${mm_dt}"           \
            "-MediaCreateDate=${mm_dt}"      \
            "-TrackCreateDate=${mm_dt}"      \
            "-FileModifyDate=${mm_dt}"       \
            "-QuickTime:CreateDate=${mm_dt}" \
            "-Keys:CreationDate=${mm_dt}"    \
            "$mm_file" 2>&1); then
            printf "   ${SUCCESS}✅ Success${RESET}\n"
            ((mm_ok++))
        else
            printf "   ${ERROR}❌ Failed: %s${RESET}\n" "$mm_out"
            ((mm_fail++))
        fi
        ((mm_counter++))
    done

    printf "\n${SUCCESS}✅ Complete — %d processed (%d ok, %d failed)${RESET}\n" \
        "$mm_counter" "$mm_ok" "$mm_fail"
    printf "${BLUE}📁 Base folder: %s${RESET}\n\n" "$target_dir"
}

# ------------------------------------------------------------------------------
# TOOL: MuteVid — Remove audio & metadata from videos
# Accepts: any number of folders and/or individual files via drag-and-drop
# ------------------------------------------------------------------------------
run_mute() {
    TOOL_MODE=1
    for mt_tool in ffmpeg ffprobe; do
        command -v "$mt_tool" >/dev/null 2>&1 || {
            printf "${ERROR}❌ Missing required tool: %s${RESET}\n" "$mt_tool"
            printf "${CYAN}Install with: brew install ffmpeg${RESET}\n"
            exit 1
        }
    done

    printf "\n${HEADER}🎬 MuteVid — Audio & Metadata Scrubber${RESET}\n\n"
    printf "${CYAN}🎯 Drop any number of video files and/or folders, then press Enter:${RESET}\n\n"

    local mt_input_line
    vared -p ">>> " -c mt_input_line
    [[ -z "$mt_input_line" ]] && { printf "${ERROR}❌ No input provided${RESET}\n"; exit 1; }

    local -a mt_queue
    collect_video_inputs "$mt_input_line" mt_queue

    local mt_total=${#mt_queue[@]}
    if (( mt_total == 0 )); then
        printf "${ERROR}❌ No video files found to process${RESET}\n"; exit 1
    fi

    printf "\n${GREEN}📊 Processing %d video(s):${RESET}\n\n" "$mt_total"

    local mt_ok=0 mt_fail=0
    local -A mt_created

    trap '
        printf "\n${CYAN}Interrupted — removing partial files…${RESET}\n"
        for mt_out in "${(@k)mt_created}"; do [[ -f "$mt_out" ]] && rm -f "$mt_out"; done
        exit 1
    ' INT TERM

    local mt_i=1 mt_file
    for mt_file in "${mt_queue[@]}"; do
        printf "  [%d/%d] %s\n" "$mt_i" "$mt_total" "${mt_file##*/}"

        local mt_dir="${mt_file:h}"
        local mt_base="${mt_file:t:r}"
        local mt_ext="${mt_file:e:l}"
        local mt_out="${mt_dir}/${mt_base}_muted.${mt_ext}"
        local mt_c=2
        while [[ -e "$mt_out" ]]; do
            mt_out="${mt_dir}/${mt_base}_muted_${mt_c}.${mt_ext}"; ((mt_c++))
        done

        if ffmpeg -hide_banner -loglevel error \
            -i "$mt_file" -c:v copy -an -map_metadata -1 \
            -movflags +faststart -y "$mt_out" 2>/dev/null; then
            if ! ffprobe -v error -select_streams a \
                -show_entries stream=codec_type "$mt_out" 2>/dev/null | grep -q audio; then
                printf "    ✅ Muted → %s\n\n" "${mt_out##*/}"
                mt_created[$mt_out]="$mt_file"
                ((mt_ok++))
            else
                printf "    ❌ Audio check failed — removing output\n\n"
                rm -f "$mt_out"; ((mt_fail++))
            fi
        else
            printf "    ❌ Processing failed\n\n"
            ((mt_fail++))
        fi
        ((mt_i++))
    done

    trap cleanup_and_exit EXIT
    trap rollback INT TERM

    printf "${SUCCESS}✅ MuteVid complete — %d succeeded, %d failed${RESET}\n\n" \
        "$mt_ok" "$mt_fail"
}

# ------------------------------------------------------------------------------
# TOOL: Slo-Mo — Slow-Motion Converter
# Accepts: folder OR individual video files via drag-and-drop
# ------------------------------------------------------------------------------
run_slomov() {
    TOOL_MODE=1
    command -v ffmpeg >/dev/null 2>&1 || {
        printf "${ERROR}❌ Missing required tool: ffmpeg${RESET}\n"
        printf "${CYAN}Install with: brew install ffmpeg${RESET}\n"
        exit 1
    }

    printf "\n${HEADER}🐢 Slo-Mo — Slow-Motion Converter${RESET}\n"
    printf "${BLUE}M1 Mac optimised · VideoToolbox hardware acceleration${RESET}\n\n"

    printf "${MAGENTA}Drop a folder or video files here, then press Enter:${RESET}\n"
    local sm_raw
    read -r sm_raw

    local -a sm_files
    collect_video_inputs "$sm_raw" sm_files
    local sm_folder="$_COLLECT_BASE_DIR"

    local sm_file_count=${#sm_files[@]}
    if (( sm_file_count == 0 )); then
        printf "${ERROR}❌ No video files found in input.${RESET}\n"; exit 1
    fi
    printf "${GREEN}📹 %d video(s) ready${RESET}\n" "$sm_file_count"

    local -a sm_done

    while true; do
        local sm_display_num=1
        local -A sm_opt_map
        typeset -A sm_opt_map

        printf "\n${MAGENTA}Select slo-mo speed:${RESET}\n"

        local sm_has_50=false sm_has_75=false sm_has_25=false sm_b
        for sm_b in "${sm_done[@]}"; do
            case "$sm_b" in 50) sm_has_50=true ;; 75) sm_has_75=true ;; 25) sm_has_25=true ;; esac
        done

        [[ $sm_has_50 == false ]] && {
            printf "${CYAN}%d) 50%% speed  (2× slower)   — Average${RESET}\n" $sm_display_num
            sm_opt_map[$sm_display_num]="50"; ((sm_display_num++))
        }
        [[ $sm_has_75 == false ]] && {
            printf "${GREEN}%d) 75%% speed  (1.25× slower) — Fast${RESET}\n" $sm_display_num
            sm_opt_map[$sm_display_num]="75"; ((sm_display_num++))
        }
        [[ $sm_has_25 == false ]] && {
            printf "${MAGENTA}%d) 25%% speed  (4× slower)   — Slow${RESET}\n" $sm_display_num
            sm_opt_map[$sm_display_num]="25"; ((sm_display_num++))
        }

        if (( sm_display_num == 1 )); then
            printf "${SUCCESS}All speed options completed!${RESET}\n"; break
        fi

        printf "\nChoose option (1-%d): " $((sm_display_num-1))
        local sm_choice
        read -r sm_choice
        local sm_code="${sm_opt_map[$sm_choice]}"
        if [[ -z "$sm_code" ]]; then
            printf "${RED}Invalid choice — try again${RESET}\n"; continue
        fi

        local sm_setpts sm_atempo sm_suffix sm_desc
        case $sm_code in
            50) sm_setpts="2.0*PTS"; sm_atempo="atempo=0.5";           sm_suffix="50"; sm_desc="50% speed" ;;
            75) sm_setpts="1.3334*PTS"; sm_atempo="atempo=0.75";         sm_suffix="75"; sm_desc="75% speed" ;;
            25) sm_setpts="4.0*PTS"; sm_atempo="atempo=0.5,atempo=0.5"; sm_suffix="25"; sm_desc="25% speed" ;;
        esac

        local sm_out_dir="${sm_folder}/${sm_suffix}%"
        mkdir -p "$sm_out_dir"

        printf "\n${MAGENTA}Processing %d video(s) at %s…${RESET}\n" "$sm_file_count" "$sm_desc"
        printf "${BLUE}Output → %s${RESET}\n\n" "$sm_out_dir"

        local sm_count=0 sm_ok=0 sm_f sm_fn sm_name sm_ext sm_dest
        for sm_f in "${sm_files[@]}"; do
            [[ -f "$sm_f" ]] || continue
            sm_fn="${sm_f##*/}"
            sm_name="${sm_fn%.*}"
            sm_ext="${sm_fn##*.}"
            ((sm_count++))
            sm_dest="${sm_out_dir}/${sm_name}_${sm_suffix}%.${sm_ext}"
            # Handle destination collision
            local sm_dc=2
            while [[ -e "$sm_dest" ]]; do
                sm_dest="${sm_out_dir}/${sm_name}_${sm_suffix}%_${sm_dc}.${sm_ext}"; ((sm_dc++))
            done

            printf "  Processing: %s (%d/%d)\n" "$sm_fn" "$sm_count" "$sm_file_count"

            # Try hardware-accelerated encode first, fall back to software
            if ffmpeg -hide_banner -loglevel error \
                -hwaccel videotoolbox -i "$sm_f" \
                -filter:v "setpts=${sm_setpts}" -filter:a "$sm_atempo" \
                -c:v h264_videotoolbox -b:v 25M -maxrate 35M -bufsize 50M \
                -profile:v high -c:a aac -b:a 320k -ar 48000 \
                -movflags +faststart \
                "$sm_dest" -y 2>/dev/null; then
                printf "  ${SUCCESS}✅ %s_${sm_suffix}%%.%s${RESET}\n\n" "$sm_name" "$sm_ext"
                ((sm_ok++))
            else
                printf "  ${YELLOW}⚠️  HW encode failed — trying software…${RESET}\n"
                if ffmpeg -hide_banner -loglevel error \
                    -i "$sm_f" \
                    -filter:v "setpts=${sm_setpts}" -filter:a "$sm_atempo" \
                    -c:v libx264 -preset veryslow -crf 15 -profile:v high -level 4.1 \
                    -c:a aac -b:a 320k -ar 48000 \
                    -movflags +faststart \
                    "$sm_dest" -y 2>/dev/null; then
                    printf "  ${SUCCESS}✅ %s_${sm_suffix}%%.%s (SW)${RESET}\n\n" "$sm_name" "$sm_ext"
                    ((sm_ok++))
                else
                    printf "  ${ERROR}❌ Failed: %s${RESET}\n\n" "$sm_fn"
                fi
            fi
        done

        printf "${SUCCESS}✅ %s complete — %d/%d processed${RESET}\n" \
            "$sm_desc" "$sm_ok" "$sm_count"
        sm_done+=("$sm_code")

        local sm_status=""
        for sm_b in "${sm_done[@]}"; do
            [[ -n "$sm_status" ]] && sm_status+=", "
            sm_status+="${sm_b}% done"
        done

        printf "\n${BLUE}Process another speed? (y/n)${RESET}"
        [[ -n "$sm_status" ]] && printf " ${GREEN}[%s]${RESET}" "$sm_status"
        printf ": "
        local sm_again
        read -r sm_again
        [[ ! "$sm_again" =~ ^[Yy]$ ]] && break
    done

    printf "\n${SUCCESS}✅ Slo-Mo complete. Files saved in subfolders of:${RESET}\n"
    printf "${BLUE}   %s${RESET}\n\n" "$sm_folder"
}

# ------------------------------------------------------------------------------
# TOOL: OG/Edits — Interactive EXIF Forensics / Video Authenticity Analyzer
# Accepts: folder OR individual files (uses parent directory for analysis)
# ------------------------------------------------------------------------------
run_exiff_audit() {
    TOOL_MODE=1

    local ef_export_only=0 ef_dir=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --export-only) ef_export_only=1; shift ;;
            *)             ef_dir="$1";      shift ;;
        esac
    done

    command -v exiftool >/dev/null 2>&1 || {
        printf "${ERROR}❌ exiftool is required. Install: brew install exiftool${RESET}\n"
        exit 1
    }

    if [[ -z "$ef_dir" ]]; then
        printf "\n${CYAN}📁 Drop a folder or video files here, then press Enter:${RESET}\n"
        local ef_raw
        read -r ef_raw

        # Accept files too — use their parent directory
        local -a ef_tokens
        ef_tokens=(${(z)ef_raw})
        local ef_first_path
        ef_first_path=$(sanitize_dropped_path "${ef_tokens[1]}")
        if [[ -f "$ef_first_path" ]]; then
            ef_dir="${ef_first_path:h}"
            printf "${CYAN}ℹ️  Using parent directory: %s${RESET}\n" "$ef_dir"
        elif [[ -d "$ef_first_path" ]]; then
            ef_dir="$ef_first_path"
        else
            printf "${ERROR}❌ Could not resolve path from input.${RESET}\n"; exit 1
        fi
    fi

    if [[ ! -d "$ef_dir" ]]; then
        printf "${ERROR}❌ Not a valid directory: %s${RESET}\n" "$ef_dir"; exit 1
    fi

    if [[ $ef_export_only -eq 1 ]]; then
        run_comprehensive_audit "$ef_dir"
        printf "\n${SUCCESS}✅ Forensic Audit complete. CSVs saved in: %s${RESET}\n" "$ef_dir"
        return 0
    fi

    while true; do
        printf "\n${HEADER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
        printf "${HEADER}  🔍 OG/Edits — Video Authenticity Analyzer${RESET}\n"
        printf "${HEADER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
        printf "${CYAN}  Folder: %s${RESET}\n" "$ef_dir"
        printf "${BLUE}─────────────────────────────────────────────────${RESET}\n"
        printf "${WHITE}  1.  Quick Overview        — file count & types${RESET}\n"
        printf "${GREEN}  2.  Strict iPhone         — unedited originals only${RESET}\n"
        printf "${YELLOW}  3.  QuickTime / Edited    — editing indicators${RESET}\n"
        printf "${ORANGE}  4.  Unusual Dimensions    — cropped / non-standard${RESET}\n"
        printf "${RED}  5.  Missing Apple Meta    — no Make=Apple${RESET}\n"
        printf "${MAGENTA}  6.  Timing Analysis       — large create↔modify gaps${RESET}\n"
        printf "${BLUE}─────────────────────────────────────────────────${RESET}\n"
        printf "${CYAN}  7.  Export All to CSV     — 4 CSV files in folder${RESET}\n"
        printf "${WHITE}  8.  Run Everything        — summary + export${RESET}\n"
        printf "${BLUE}─────────────────────────────────────────────────${RESET}\n"
        printf "${WHITE}  q.  Back / Quit${RESET}\n"
        printf "${BLUE}─────────────────────────────────────────────────${RESET}\n"
        printf "${WHITE}Enter choice (1-8, q): ${RESET}"
        local ef_choice
        read -r ef_choice

        case "$ef_choice" in
            1)
                printf "\n${HEADER}=== QUICK OVERVIEW ===${RESET}\n"
                local ef_count
                ef_count=$(find "$ef_dir" -type f \( -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" \) \
                    | wc -l | tr -d ' ')
                printf "${WHITE}Total video files: ${CYAN}%s${RESET}\n\n" "$ef_count"
                printf "${WHITE}File types:${RESET}\n"
                find "$ef_dir" -type f \( -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" \) \
                    | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -nr \
                    | while read -r ef_n ef_e; do
                        printf "  ${CYAN}%-6s${RESET} %s files\n" "$ef_e" "$ef_n"
                    done
                printf "\n${WHITE}Resolutions:${RESET}\n"
                exiftool -csv -r -ImageWidth -ImageHeight "$ef_dir" 2>/dev/null \
                    | tail -n +2 \
                    | awk -F',' '{if(NF>=3 && $2~/^[0-9]+$/ && $3~/^[0-9]+$/) print $2"x"$3}' \
                    | sort | uniq -c | sort -nr \
                    | while read -r ef_n ef_r; do
                        printf "  ${CYAN}%-4s${RESET} × ${WHITE}%s${RESET}\n" "$ef_n" "$ef_r"
                    done
                ;;
            2)
                printf "\n${HEADER}=== STRICT iPHONE ORIGINALS ===${RESET}\n"
                printf "${GREEN}Videos appearing to be unedited iPhone recordings:${RESET}\n\n"
                exiftool -api QuickTimeUTC=1 \
                    -if '$Make eq "Apple" and $Model =~ /iPhone/ and $Software =~ /^[0-9]+\.[0-9]/ and not defined $CompressorName and abs($FileModifyDate - $CreateDate) < 3600' \
                    -FileName -Make -Model -Software -CreateDate -r "$ef_dir" 2>/dev/null
                local ef_cnt
                ef_cnt=$(exiftool -api QuickTimeUTC=1 \
                    -if '$Make eq "Apple" and $Model =~ /iPhone/ and $Software =~ /^[0-9]+\.[0-9]/ and not defined $CompressorName and abs($FileModifyDate - $CreateDate) < 3600' \
                    -FileName -r "$ef_dir" 2>/dev/null | grep -c "File Name")
                printf "\n${SUCCESS}Total strict iPhone originals: %s${RESET}\n" "$ef_cnt"
                ;;
            3)
                printf "\n${HEADER}=== QUICKTIME / EDITED VIDEOS ===${RESET}\n"
                printf "${YELLOW}Videos showing signs of editing or re-encoding:${RESET}\n\n"
                exiftool -api QuickTimeUTC=1 \
                    -if '$Software =~ /QuickTime/ or defined $CompressorName or abs($FileModifyDate - $CreateDate) > 3600' \
                    -FileName -Software -CreateDate -FileModifyDate -CompressorName -r "$ef_dir" 2>/dev/null
                local ef_cnt
                ef_cnt=$(exiftool -api QuickTimeUTC=1 \
                    -if '$Software =~ /QuickTime/ or defined $CompressorName or abs($FileModifyDate - $CreateDate) > 3600' \
                    -FileName -r "$ef_dir" 2>/dev/null | grep -c "File Name")
                printf "\n${YELLOW}Total with edit indicators: %s${RESET}\n" "$ef_cnt"
                ;;
            4)
                printf "\n${HEADER}=== UNUSUAL DIMENSIONS ===${RESET}\n"
                printf "${ORANGE}Videos with non-standard aspect ratios (likely cropped or re-exported):${RESET}\n\n"
                exiftool -api QuickTimeUTC=1 -n \
                    -if '$ImageWidth % 16 != 0 or $ImageHeight % 16 != 0 or (abs($ImageWidth/$ImageHeight - 16/9) > 0.01 and abs($ImageWidth/$ImageHeight - 4/3) > 0.01 and abs($ImageWidth/$ImageHeight - 3/4) > 0.01 and abs($ImageWidth/$ImageHeight - 9/16) > 0.01)' \
                    -FileName -ImageWidth -ImageHeight -Make -Model -r "$ef_dir" 2>/dev/null
                local ef_cnt
                ef_cnt=$(exiftool -api QuickTimeUTC=1 -n \
                    -if '$ImageWidth % 16 != 0 or $ImageHeight % 16 != 0 or (abs($ImageWidth/$ImageHeight - 16/9) > 0.01 and abs($ImageWidth/$ImageHeight - 4/3) > 0.01 and abs($ImageWidth/$ImageHeight - 3/4) > 0.01 and abs($ImageWidth/$ImageHeight - 9/16) > 0.01)' \
                    -FileName -r "$ef_dir" 2>/dev/null | grep -c "File Name")
                printf "\n${ORANGE}Total unusual dimensions: %s${RESET}\n" "$ef_cnt"
                ;;
            5)
                printf "\n${HEADER}=== MISSING APPLE METADATA ===${RESET}\n"
                printf "${RED}Videos without Make=Apple identification:${RESET}\n\n"
                exiftool -api QuickTimeUTC=1 \
                    -if 'not defined $Make or $Make ne "Apple"' \
                    -FileName -Make -Model -Software -r "$ef_dir" 2>/dev/null
                local ef_cnt
                ef_cnt=$(exiftool -api QuickTimeUTC=1 \
                    -if 'not defined $Make or $Make ne "Apple"' \
                    -FileName -r "$ef_dir" 2>/dev/null | grep -c "File Name")
                printf "\n${RED}Total missing Apple metadata: %s${RESET}\n" "$ef_cnt"
                ;;
            6)
                printf "\n${HEADER}=== TIMING ANALYSIS ===${RESET}\n"
                printf "${MAGENTA}Videos where FileModifyDate differs from CreateDate by >1 hour:${RESET}\n\n"
                exiftool -api QuickTimeUTC=1 \
                    -if 'abs($FileModifyDate - $CreateDate) > 3600' \
                    -FileName -CreateDate -FileModifyDate -r "$ef_dir" 2>/dev/null
                local ef_cnt
                ef_cnt=$(exiftool -api QuickTimeUTC=1 \
                    -if 'abs($FileModifyDate - $CreateDate) > 3600' \
                    -FileName -r "$ef_dir" 2>/dev/null | grep -c "File Name")
                printf "\n${MAGENTA}Total with significant time gaps: %s${RESET}\n" "$ef_cnt"
                ;;
            7)
                printf "\n${HEADER}=== EXPORTING CSV FILES ===${RESET}\n"
                _exiff_export_csvs "$ef_dir"
                ;;
            8)
                printf "\n${HEADER}=== FULL ANALYSIS ===${RESET}\n\n"
                local ef_total ef_originals ef_edited ef_unusual ef_missing
                ef_total=$(find "$ef_dir" -type f \
                    \( -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" \) \
                    | wc -l | tr -d ' ')
                ef_originals=$(exiftool -api QuickTimeUTC=1 \
                    -if '$Make eq "Apple" and $Model =~ /iPhone/ and $Software =~ /^[0-9]+\.[0-9]/ and not defined $CompressorName and abs($FileModifyDate - $CreateDate) < 3600' \
                    -FileName -r "$ef_dir" 2>/dev/null | grep -c "File Name")
                ef_edited=$(exiftool -api QuickTimeUTC=1 \
                    -if '$Software =~ /QuickTime/ or defined $CompressorName or abs($FileModifyDate - $CreateDate) > 3600' \
                    -FileName -r "$ef_dir" 2>/dev/null | grep -c "File Name")
                ef_unusual=$(exiftool -api QuickTimeUTC=1 -n \
                    -if '$ImageWidth % 16 != 0 or $ImageHeight % 16 != 0 or (abs($ImageWidth/$ImageHeight - 16/9) > 0.01 and abs($ImageWidth/$ImageHeight - 4/3) > 0.01 and abs($ImageWidth/$ImageHeight - 3/4) > 0.01 and abs($ImageWidth/$ImageHeight - 9/16) > 0.01)' \
                    -FileName -r "$ef_dir" 2>/dev/null | grep -c "File Name")
                ef_missing=$(exiftool -api QuickTimeUTC=1 \
                    -if 'not defined $Make or $Make ne "Apple"' \
                    -FileName -r "$ef_dir" 2>/dev/null | grep -c "File Name")

                printf "${HEADER}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RESET}\n"
                printf "${HEADER}┃  OG/EDITS SUMMARY                         ┃${RESET}\n"
                printf "${HEADER}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫${RESET}\n"
                printf "${WHITE}┃  Total video files        : %-14s┃${RESET}\n" "$ef_total"
                printf "${GREEN}┃  Strict iPhone originals  : %-14s┃${RESET}\n" "$ef_originals"
                printf "${YELLOW}┃  Edit indicators          : %-14s┃${RESET}\n" "$ef_edited"
                printf "${ORANGE}┃  Unusual dimensions       : %-14s┃${RESET}\n" "$ef_unusual"
                printf "${RED}┃  Missing Apple metadata   : %-14s┃${RESET}\n"   "$ef_missing"
                printf "${HEADER}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}\n\n"

                _exiff_export_csvs "$ef_dir"
                ;;
            [qQ]) break ;;
            *) printf "${ERROR}Invalid choice — enter 1-8 or q.${RESET}\n" ;;
        esac

        printf "\n${WHITE}Press Enter to return to the OG/Edits menu…${RESET}"
        read -r
    done
}

_exiff_export_csvs() {
    local ef_target="$1"
    printf "${CYAN}Exporting forensic CSV files to: %s${RESET}\n\n" "$ef_target"

    exiftool -api QuickTimeUTC=1 -n \
        -if '$Make eq "Apple" and $Model =~ /iPhone/ and $Software =~ /^[0-9]+\.[0-9]/ and not defined $CompressorName and abs($FileModifyDate - $CreateDate) < 3600' \
        -csv -r \
        -FileName -Make -Model -Software -CompressorName \
        -CreateDate -FileModifyDate \
        -ImageWidth -ImageHeight -AspectRatio \
        -VideoFrameRate -Duration -AvgBitrate \
        -GPSLatitude -GPSLongitude -FileSize \
        "$ef_target" > "${ef_target}/audit_STRICT_originals.csv" 2>/dev/null
    printf "${SUCCESS}✅ audit_STRICT_originals.csv${RESET}\n"

    exiftool -api QuickTimeUTC=1 -n \
        -if '$Software =~ /QuickTime/ or defined $CompressorName or abs($FileModifyDate - $CreateDate) > 3600' \
        -csv -r \
        -FileName -Make -Model -Software -CompressorName \
        -CreateDate -FileModifyDate \
        -ImageWidth -ImageHeight -AspectRatio \
        -VideoFrameRate -Duration -AvgBitrate \
        -GPSLatitude -GPSLongitude -FileSize \
        "$ef_target" > "${ef_target}/audit_EDIT_indicators.csv" 2>/dev/null
    printf "${SUCCESS}✅ audit_EDIT_indicators.csv${RESET}\n"

    exiftool -api QuickTimeUTC=1 -n \
        -if '$ImageWidth % 16 != 0 or $ImageHeight % 16 != 0 or ($ImageWidth/$ImageHeight != 16/9 and $ImageWidth/$ImageHeight != 4/3 and $ImageWidth/$ImageHeight != 3/4 and $ImageWidth/$ImageHeight != 9/16)' \
        -csv -r \
        -FileName -Make -Model -Software -CompressorName \
        -CreateDate -FileModifyDate \
        -ImageWidth -ImageHeight -AspectRatio \
        -VideoFrameRate -Duration -AvgBitrate \
        -GPSLatitude -GPSLongitude -FileSize \
        "$ef_target" > "${ef_target}/audit_UNUSUAL_dimensions.csv" 2>/dev/null
    printf "${SUCCESS}✅ audit_UNUSUAL_dimensions.csv${RESET}\n"

    exiftool -api QuickTimeUTC=1 -n \
        -if 'not defined $Make or $Make ne "Apple"' \
        -csv -r \
        -FileName -Make -Model -Software -CompressorName \
        -CreateDate -FileModifyDate \
        -ImageWidth -ImageHeight -AspectRatio \
        -VideoFrameRate -Duration -AvgBitrate \
        -GPSLatitude -GPSLongitude -FileSize \
        "$ef_target" > "${ef_target}/audit_NON_APPLE_metadata.csv" 2>/dev/null
    printf "${SUCCESS}✅ audit_NON_APPLE_metadata.csv${RESET}\n"

    printf "\n${SUCCESS}All CSVs saved in: %s${RESET}\n" "$ef_target"
}

# ==============================================================================
# BANNER
# ==============================================================================

show_banner() {
    printf "\n${HEADER}"
    printf "╔══════════════════════════════════════════════════════╗\n"
    printf "║       📹  ProVid — Professional Video Organizer      ║\n"
    printf "║                      v3.1                            ║\n"
    printf "╚══════════════════════════════════════════════════════╝\n"
    printf "${RESET}\n"
}

# ==============================================================================
# TRAPS
# ==============================================================================

trap cleanup_and_exit EXIT
trap rollback INT TERM

# ==============================================================================
# STARTUP
# ==============================================================================

check_dependencies || exit 1

# ==============================================================================
# MAIN: RESUME OR START NEW SESSION
# ==============================================================================

if check_for_resume; then
    sorting_mode="$SESSION_MODE"
    file_prefix="$SESSION_PREFIX"
    inputFolder="$SESSION_INPUT_FOLDER"

    printf "%s\n" "${GREEN}🎯 Resumed mode:   $sorting_mode${RESET}"
    printf "%s\n" "${GREEN}📛 Resumed prefix: ${file_prefix:-None}${RESET}"
    printf "%s\n" "${GREEN}📁 Resumed folder: $inputFolder${RESET}"

    create_folder_structure "$inputFolder" "$sorting_mode"

    checksum=""
    for checksum in "${(@k)SESSION_PROCESSED_FILES}"; do
        file_hashes[$checksum]=1
    done

else
    # ── Mode selection ──────────────────────────────────────────────────────
    sorting_mode=""
    while [[ -z "$sorting_mode" ]]; do
        show_banner
        printf "${WHITE}  ── Rename & Organize ──────────────────────────────${RESET}\n"
        printf "${RED}    1.  ProVid    ${WHITE}— rename: resolution + orientation + FPS + emojis${RESET}\n"
        printf "${BLUE}    2.  VidRes    ${WHITE}— sort into 4K / 1080p / 720p / SD folders${RESET}\n"
        printf "${GREEN}    3.  ProMax    ${WHITE}— sort by resolution + orientation${RESET}\n"
        printf "${YELLOW}    4.  MaxVid    ${WHITE}— sort by resolution + orientation + FPS${RESET}\n"
        printf "${MAGENTA}    5.  KeepName  ${WHITE}— sort into folders, keep original filenames${RESET}\n"
        printf "${YELLOW}    6.  Emoji     ${WHITE}— emoji-only filenames (📱🌍 001.mov)${RESET}\n"
        printf "${WHITE}  ── Analysis ────────────────────────────────────────${RESET}\n"
        printf "${ORANGE}    7.  OG/Edits  ${WHITE}— check if videos are original or re-exported${RESET}\n"
        printf "${WHITE}  ── Tools ───────────────────────────────────────────${RESET}\n"
        printf "${CYAN}    8.  1MinVid   ${WHITE}— stamp new dates onto videos, 1 minute apart${RESET}\n"
        printf "${GREEN}    9.  MetaMov   ${WHITE}— smart date fix: iPhone chrono or download order${RESET}\n"
        printf "${RED}   10.  MuteVid   ${WHITE}— strip audio & metadata from videos${RESET}\n"
        printf "${MAGENTA}   11.  Slo-Mo    ${WHITE}— create slow-motion versions${RESET}\n"
        printf "${WHITE}────────────────────────────────────────────────────${RESET}\n"
        printf "${WHITE}  All modes accept a folder OR individual video files.\n${RESET}"
        printf "${WHITE}────────────────────────────────────────────────────${RESET}\n"
        read -r choice?"${WHITE}  Enter a number (1-11, q=quit): ${RESET}"
        case "$choice" in
            1)  sorting_mode="ProVid"   ;;
            2)  sorting_mode="VidRes"   ;;
            3)  sorting_mode="ProMax"   ;;
            4)  sorting_mode="MaxVid"   ;;
            5)  sorting_mode="KeepName" ;;
            6)  sorting_mode="EmojiVid" ;;
            7)  sorting_mode="OG/Edits" ;;
            8)  sorting_mode="1MinVid"  ;;
            9)  sorting_mode="MetaMov"  ;;
            10) sorting_mode="MuteVid"  ;;
            11) sorting_mode="Slo-Mo"   ;;
            [qQ])
                printf "\n%s\n" "${YELLOW}Aborting session.${RESET}"
                exit 0
                ;;
            *)
                printf "\n%s\n\n" \
                    "${ERROR}${CROSS} Invalid choice. Enter 1-11 or 'q'.${RESET}" >&2
                ;;
        esac
    done

    # ── Dispatch standalone tools ───────────────────────────────────────────
    case "$sorting_mode" in
        "1MinVid")  run_fixvid;       exit 0 ;;
        "MetaMov")  run_metamov;      exit 0 ;;
        "MuteVid")  run_mute;         exit 0 ;;
        "Slo-Mo")   run_slomov;       exit 0 ;;
        "OG/Edits") run_exiff_audit;  exit 0 ;;
    esac

    # ── Prompt colour per organizer mode ───────────────────────────────────
    PROMPT_COLOR=""
    case "$sorting_mode" in
        "ProVid")   PROMPT_COLOR="$RED"     ;;
        "VidRes")   PROMPT_COLOR="$BLUE"    ;;
        "ProMax")   PROMPT_COLOR="$GREEN"   ;;
        "MaxVid")   PROMPT_COLOR="$YELLOW"  ;;
        "KeepName") PROMPT_COLOR="$MAGENTA" ;;
        "EmojiVid") PROMPT_COLOR="$YELLOW"  ;;
        *)          PROMPT_COLOR="$WHITE"   ;;
    esac
    printf "%s\n" "${PROMPT_COLOR}🎯 Selected mode: $sorting_mode${RESET}"

    # ── Optional filename prefix ────────────────────────────────────────────
    file_prefix=""
    if [[ "$sorting_mode" == "KeepName" ]]; then
        printf "%s\n" "${PROMPT_COLOR}📛 Prefix: not used in KeepName mode${RESET}"
    else
        printf "%s" "${PROMPT_COLOR}Prefix for filenames (or press Enter to skip): ${RESET}"
        read -r file_prefix
        file_prefix=$(sanitize_title "$file_prefix")
        printf "%s\n" "${PROMPT_COLOR}📛 File Prefix: ${file_prefix:-None}${RESET}"
    fi

    # ── Drag-and-drop input: folder OR individual video files ───────────────
    printf "%s\n" \
        "${PROMPT_COLOR}📁 Drop a folder or video files here, then press [Enter]:${RESET}"
    raw_drop=""
    read -r raw_drop

    video_files_raw=()
    collect_video_inputs "$raw_drop" video_files_raw
    inputFolder="$_COLLECT_BASE_DIR"

    if [[ -z "$inputFolder" ]]; then
        printf "%s\n" "${ERROR}${CROSS} Could not determine a valid base directory.${RESET}" >&2
        exit 1
    fi

    if [[ ${#video_files_raw[@]} -eq 0 ]]; then
        printf "\n%s\n" "${YELLOW}⚠️  No video files found. Exiting.${RESET}"
        exit 0
    fi

    create_folder_structure "$inputFolder" "$sorting_mode" || exit 1

    total_files=${#video_files_raw[@]}
    processed_count=0
    start_time=$SECONDS

    load_metadata_cache

    # ── Preview mode ────────────────────────────────────────────────────────
    if [[ $PREVIEW_MODE -eq 1 ]]; then
        printf "\n%s\n" "${HEADER}📋 Preview — Files to Process${RESET}"
        printf -- "${BLUE}─────────────────────────────────${RESET}\n"
        printf "${WHITE}Total files:  ${CYAN}%d${RESET}\n"  "$total_files"
        printf "${WHITE}Mode:         ${CYAN}%s${RESET}\n"  "$sorting_mode"
        printf "${WHITE}Prefix:       ${CYAN}%s${RESET}\n"  "${file_prefix:-None}"
        printf "${WHITE}Base folder:  ${CYAN}%s${RESET}\n"  "$inputFolder"
        if [[ $BACKUP_MODE -eq 1 ]]; then
            printf "${GREEN}💾 Backup mode: files will be COPIED (originals kept)${RESET}\n"
        else
            printf "${YELLOW}📦 Standard mode: files will be MOVED${RESET}\n"
        fi
        printf -- "${BLUE}─────────────────────────────────${RESET}\n"
        printf "${WHITE}Sample files:${RESET}\n"
        sample_count=0; file=""
        for file in "${video_files_raw[@]}"; do
            printf "  ${CYAN}%s${RESET}\n" "${file##*/}"
            ((sample_count++))
            (( sample_count >= 10 )) && break
        done
        (( total_files > 10 )) && printf "  ${YELLOW}… and %d more${RESET}\n" "$((total_files - 10))"
        printf "\n"
        read -r answer?"${WHITE}Proceed? (Y/n): ${RESET}"
        if [[ ! "${answer:-Y}" =~ ^[Yy]$ ]] && [[ -n "$answer" ]]; then
            printf "%s\n" "${YELLOW}Cancelled.${RESET}"; exit 0
        fi
        printf "\n"
    fi

    printf "%s\n" "${BLUE}🎬 Processing $total_files video(s) in $sorting_mode mode…${RESET}" >&2

    PROCESSING_START_TIME=$SECONDS
    FILES_PROCESSED_FOR_ETA=0

    file_index=1; file=""
    for file in "${video_files_raw[@]}"; do
        display_progress_bar "$file_index" "$total_files" "$file"
        process_video "$file" "$file_index" "$sorting_mode"
        ((file_index++))
        ((processed_count++))
        ((FILES_PROCESSED_FOR_ETA++))

        (( processed_count % 20 == 0 )) && \
            save_session_state "$inputFolder" "$sorting_mode" "$file_prefix" "$processed_count"
    done

    printf "\r%80s\r" ""

    save_session_state  "$inputFolder" "$sorting_mode" "$file_prefix" "$processed_count"
    save_metadata_cache

    if (( processed_count >= total_files && total_files > 0 )); then
        rm -f "$SESSION_STATE_FILE"
        log $LOG_LEVEL_INFO "All files processed — session state cleared"
    fi

fi  # end of check_for_resume else branch
