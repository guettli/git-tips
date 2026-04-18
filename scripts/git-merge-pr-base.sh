#!/usr/bin/env bash
# Bash Strict Mode: https://github.com/guettli/bash-strict-mode
trap 'echo -e "\n🤷 🚨 🔥 Warning: A command has failed. Exiting the script. Line was ($0:$LINENO): $(sed -n "${LINENO}p" "$0" 2>/dev/null || true) 🔥 🚨 🤷 "; exit 3' ERR
set -Eeuo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [--no-fetch] [--dry-run]

Merge the current PR base branch into the current branch.

If your branch was created from main, your PR base is usualy origin/main

Options:
  --no-fetch Skip fetching the PR base branch before merging
  --dry-run  Print the commands without executing them
  -h, --help Show this help

Requires: gh
Reason: Git has no concept of pull requests or a PR base branch,
so this script uses GitHub CLI to resolve the base branch first.
EOF
}

fetch_first=true
dry_run=false
while [[ $# -gt 0 ]]; do
    case "$1" in
    --no-fetch)
        fetch_first=false
        shift
        ;;
    --dry-run)
        dry_run=true
        shift
        ;;
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

remote=$(git config branch."$(git branch --show-current)".remote)
if [[ -z "$remote" ]]; then
    echo "Failed to find remote. (often it is 'origin')"
    exit 1
fi

base_ref_name=$(gh pr view --json baseRefName --jq '.baseRefName')
if [[ -z "$base_ref_name" ]]; then
    echo "Failed to find pr base"
    exit 1
fi
pr_base="$remote/$base_ref_name"
echo "PR base: $pr_base"

fetch_command=(git fetch "$remote" "$base_ref_name")
merge_command=(git merge "$pr_base")
if [[ "$dry_run" == true ]]; then
    if [[ "$fetch_first" == true ]]; then
        printf 'Dry run:'
        printf ' %q' "${fetch_command[@]}"
        printf '\n'
    fi
    printf 'Dry run:'
    printf ' %q' "${merge_command[@]}"
    printf '\n'
    exit 0
fi

if [[ "$fetch_first" == true ]]; then
    "${fetch_command[@]}"
fi

"${merge_command[@]}"
