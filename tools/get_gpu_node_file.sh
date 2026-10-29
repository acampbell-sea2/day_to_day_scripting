#!/bin/bash

set -euo pipefail

echo "=================================="
echo " GPU File Transfer Tool"
echo "=================================="
echo

#prompt uuser for infroamtion
read -rp "Enter GPU node (e.g., gpu002): " GPU_NODE
read -rp "Enter filename (e.g., pcie_errors.txt): " FILENAME
read -rp "Enter windows username: " WIN_USER

#valdiate inputs
if [[ -z "$GPU_NODE" || -z "$FILENAME" || -z "$WIN_USER" ]]; then
        echo "ERROR: All three fields are required!"
        exit 1
fi

if [[ ! "$GPU_NODE" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo "ERROR: Invalid GPU Node name."
        exit 1
fi

if [[ "$FILENAME" == */* || "$FILENAME" == "." || "$FILENAME" == ".." ]]; then
        echo "ERROR: Enter a filename, not a path."
        exit 1
fi

#config
GPU_HOST="${GPU_NODE}.o1.local"
GPU_USER="dc-support"
REMOTE_DIR="/home/dc-support"
JUMP_HOSTS="dcops@10.0.96.100, ubuntu@10.1.11.117"


LOCAL_FILE="$HOME/$FILENAME"
WINDOWS_DIR="/mnt/c/Users/$WIN_USER/Downloads"

#verify windows downloads directory exists
if [[ ! -d "$WINDOWS_DIR" ]]; then
        echo "ERROR: Windows downloads folderr not found!"
        echo "$WINDOWS_DIR"
        exit 1
fi

echo
echo "=================================="
echo "        TRANSFER DETAILS"
echo "=================================="
echo "GPU Node:  $GPU_HOST"
echo "File:      $FILENAME"
echo "Windows:   $WIN_USER"
echo "==================================="
echo

#step 1: scp file from GPU node to WSL
echo "Connectiong to $GPU_HOST..."

scp -J "$JUMP_HOSTS" \
        "${GPU_USER}@${GPU_HOST}:${REMOTE_DIR}/${FILENAME}"\
        "$LOCAL_FILE"

echo
echo "SCP transfer successful."
echo

#Step 2 Copy file into windows download
echo "Copying file to Windows downloads..."

cp -- "$LOCAL_FILE" "$WINDOWS_DIR/"

echo
echo "==================================="
echo "       TRANSFER COMPLETE"
echo "==================================="
echo "Node:        $GPU_NODE"
echo "File:        $FILENAME"
echo "Saved to:    $WINDOWS_DIR/$FILENAME"
echo "==================================="
