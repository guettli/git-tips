#!/usr/bin/env bash
#
# Source: https://github.com/guettli/git-tips
#
# Bash Strict Mode: https://github.com/guettli/bash-strict-mode
trap 'echo -e "\n🤷 🚨 🔥 Warning: A command has failed. Exiting the script. Line was ($0:$LINENO): $(sed -n "${LINENO}p" "$0" 2>/dev/null || true) 🔥 🚨 🤷 "; exit 3' ERR
set -Eeuo pipefail

# List the ten branches which had recent activities. First run fetch.
# Highlight branches where the local branch is not equal to the branch of origin.

usage() {
    cat <<EOF
Usage: $0 [LIMIT] [--no-fetch]

List local and origin branches sorted by recent activity.
The script merges local branches with origin/<branch> branches into one view.

Options:
  LIMIT       Number of branches to show (default: 10)
  --no-fetch  Skip 'git fetch --prune origin'
  -h, --help  Show this help
EOF
}

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: This script must be run inside a git repository."
    exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    echo "Error: Git remote 'origin' is not configured."
    exit 1
fi

limit=10
fetch_origin=true

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    --no-fetch)
        fetch_origin=false
        shift
        ;;
    '' | *[!0-9]*)
        echo "Error: Unknown argument '$1'"
        usage
        exit 1
        ;;
    *)
        limit="$1"
        shift
        ;;
    esac
done

if [[ "$limit" -lt 1 ]]; then
    echo "Error: LIMIT must be greater than zero."
    exit 1
fi

if [[ "$fetch_origin" == true ]]; then
    fetch_output=""
    if ! fetch_output="$(git fetch --prune origin 2>&1)"; then
        printf '%s\n' "$fetch_output" >&2
        exit 1
    fi
fi

if [[ -t 1 ]]; then
    color_reset=$'\033[0m'
    color_red=$'\033[31m'
    color_yellow=$'\033[33m'
    color_green=$'\033[32m'
    color_dim=$'\033[2m'
else
    color_reset=""
    color_red=""
    color_yellow=""
    color_green=""
    color_dim=""
fi

status_and_color() {
    local branch="$1"
    local ahead behind

    if ! git show-ref --verify --quiet "refs/heads/$branch"; then
        printf 'remote only\t%s\n' "$color_yellow"
        return
    fi

    if ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        printf 'local only\t%s\n' "$color_yellow"
        return
    fi

    read -r ahead behind < <(git rev-list --left-right --count "${branch}...origin/${branch}")
    if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then
        printf 'synced\t%s\n' "$color_green"
        return
    fi

    if [[ "$ahead" -gt 0 && "$behind" -gt 0 ]]; then
        printf 'diverged (ahead %s, behind %s)\t%s\n' "$ahead" "$behind" "$color_red"
        return
    fi

    if [[ "$ahead" -gt 0 ]]; then
        printf 'ahead %s\t%s\n' "$ahead" "$color_yellow"
        return
    fi

    printf 'behind %s\t%s\n' "$behind" "$color_yellow"
}

declare -A branch_relative=()
declare -A branch_subject=()
declare -A branch_head=()
declare -a ordered_branches=()

while IFS=$'\t' read -r full_ref short_ref relative subject head_marker; do
    branch_name="$short_ref"

    case "$full_ref" in
    refs/heads/*) ;;
    refs/remotes/origin/HEAD)
        continue
        ;;
    refs/remotes/origin/*)
        branch_name="${short_ref#origin/}"
        ;;
    *)
        continue
        ;;
    esac

    if [[ -z "${branch_relative[$branch_name]+x}" ]]; then
        branch_relative["$branch_name"]="$relative"
        branch_subject["$branch_name"]="$subject"
        branch_head["$branch_name"]="$head_marker"
        ordered_branches+=("$branch_name")
    fi
done < <(
    git for-each-ref refs/heads refs/remotes/origin \
        --sort=-committerdate \
        --format=$'%(refname)\t%(refname:short)\t%(committerdate:relative)\t%(subject)\t%(HEAD)'
)

printf '%-2s %-45s %-18s %-34s %s\n' "" "branch" "last activity" "origin status" "subject"
printf '%-2s %-45s %-18s %-34s %s\n' "" "------" "-------------" "-------------" "-------"

count=0
for branch in "${ordered_branches[@]}"; do
    if [[ "$count" -ge "$limit" ]]; then
        break
    fi

    relative="${branch_relative[$branch]}"
    subject="${branch_subject[$branch]}"
    head_marker="${branch_head[$branch]}"
    IFS=$'\t' read -r status color < <(status_and_color "$branch")
    display_branch="$branch"
    if [[ -z "$head_marker" ]]; then
        head_marker=" "
    fi
    if [[ "$status" == "remote only" ]]; then
        display_branch="origin/$branch"
    fi

    printf '%s  %-45.45s %s%-18.18s%s %s%-34.34s%s %s%s%s\n' \
        "$head_marker" \
        "$display_branch" \
        "$color_dim" "$relative" "$color_reset" \
        "$color" "$status" "$color_reset" \
        "$color_dim" "$subject" "$color_reset"
    count=$((count + 1))
done
