#!/usr/bin/env bash
#
# Source: https://github.com/guettli/git-tips
#
# Bash Strict Mode: https://github.com/guettli/bash-strict-mode
trap 'echo -e "\n🤷 🚨 🔥 Warning: A command has failed. Exiting the script. Line was ($0:$LINENO): $(sed -n "${LINENO}p" "$0" 2>/dev/null || true) 🔥 🚨 🤷 "; exit 3' ERR
set -Eeuo pipefail

# git-sw: Interactive branch switcher using fzf
# Place this on your PATH and run: git sw

if ! command -v fzf &>/dev/null; then
    echo "Error: fzf is not installed. Install it from https://github.com/junegunn/fzf" >&2
    exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: This script must be run inside a git repository." >&2
    exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
    git fetch --prune origin >/dev/null 2>&1 || true
fi

declare -A local_ref=()
declare -A remote_ref=()
declare -A seen_branch=()
declare -a ordered_branches=()

while IFS=$'\t' read -r full_ref short_ref; do
    case "$full_ref" in
    refs/heads/*)
        branch_name="$short_ref"
        local_ref["$branch_name"]="$short_ref"
        ;;
    refs/remotes/origin/HEAD)
        continue
        ;;
    refs/remotes/origin/*)
        branch_name="${short_ref#origin/}"
        remote_ref["$branch_name"]="$short_ref"
        ;;
    *)
        continue
        ;;
    esac

    if [[ -z "${seen_branch[$branch_name]+x}" ]]; then
        seen_branch["$branch_name"]=1
        ordered_branches+=("$branch_name")
    fi
done < <(
    git for-each-ref refs/heads refs/remotes/origin \
        --sort=-committerdate \
        --format=$'%(refname)\t%(refname:short)'
)

selection=$(
    for branch in "${ordered_branches[@]}"; do
        if [[ -n "${local_ref[$branch]+x}" ]]; then
            printf '%s\tlocal\t%s\n' "$branch" "${local_ref[$branch]}"
        else
            printf 'origin/%s\tremote\t%s\n' "$branch" "${remote_ref[$branch]}"
        fi
    done |
        fzf \
            --height=40% \
            --reverse \
            --delimiter=$'\t' \
            --with-nth=1 \
            --preview 'git log --oneline -10 {3}'
) || exit 0

IFS=$'\t' read -r _ branch_kind branch_ref <<<"$selection"

if [[ "$branch_kind" == "remote" ]]; then
    git switch --track "$branch_ref"
    exit 0
fi

git switch "$branch_ref"
