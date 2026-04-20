#!/usr/bin/env bash
# Bash Strict Mode: https://github.com/guettli/bash-strict-mode
trap 'echo -e "\n🤷 🚨 🔥 Warning: A command has failed. Exiting the script. Line was ($0:$LINENO): $(sed -n "${LINENO}p" "$0" 2>/dev/null || true) 🔥 🚨 🤷 "; exit 3' ERR
set -Eeuo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [--no-fetch] [--dry-run]

Merge the current PR/MR base branch into the current branch.

The hosting provider is autodetected from the URL of the current branch remote.

Options:
  --no-fetch Skip fetching the PR base branch before merging
  --dry-run  Print the commands without executing them
  -h, --help Show this help

Requires:
  - GitHub: gh
  - GitLab: glab, jq
  - Codeberg: berg, jq

Reason: Git has no concept of pull requests/merge requests or a PR base branch,
so this script uses the hosting provider CLI to resolve the base branch first.
EOF
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Error: Required command '$command_name' is not available."
        exit 1
    fi
}

get_remote_host() {
    local remote_url="$1"

    if [[ "$remote_url" =~ ^https?://([^/@]+@)?([^/:]+)(:[0-9]+)?/ ]]; then
        printf '%s\n' "${BASH_REMATCH[2],,}"
        return 0
    fi

    if [[ "$remote_url" =~ ^ssh://([^/@]+@)?([^/:]+)(:[0-9]+)?/ ]]; then
        printf '%s\n' "${BASH_REMATCH[2],,}"
        return 0
    fi

    if [[ "$remote_url" =~ ^[^@]+@([^:]+): ]]; then
        printf '%s\n' "${BASH_REMATCH[1],,}"
        return 0
    fi

    return 1
}

detect_provider() {
    local remote_host="$1"

    case "$remote_host" in
    github.com)
        printf 'github\n'
        ;;
    gitlab.com | *gitlab*)
        printf 'gitlab\n'
        ;;
    codeberg.org)
        printf 'codeberg\n'
        ;;
    *)
        return 1
        ;;
    esac
}

resolve_base_ref_name() {
    local provider="$1"
    local current_branch="$2"

    case "$provider" in
    github)
        require_command gh
        gh pr view --json baseRefName --jq '.baseRefName'
        ;;
    gitlab)
        require_command glab
        require_command jq
        glab mr view --output json | jq -r '.target_branch // empty'
        ;;
    codeberg)
        require_command berg
        require_command jq
        berg --output json --non-interactive pull list --state open | jq -r --arg branch "$current_branch" '
            [ .[]
              | select(
                  .head.ref == $branch
                  or .head.label == $branch
                  or (.head.label != null and (.head.label | endswith(":" + $branch)))
                )
            ] as $prs
            | if ($prs | length) == 1 then
                  $prs[0].base.ref // empty
              elif ($prs | length) == 0 then
                  empty
              else
                  error("multiple open pull requests found for branch " + $branch)
              end
        '
        ;;
    *)
        echo "Error: Unsupported provider '$provider'."
        exit 1
        ;;
    esac
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

require_command git

current_branch=$(git branch --show-current)
if [[ -z "$current_branch" ]]; then
    echo "Error: Could not determine the current branch."
    echo "A detached HEAD is not supported."
    exit 1
fi

remote=$(git config branch."$current_branch".remote)
if [[ -z "$remote" ]]; then
    echo "Failed to find remote. (often it is 'origin')"
    exit 1
fi

remote_url=$(git remote get-url "$remote")
if [[ -z "$remote_url" ]]; then
    echo "Error: Failed to find the URL for remote '$remote'."
    exit 1
fi

remote_host=$(get_remote_host "$remote_url") || {
    echo "Error: Failed to parse host from remote URL '$remote_url'."
    exit 1
}

provider=$(detect_provider "$remote_host") || {
    echo "Error: Unsupported Git hosting provider for remote URL '$remote_url'."
    exit 1
}

base_ref_name=$(resolve_base_ref_name "$provider" "$current_branch")
if [[ -z "$base_ref_name" ]]; then
    echo "Failed to find PR/MR base for provider '$provider' and branch '$current_branch'."
    exit 1
fi
pr_base="$remote/$base_ref_name"
echo "PR base: $pr_base ($provider)"

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
