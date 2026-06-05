#!/usr/bin/env bash
# Bash Strict Mode: https://github.com/guettli/bash-strict-mode
trap 'echo -e "\n🤷 🚨 🔥 Warning: A command has failed. Exiting the script. Line was ($0:$LINENO): $(sed -n "${LINENO}p" "$0" 2>/dev/null || true) 🔥 🚨 🤷 "; exit 3' ERR
set -Eeuo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0")

Merge the current PR/MR base branch into the current branch.

Runs:

    go run github.com/guettli/sync-branch@latest sync

Options:
  -h, --help Show this help

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "Error: Unknown argument '$1'"
        usage
        exit 1
        ;;
    esac
done

go run github.com/guettli/sync-branch@latest sync
