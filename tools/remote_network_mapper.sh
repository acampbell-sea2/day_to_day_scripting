
#!/usr/bin/env bash
#
# Remote Linux Network / PCI Inventory
#
# Runs the local inventory script on a remote Linux host
# through two SSH jump hosts.
#
# WSL -> Jump Host 1 -> Jump Host 2 -> Target
#
# No installation is required on the remote host.
# The inventory script is streamed over SSH.
#

set -euo pipefail
umask 077

# --------------------------------------------------
# Configuration
# --------------------------------------------------

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

COLLECTOR="$SCRIPT_DIR/linux_network_interface_pci_mapper.sh"

JUMP_HOSTS=${JUMP_HOSTS:-dcops@10.0.96.100,ubuntu@10.1.11.117}

OUTPUT_DIR=${OUTPUT_DIR:-"$HOME/network-inventory-reports"}

HOST=""
REMOTE_USER=""
OUTPUT_FILE=""
WINDOWS_USER=""
FULL=0
OPTICS=0
DIRECT=0
USE_SUDO=1
IDENTIFY=""

# --------------------------------------------------
# Help
# --------------------------------------------------

usage() {
    cat <<'HELP'
Usage: ./remote_network_mapper.sh [OPTIONS]

Run a network and PCI inventory against a remote Linux
host using the configured SSH jump hosts.

Options:

  --host HOST         Target hostname, FQDN, or IP
  --user USER         Remote SSH username
  --full              Include detailed PCI information
  --optics            Include optical transceiver data
  --output FILE       Custom local report filename
  --windows-user USER Copy report to Windows Downloads
  --no-sudo           Run without remote sudo
  --direct            Connect without jump hosts
  --identify IFACE    Blink a NIC identification LED
  -h, --help          Display help

Default SSH route:

  dcops@10.0.96.100
          |
  ubuntu@10.1.11.117
          |
       Target

Examples:

  ./remote_network_mapper.sh --host gpu0143

  ./remote_network_mapper.sh --host gpu0319 --full --optics

  ./remote_network_mapper.sh --host pve4 --user root

  ./remote_network_mapper.sh --host gpu0143 --windows-user acampbell

  ./remote_network_mapper.sh --host gpu0143 --identify ens2f0np0

Short GPU names automatically receive the .o1.local suffix.

Inventory commands are read-only. The --identify option
requests a temporary NIC identification LED blink.

Reports may contain hardware serial numbers and MAC addresses.
Review reports before sharing them publicly.
HELP
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

# --------------------------------------------------
# Parse arguments
# --------------------------------------------------

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

        --full)
            FULL=1
            shift
            ;;

        --optics)
            OPTICS=1
            shift
            ;;

        --no-sudo)
            USE_SUDO=0
            shift
            ;;

        --direct)
            DIRECT=1
            shift
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            fail "Unknown option: $1"
            ;;
    esac
done

# --------------------------------------------------
# Verify prerequisites
# --------------------------------------------------

[[ -f "$COLLECTOR" && -r "$COLLECTOR" ]] ||
    fail "Inventory script not found: $COLLECTOR"

command -v ssh >/dev/null 2>&1 ||
    fail "SSH client is not installed"

# --------------------------------------------------
# Target selection
# --------------------------------------------------

if [[ -z "$HOST" ]]; then
    [[ -t 0 ]] ||
        fail "Use --host when running non-interactively"

    read -r -p "Enter remote hostname: " HOST
fi

[[ "$HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] &&
[[ "$HOST" != *..* ]] ||
    fail "Invalid hostname: $HOST"

# Automatically expand GPU node names
if [[ "$HOST" =~ ^gpu[0-9]+$ ]]; then
    HOST="${HOST}.o1.local"
fi

# Determine default remote username
if [[ -z "$REMOTE_USER" ]]; then
    case "$HOST" in
        gpu[0-9]*.o1.local)
            REMOTE_USER="dc-support"
            ;;
        pve[0-9]*)
            REMOTE_USER="root"
            ;;
        *)
            REMOTE_USER=$(id -un)
            ;;
    esac
fi

# Validate input values
[[ "$REMOTE_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*$ ]] ||
    fail "Invalid SSH username"

[[ -z "$WINDOWS_USER" ||
   "$WINDOWS_USER" =~ ^[a-zA-Z0-9_.-]+$ ]] ||
    fail "Invalid Windows username"

[[ -z "$IDENTIFY" ||
   "$IDENTIFY" =~ ^[a-zA-Z0-9_.:-]+$ ]] ||
    fail "Invalid interface name"

if [[ -n "$IDENTIFY" ]]; then
    (( FULL == 0 && OPTICS == 0 )) ||
        fail "--identify cannot be combined with --full or --optics"

    [[ -z "$OUTPUT_FILE" && -z "$WINDOWS_USER" ]] ||
        fail "--identify does not create a report"
fi

# --------------------------------------------------
# Build inventory arguments
# --------------------------------------------------

COLLECTOR_ARGS=()

if [[ -n "$IDENTIFY" ]]; then
    COLLECTOR_ARGS+=(--identify "$IDENTIFY")
else
    (( FULL == 0 )) || COLLECTOR_ARGS+=(--full)
    (( OPTICS == 0 )) || COLLECTOR_ARGS+=(--optics)
fi

# Safely quote arguments for remote Bash
REMOTE_ARGS=""

for arg in "${COLLECTOR_ARGS[@]}"; do
    printf -v quoted '%q' "$arg"
    REMOTE_ARGS+=" $quoted"
done

# --------------------------------------------------
# Remote privilege handling
# --------------------------------------------------

# sudo -n does not request a password.
# This is important because SSH stdin contains
# the inventory script itself.

if (( USE_SUDO )); then

    REMOTE_COMMAND="if [ \"\$(id -u)\" -eq 0 ]; then
        exec bash -s --${REMOTE_ARGS}
    elif command -v sudo >/dev/null 2>&1 &&
         sudo -n true >/dev/null 2>&1; then
        exec sudo -n bash -s --${REMOTE_ARGS}
    else
        echo 'WARNING: Passwordless sudo unavailable. Running unprivileged.' >&2
        exec bash -s --${REMOTE_ARGS}
    fi"

else
    REMOTE_COMMAND="exec bash -s --${REMOTE_ARGS}"
fi

# --------------------------------------------------
# Build SSH connection
# --------------------------------------------------

SSH_ARGS=(
    -T
    -o ConnectTimeout=15
    -o ServerAliveInterval=15
    -o ServerAliveCountMax=3
    -o StrictHostKeyChecking=accept-new
)

if (( !DIRECT )); then
    SSH_ARGS+=(-J "$JUMP_HOSTS")
fi

SSH_ARGS+=(
    "${REMOTE_USER}@${HOST}"
    "$REMOTE_COMMAND"
)

printf '\n'
printf '========================================\n'
printf ' REMOTE NETWORK INVENTORY\n'
printf '========================================\n'
printf 'Target: %s@%s\n' "$REMOTE_USER" "$HOST"

if (( DIRECT )); then
    printf 'SSH route: Direct\n'
else
    printf 'SSH route: %s\n' "$JUMP_HOSTS"
fi

# --------------------------------------------------
# Optional NIC identification
# --------------------------------------------------

if [[ -n "$IDENTIFY" ]]; then
    printf 'Identifying NIC: %s\n' "$IDENTIFY"

    exec ssh "${SSH_ARGS[@]}" < "$COLLECTOR"
fi

# --------------------------------------------------
# Create local report path
# --------------------------------------------------

if [[ -z "$OUTPUT_FILE" ]]; then

    SAFE_HOST=${HOST//[^a-zA-Z0-9_.-]/_}

    TIMESTAMP=$(date -u '+%Y%m%dT%H%M%SZ')

    OUTPUT_FILE="$OUTPUT_DIR/${SAFE_HOST}_network-inventory_${TIMESTAMP}.txt"
fi

mkdir -p -- "$(dirname -- "$OUTPUT_FILE")"

[[ ! -e "$OUTPUT_FILE" ]] ||
    fail "Output file already exists: $OUTPUT_FILE"

# Temporary file prevents incomplete reports from
# being mistaken for successful inventory results.

PARTIAL=$(mktemp "${OUTPUT_FILE}.partial.XXXXXXXX")

cleanup() {
    if [[ -n "${PARTIAL:-}" ]]; then
        rm -f -- "$PARTIAL"
    fi
}

trap cleanup EXIT

printf 'Report: %s\n\n' "$OUTPUT_FILE"

# --------------------------------------------------
# Run remote inventory
# --------------------------------------------------

if ssh "${SSH_ARGS[@]}" < "$COLLECTOR" | tee "$PARTIAL"; then

    mv -- "$PARTIAL" "$OUTPUT_FILE"
    PARTIAL=""

else
    fail "SSH connection or remote inventory failed"
fi

printf '\nInventory saved to:\n%s\n' "$OUTPUT_FILE"

# --------------------------------------------------
# Optional Windows Downloads copy
# --------------------------------------------------

if [[ -n "$WINDOWS_USER" ]]; then

    WINDOWS_DOWNLOADS="/mnt/c/Users/${WINDOWS_USER}/Downloads"

    [[ -d "$WINDOWS_DOWNLOADS" ]] ||
        fail "Windows Downloads folder not found: $WINDOWS_DOWNLOADS"

    WINDOWS_FILE="$WINDOWS_DOWNLOADS/$(basename -- "$OUTPUT_FILE")"

    [[ ! -e "$WINDOWS_FILE" ]] ||
        fail "Windows destination already exists: $WINDOWS_FILE"

    cp -- "$OUTPUT_FILE" "$WINDOWS_FILE"

    printf 'Copied to Windows:\n%s\n' "$WINDOWS_FILE"
fi

printf '\nInventory completed successfully.\n'
