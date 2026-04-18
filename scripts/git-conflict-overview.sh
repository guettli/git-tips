#!/usr/bin/env bash
#
# Source: https://github.com/guettli/git-tips
#
# Bash Strict Mode: https://github.com/guettli/bash-strict-mode
trap 'echo -e "\n🤷 🚨 🔥 Warning: A command has failed. Exiting the script. Line was ($0:$LINENO): $(sed -n "${LINENO}p" "$0" 2>/dev/null || true) 🔥 🚨 🤷 "; exit 3' ERR
set -Eeuo pipefail

function usage() {
    echo "Usage: $0 <file>"
    echo "This script opens DIFFTOOL twice:"
    echo "  DIFFTOOL <file>.BASE <file>.REMOTE"
    echo "  DIFFTOOL <file>.BASE <file>.LOCAL"
    echo "Then it opens git mergetool for <file>."
    echo "This helps to resolve git merge conflicts."
    echo "If env var DIFFTOOL is not set, it defaults to your git 'diff.tool' setting (or 'code -d')."
    echo ""
    echo "The two file comparisons opened by the script can help you to see the changes."
    echo "  BASE vs LOCAL: These are the changes of your local branch. It is likely that you are more familiar with these changes."
    echo "  BASE vs REMOTE: The upstream branch (often 'main') changed. These changes are why the merge has conflicts."
    echo ""
    echo "For resolving the conflict, I recommend to configure 'meld' as mergetool."
    echo "This script opens the two overview diffs first and then launches git mergetool."
    echo ""
    echo "Related: https://github.com/guettli/git-tips/"
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

if [[ ! -f "$1" ]]; then
    echo "Error: File '$1' does not exist."
    usage
fi

merge_head_path="$(git rev-parse --git-path MERGE_HEAD)"

if [[ ! -e "$merge_head_path" ]]; then
    echo "MERGE_HEAD does not exist. No merge seems to be active at the moment."
    usage
fi

mapfile -t merge_heads <"$merge_head_path"
if [[ ${#merge_heads[@]} -ne 1 ]]; then
    echo "Expected exactly one MERGE_HEAD entry, got ${#merge_heads[@]}."
    echo "This script currently supports only non-octopus merges."
    exit 1
fi

merge_head="${merge_heads[0]}"

FILE="$1"
default_difftool="$(git config --get diff.tool 2>/dev/null || true)"
if [[ -n "$default_difftool" ]]; then
    git_difftool_cmd="$(git config --get "difftool.${default_difftool}.cmd" 2>/dev/null || true)"
    if [[ -n "$git_difftool_cmd" ]]; then
        default_difftool="$git_difftool_cmd"
    fi
else
    default_difftool="code -d"
fi
difftool="${DIFFTOOL:-$default_difftool}"

# Stage :1 can be a synthetic merge base and may itself contain conflict markers.
# Prefer the real common ancestor commit of HEAD and MERGE_HEAD for BASE.
base_commit="$(git merge-base HEAD "$merge_head")"
if ! git show "${base_commit}:$FILE" >"$FILE".BASE 2>/dev/null; then
    echo "Could not read '$FILE' from merge-base commit $base_commit." >&2
    echo "Refusing to fall back to index stage :1 because it may contain conflict markers." >&2
    exit 1
fi

git show :2:"$FILE" >"$FILE".LOCAL
git show :3:"$FILE" >"$FILE".REMOTE
$difftool "$FILE".BASE "$FILE".REMOTE &
$difftool "$FILE".BASE "$FILE".LOCAL &
git mergetool --no-prompt -- "$FILE"
