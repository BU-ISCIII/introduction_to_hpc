  #!/usr/bin/env bash
  set -euo pipefail

  # Defaults
  BASE="/scratch/hpc_course"
  DAYS=2
  MODE="temps"      # temps|stale
  FORCE=0
  DEBUG=0
  KEEP_PATTERNS=()   # Only applies to 'stale' (name patterns to keep)
  STALE_MAXDEPTH=4    # Recursive activity scan depth (project root is depth 0)

  # Slurm: default configuration (overridable via environment variables)
  SRUN_PART="${SRUN_PART:-short_idx}"
  SRUN_TIME="${SRUN_TIME:-00:10:00}"
  SRUN_CPUS="${SRUN_CPUS:-1}"
  SRUN_MEM="${SRUN_MEM:-1G}"
  SRUN_ACCOUNT="${SRUN_ACCOUNT:-}"
  SRUN_EXTRA="${SRUN_EXTRA:-}"
  SRUN_ARGS=(
    --partition="$SRUN_PART"
    --time="$SRUN_TIME"
    --cpus-per-task="$SRUN_CPUS"
    --mem="$SRUN_MEM"
    --quiet
  )
  if [[ -n "$SRUN_ACCOUNT" ]]; then SRUN_ARGS+=(--account="$SRUN_ACCOUNT"); fi
  if [[ -n "$SRUN_EXTRA" ]]; then
    # Allow passing extra flags as string (e.g. "--qos short --constraint NVME")
    read -r -a _EXTRA_ARR <<< "$SRUN_EXTRA"
    SRUN_ARGS+=("${_EXTRA_ARR[@]}")
  fi

  usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

  -m, --mode   Cleanup mode: temps (default) or stale
  -d, --days   Age in days (stale mode only; default 2). With 0, no age filter
  -x, --maxdepth  Recursive activity scan depth (stale mode only; default 4)
  -b, --base   Base directory (default: /scratch/hpc_course)
  -k, --keep   Name pattern to keep (repeatable; stale mode only)
      --debug  Show one recent path for each project excluded from stale results
  -f, --force  Perform deletion (default: dry-run)
  -h, --help   Show this help

Examples:
  # Old temporaries (dry-run)
  cleanup_scratch.sh -m temps -d 3

  # Top-level folders with no recent activity down to depth 4 (dry-run)
  cleanup_scratch.sh -m stale

  # Check recent activity down to depth 6
  cleanup_scratch.sh -m stale --maxdepth 6

  # Explain why projects are considered active
  cleanup_scratch.sh -m stale --debug

  # Actually delete, keeping folders matching "refs" or "important*"
  cleanup_scratch.sh -m stale -f -k refs -k 'important*'
EOF
  }

  # Colors (enabled for TTYs with >=8 colors)
  if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ $(tput colors) -ge 8 ]]; then
    BOLD="$(tput bold)"; RESET="$(tput sgr0)"
    RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; BLUE="$(tput setaf 4)"; MAGENTA="$(tput setaf 5)"; CYAN="$(tput setaf 6)"
  else
    BOLD=""; RESET=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""
  fi

  # Simple flags parsing
  while [[ ${1:-} ]]; do
    case "$1" in
      -m|--mode) MODE="$2"; shift 2 ;;
      -d|--days) DAYS="$2"; shift 2 ;;
      -x|--maxdepth) STALE_MAXDEPTH="$2"; shift 2 ;;
      -b|--base) BASE="$2"; shift 2 ;;
      -k|--keep) KEEP_PATTERNS+=("$2"); shift 2 ;;
      --debug) DEBUG=1; shift ;;
      -f|--force) FORCE=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unrecognized option: $1"; usage; exit 1 ;;
    esac
  done

  # Safety: require BASE under /scratch
  if [[ "$BASE" != /scratch/* ]]; then
    echo "ERROR: BASE must be under /scratch (current: $BASE)" >&2
    exit 1
  fi

  if [[ ! "$STALE_MAXDEPTH" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --maxdepth must be a non-negative integer (current: $STALE_MAXDEPTH)" >&2
    exit 1
  fi

  # Helper: confirm and execute deletion
confirm_and_delete() {
  local prompt="$1"; shift
  local del_cmd=("$@")

  if (( FORCE )); then
    read -rp "$prompt [y/N] " ans
    [[ "${ans:-N}" =~ ^[Yy]$ ]] || { echo "Cancelled"; return 0; }
    "${del_cmd[@]}"
  else
    echo "(simulation mode: add --force to delete)"
  fi
}

# Evaluate deletion permissions for the provided directories on a compute node
check_directories() {
  local dirs=("$@")

  DELETABLE=()
  BLOCKED_REPORT=()
  
  # check if no dirs to check and return early
  ((${#dirs[@]})) || return 0

  local list_file
  list_file="$(mktemp "$(pwd)/.cleanup_scratch.check.XXXXXX")"  # Persist list for the compute node
  printf '%s\n' "${dirs[@]}" > "$list_file"                      # One path per line (read back inside srun)

  mapfile -t CHECK_RESULTS < <(
    srun "${SRUN_ARGS[@]}" bash -s "$list_file" <<'EOF'
set -euo pipefail

LIST_FILE=$1

while IFS= read -r dir; do
  [[ -z "$dir" ]] && continue              # Skip empty lines

  parent=${dir%/*}
  [[ -z "$parent" ]] && parent='/'

  if ! test -w "$parent" -a -x "$parent"; then       # Need w+x on parent to remove child
    who=$(stat -c '%U:%G %A' "$parent" 2>/dev/null || echo '?')
    printf 'BLOCK|%s|NON-WRITABLE PARENT: %s [%s]\n' "$dir" "$parent" "$who"
    continue
  fi

  first_block=$(find "$dir" -type d \
    \( ! -writable -o ! -executable \) -printf '%M %u:%g %p\n' -quit 2>/dev/null || true)
  if [[ -n "$first_block" ]]; then
    printf 'BLOCK|%s|INNER DIR WITHOUT PERMS: %s\n' "$dir" "$first_block"  # Report first offending directory
    continue
  fi

  immutable_path=$(command -v lsattr >/dev/null 2>&1 && lsattr -Rd "$dir" 2>/dev/null | awk '/\si\s/ {sub(/^.*\s/, ""); print; exit}' || true)
  if [[ -n "$immutable_path" ]]; then
    printf 'BLOCK|%s|IMMUTABLE ATTRIBUTE: %s (+i)\n' "$dir" "$immutable_path"  # Immutable items cannot be removed
    continue
  fi

  printf 'OK|%s|\n' "$dir"                    # Directory passes all checks
done < "$LIST_FILE"
EOF
  )

  rm -f -- "$list_file"  # Drop temporary manifest

  local line status path reason
  for line in "${CHECK_RESULTS[@]}"; do
    IFS='|' read -r status path reason <<<"$line"
    if [[ "$status" == "OK" ]]; then
      DELETABLE+=("$path")
    else
      BLOCKED_REPORT+=("$path|$reason")
    fi
  done
}

if [[ "$MODE" == "temps" ]]; then
  AGE_DESC="without age filter (temps mode ignores --days)"

  echo "${CYAN}[srun:${SRUN_PART}]${RESET} Searching temporary folders (${AGE_DESC}) in ${BASE} (work*, tmp*, .nextflow*) excluding .Trash-*, lost+found, .snapshot(s)"
  # Collect candidates (listing on compute node)
  mapfile -t CANDIDATES < <(
    srun "${SRUN_ARGS[@]}" \
      find "$BASE" -maxdepth 3 \
        \( -path '*/.Trash-*' -o -name 'lost+found' -o -path '*/.snapshot' -o -path '*/.snapshots' \) -prune -o \
        \( -name 'work' -o -name 'work_*' -o -name 'tmp' -o -name 'tmp_*' -o -name '.nextflow*' \) \
        -type d -print | sort
    )

    if ((${#CANDIDATES[@]}==0)); then
      echo "${YELLOW}No temporary candidates to delete.${RESET}"
      exit 0
    fi

    check_directories "${CANDIDATES[@]}"

    echo "${BOLD}Candidates:${RESET} ${#CANDIDATES[@]}"
    echo "${GREEN}Deletable:${RESET} ${#DELETABLE[@]}"
    if ((${#DELETABLE[@]} > 0)); then
      printf '  %s\n' "${DELETABLE[@]}"
    fi
    echo "${YELLOW}Blocked:${RESET} ${#BLOCKED_REPORT[@]}"
    if ((${#BLOCKED_REPORT[@]} > 0)); then
      for line in "${BLOCKED_REPORT[@]}"; do
        IFS='|' read -r base reason <<<"$line"
        echo "  ${YELLOW}$base${RESET} -> $reason"
      done
      echo "${BLUE}Hint:${RESET} ask the indicated owner or support to adjust permissions/ACLs or delete the folder."
    fi

    if (( FORCE )); then
      read -rp "${RED}Delete the deletable directories?${RESET} [y/N] " ans
      [[ "${ans:-N}" =~ ^[Yy]$ ]] || { echo "${YELLOW}Cancelled${RESET}"; exit 0; }
      if ((${#DELETABLE[@]} > 0)); then
        DEL_FILE="$(pwd)/.cleanup_scratch.to_delete.$USER.$$"
        printf '%s\0' "${DELETABLE[@]}" > "$DEL_FILE"
        echo "${CYAN}[srun:${SRUN_PART}]${RESET} Deleting ${#DELETABLE[@]} directories on compute node"
        srun "${SRUN_ARGS[@]}" bash -lc "xargs -0 rm -rf < \"$DEL_FILE\""
        rm -f -- "$DEL_FILE"
      else
        echo "${YELLOW}No deletable directories (insufficient permissions).${RESET}"
      fi
    else
      echo "${BLUE}(simulation mode: add --force to delete)${RESET}"
    fi

elif [[ "$MODE" == "stale" ]]; then
  if [[ ${DAYS} -gt 0 ]]; then
    AGE_DESC="with no activity in the last ${DAYS} days"
  else
    AGE_DESC="without age filter"
  fi

  echo "${CYAN}[srun:${SRUN_PART}]${RESET} Searching top-level folders ${AGE_DESC} in ${BASE} (activity scan maxdepth ${STALE_MAXDEPTH}; excluding work/work_*, .Trash-*, lost+found, .snapshot(s))"
    # Collect top-level candidates (listing on compute node)
    if [[ ${DAYS} -gt 0 ]]; then
      mapfile -t CANDIDATES < <(
        srun "${SRUN_ARGS[@]}" bash -s -- "$BASE" "$DAYS" "$STALE_MAXDEPTH" "$DEBUG" <<'EOF'
set -euo pipefail

base=$1
days=$2
maxdepth=$3
debug=$4

find "$base" -mindepth 1 -maxdepth 1 \
  \( -name 'lost+found' -o -name '.snapshot' -o -name '.snapshots' -o -name '.Trash-*' \) -prune -o \
  -type d -print0 |
while IFS= read -r -d '' project; do
  # A project is stale only when neither its root nor any inspected entry is
  # recent. Work directories are pruned because their transient files should
  # not keep an otherwise inactive project alive.
  recent_path=$(find "$project" -maxdepth "$maxdepth" \
      \( -type d \( -name 'work' -o -name 'work_*' \) -prune \) -o \
      -newermt "$days days ago" -print -quit 2>/dev/null || true)

  if [[ -z "$recent_path" ]]; then
    printf '%s\n' "$project"
  elif (( debug )); then
    printf '[debug] ACTIVE: %s\n' "$project" >&2
    stat -c '        recent: %y | %F | %n' -- "$recent_path" >&2 || \
      printf '        recent: %s\n' "$recent_path" >&2
  fi
done | sort
EOF
      )
    else
      mapfile -t CANDIDATES < <(
        srun "${SRUN_ARGS[@]}" \
          find "$BASE" -mindepth 1 -maxdepth 1 \
            \( -name 'lost+found' -o -name '.snapshot' -o -name '.snapshots' -o -name '.Trash-*' \) -prune -o \
            -type d -print | sort
      )
    fi

    # Filter by name patterns to keep
    TO_DELETE=()
    for d in "${CANDIDATES[@]:-}"; do
      name="$(basename "$d")"
      keep=0
      for pat in "${KEEP_PATTERNS[@]:-}"; do
        if [[ "$name" == $pat ]]; then
          keep=1; break
        fi
      done
      (( keep )) || TO_DELETE+=("$d")
    done

    if ((${#TO_DELETE[@]}==0)); then
      echo "${YELLOW}No candidate folders to delete.${RESET}"
      exit 0
    fi

    check_directories "${TO_DELETE[@]}"

    echo "${BOLD}Candidates:${RESET} ${#TO_DELETE[@]}"
    echo "${GREEN}Deletable:${RESET} ${#DELETABLE[@]}"
    if ((${#DELETABLE[@]} > 0)); then
      printf '  %s\n' "${DELETABLE[@]}"
    fi
    echo "${YELLOW}Blocked:${RESET} ${#BLOCKED_REPORT[@]}"
    if ((${#BLOCKED_REPORT[@]} > 0)); then
      for line in "${BLOCKED_REPORT[@]}"; do
        IFS='|' read -r base reason <<<"$line"
        echo "  ${YELLOW}$base${RESET} -> $reason"
      done
      echo "${BLUE}Hint:${RESET} ask the indicated owner or support to adjust permissions/ACLs or delete the folder."
    fi

    # Deletion
    if (( FORCE )); then
      read -rp "${RED}Delete the listed directories?${RESET} [y/N] " ans
      [[ "${ans:-N}" =~ ^[Yy]$ ]] || { echo "${YELLOW}Cancelled${RESET}"; exit 0; }
      if ((${#DELETABLE[@]} > 0)); then
        # Generate list in a shared file under BASE to process on compute node
        DEL_FILE="$(pwd)/.cleanup_scratch.to_delete.$USER.$$"
        printf '%s\0' "${DELETABLE[@]}" > "$DEL_FILE"
        echo "${CYAN}[srun:${SRUN_PART}]${RESET} Deleting ${#DELETABLE[@]} directories on compute node"
        srun "${SRUN_ARGS[@]}" bash -lc "xargs -0 rm -rf < \"$DEL_FILE\""
        rm -f -- "$DEL_FILE"
      else
        echo "${YELLOW}No deletable directories (insufficient permissions).${RESET}"
      fi
    else
      echo "${BLUE}(simulation mode: add --force to delete)${RESET}"
    fi

  else
    echo "${RED}ERROR:${RESET} unrecognized mode: $MODE (use temps|stale)" >&2
    exit 1
  fi
