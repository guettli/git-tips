#!/usr/bin/env bash
#
# Source: https://github.com/guettli/git-tips
#
# Bash Strict Mode: https://github.com/guettli/bash-strict-mode
trap 'echo -e "\n🤷 🚨 🔥 Warning: A command has failed. Exiting the script. Line was ($0:$LINENO): $(sed -n "${LINENO}p" "$0" 2>/dev/null || true) 🔥 🚨 🤷 "; exit 3' ERR
set -Eeuo pipefail

usage() {
    cat <<EOF
Usage: $0

Pull the current branch from origin, resolve the PR target branch via GitHub,
then merge origin/<target-branch> into the current branch.
EOF
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Error: Required command '$command_name' is not available."
        exit 1
    fi
}

if [[ $# -gt 0 ]]; then
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
fi

require_command git
require_command gh

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: This script must be run inside a git repository."
    exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    echo "Error: Git remote 'origin' is not configured."
    exit 1
fi

current_branch="$(git branch --show-current)"
if [[ -z "$current_branch" ]]; then
    echo "Error: Could not determine the current branch."
    echo "A detached HEAD is not supported."
    exit 1
fi

echo "Current branch: $current_branch"
echo "Pulling origin/$current_branch"
git pull --ff-only origin "$current_branch"

target_branch="$(gh pr view --json baseRefName --jq '.baseRefName')"
if [[ -z "$target_branch" ]]; then
    echo "Error: Could not determine the PR target branch via GitHub."
    exit 1
fi

echo "PR target branch: $target_branch"
echo "Fetching origin/$target_branch"
git fetch origin "$target_branch"

if [[ "$current_branch" == "$target_branch" ]]; then
    echo "Current branch already is the target branch. Nothing to merge."
    exit 0
fi

echo "Merging origin/$target_branch into $current_branch"
git merge "origin/$target_branch"
