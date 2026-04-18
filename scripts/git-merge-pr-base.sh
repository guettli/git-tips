#!/usr/bin/env bash
# Bash Strict Mode: https://github.com/guettli/bash-strict-mode
trap 'echo -e "\n🤷 🚨 🔥 Warning: A command has failed. Exiting the script. Line was ($0:$LINENO): $(sed -n "${LINENO}p" "$0" 2>/dev/null || true) 🔥 🚨 🤷 "; exit 3' ERR
set -Eeuo pipefail

usage() {
    echo "Usage: $(basename "$0")"
    echo
    echo "Merge the current PR base branch into the current branch."
    echo
    echo "Requires: gh"
    echo "Reason: Git has no concept of pull requests or a PR base branch,"
    echo "so this script uses GitHub CLI to resolve the base branch first."
}

if [[ $# -gt 0 ]]; then
    usage
    exit 1
fi

remote=$(git config branch."$(git branch --show-current)".remote)
if [[ -z "$remote" ]]; then
    echo "Failed to find remote. (often it is origin)"
    exit 1
fi

pr_base=$(gh pr view --json baseRefName --jq "\"$remote/\" + .baseRefName")
if [[ -z "$pr_base" ]]; then
    echo "Failed to find pr base"
    exit 1
fi
echo "PR base: $pr_base"
git merge "$pr_base"
