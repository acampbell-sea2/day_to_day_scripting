}

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

while (($#)); do
    case "$1" in
        --host|--user|--output|--windows-user|--identify)
            (($# >= 2)) || fail "$1 requires a value"
            case "$1" in
                --host) HOST=$2 ;;
                --user) REMOTE_USER=$2 ;;
                --output) OUTPUT_FILE=$2 ;;
                --windows-user) WINDOWS_USER=$2 ;;
                --identify) IDENTIFY=$2 ;;
            esac
            shift 2
            ;;
        --full) FULL=1; shift ;;
        --optics) OPTICS=1; shift ;;
        --no-sudo) USE_SUDO=0; shift ;;
        --direct) DIRECT=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "unknown option: $1 (use --help)" ;;
    esac
done

[[ -f "$COLLECTOR" && -r "$COLLECTOR" ]] || fail "collector not found: $COLLECTOR (keep both scripts in the same folder)"
command -v ssh >/dev/null 2>&1 || fail "OpenSSH client not found in WSL"

if [[ -z "$HOST" ]]; then
    [[ -t 0 ]] || fail "provide --host HOST when running non-interactively"
    read -r -p 'Remote host (e.g., gpu0143, pve4, or full FQDN): ' HOST
fi
[[ "$HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] && [[ "$HOST" != *..* ]] || fail "invalid hostname: $HOST"

# Preserve the existing GPU naming convention, but do not force it on other hosts.
if [[ "$HOST" =~ ^gpu[0-9]+$ ]]; then
    HOST="${HOST}.o1.local"
fi

if [[ -z "$REMOTE_USER" ]]; then
    case "$HOST" in
        gpu[0-9]*.o1.local) REMOTE_USER=dc-support ;;
        pve[0-9]*) REMOTE_USER=root ;;
        *) REMOTE_USER=$(id -un) ;;
    esac
fi
[[ "$REMOTE_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*$ ]] || fail "invalid SSH user: $REMOTE_USER"
[[ -z "$WINDOWS_USER" || "$WINDOWS_USER" =~ ^[a-zA-Z0-9_.-]+$ ]] || fail "invalid Windows username"
[[ -z "$IDENTIFY" || "$IDENTIFY" =~ ^[a-zA-Z0-9_.:-]+$ ]] || fail "invalid interface name for --identify"
[[ -z "$IDENTIFY" || ( $FULL -eq 0 && $OPTICS -eq 0 ) ]] || fail "--identify cannot be combined with --full or --optics"
[[ -z "$IDENTIFY" || -z "$OUTPUT_FILE" ]] || fail "--identify does not generate an output file"
[[ -z "$IDENTIFY" || -z "$WINDOWS_USER" ]] || fail "--identify does not generate a report to copy"

COLLECTOR_ARGS=()
if [[ -n "$IDENTIFY" ]]; then
    COLLECTOR_ARGS+=(--identify "$IDENTIFY")
else
    (( FULL == 0 )) || COLLECTOR_ARGS+=(--full)
    (( OPTICS == 0 )) || COLLECTOR_ARGS+=(--optics)
fi

# Quote arguments for the remote login shell. The invoked program is Bash.
REMOTE_ARGS=""
for arg in "${COLLECTOR_ARGS[@]}"; do
    printf -v q '%q' "$arg"
    REMOTE_ARGS+=" $q"
done

if (( USE_SUDO )); then
    # sudo -n never reads a password from stdin (which contains the script).
    # Without passwordless sudo, run unprivileged rather than failing silently.
    REMOTE_COMMAND="if [ \"\$(id -u)\" -eq 0 ]; then exec bash -s --${REMOTE_ARGS}; elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then exec sudo -n bash -s --${REMOTE_ARGS}; else echo 'WARNING: Remote sudo -n unavailable; collecting unprivileged (some fields may be N/A).' >&2; exec bash -s --${REMOTE_ARGS}; fi"
else
    REMOTE_COMMAND="exec bash -s --${REMOTE_ARGS}"
fi

SSH_ARGS=(-T -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=accept-new)
if (( !DIRECT )); then SSH_ARGS+=(-J "$JUMP_HOSTS"); fi
SSH_ARGS+=("${REMOTE_USER}@${HOST}" "$REMOTE_COMMAND")

printf 'Target:     %s@%s\n' "$REMOTE_USER" "$HOST"
if (( DIRECT )); then
    printf 'SSH route:  Direct\n'
else
    printf 'SSH route:  %s\n' "$JUMP_HOSTS"
fi

if [[ -n "$IDENTIFY" ]]; then
    printf 'Action:     Identify %s LED for 15 seconds (not an inventory report)\n' "$IDENTIFY"
    exec ssh "${SSH_ARGS[@]}" < "$COLLECTOR"
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    safe_host=${HOST//[^a-zA-Z0-9_.-]/_}
    stamp=$(date -u '+%Y%m%dT%H%M%SZ')
    OUTPUT_FILE="$OUTPUT_DIR/${safe_host}_network-inventory_${stamp}.txt"
fi
mkdir -p -- "$(dirname -- "$OUTPUT_FILE")"
[[ ! -e "$OUTPUT_FILE" ]] || fail "output file already exists: $OUTPUT_FILE"

# Save only a successful complete report under the requested name.
PARTIAL=$(mktemp "${OUTPUT_FILE}.partial.XXXXXXXX")
cleanup() { [[ -z "${PARTIAL:-}" ]] || rm -f -- "$PARTIAL"; }
trap cleanup EXIT
printf 'Local file: %s\n\n' "$OUTPUT_FILE"

if ssh "${SSH_ARGS[@]}" < "$COLLECTOR" | tee "$PARTIAL"; then
    mv -- "$PARTIAL" "$OUTPUT_FILE"
    PARTIAL=""
else
    fail "SSH or remote inventory failed; incomplete report was not saved"
fi

printf '\nReport saved locally in WSL: %s\n' "$OUTPUT_FILE"
if [[ -n "$WINDOWS_USER" ]]; then
    WINDOWS_DOWNLOADS="/mnt/c/Users/${WINDOWS_USER}/Downloads"
    [[ -d "$WINDOWS_DOWNLOADS" ]] || fail "report saved in WSL, but Windows Downloads folder is missing: $WINDOWS_DOWNLOADS"
    WINDOWS_FILE="$WINDOWS_DOWNLOADS/$(basename -- "$OUTPUT_FILE")"
    [[ ! -e "$WINDOWS_FILE" ]] || fail "report saved in WSL, but Windows file already exists: $WINDOWS_FILE"
    cp -- "$OUTPUT_FILE" "$WINDOWS_FILE"
    printf 'Copied to Windows: %s\n' "$WINDOWS_FILE"
fi
