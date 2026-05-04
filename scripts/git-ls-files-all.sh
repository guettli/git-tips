#!/usr/bin/env bash
#
# Source: https://github.com/guettli/git-tips
#
# Bash Strict Mode: https://github.com/guettli/bash-strict-mode
trap 'echo -e "\n🤷 🚨 🔥 Warning: A command has failed. Exiting the script. Line was ($0:$LINENO): $(sed -n "${LINENO}p" "$0" 2>/dev/null || true) 🔥 🚨 🤷 "; exit 3' ERR
set -Eeuo pipefail

usage() {
    cat <<EOF
Usage: $0 [git-ls-files-pathspec...]

Run 'git ls-files' for every git repository in the parent directory of the current directory.
Print matches as paths like '../some-repo/path/to/file'.

Examples:
  $0
  $0 '*.md'
  $0 'scripts/*.sh'

  # Search for a string in all sibling git repos.
  # If you are in ~/my-repos/foo, this searches repos in ~/my-repos.
  $0 '*.py' | xargs -d '\n' grep bar
EOF
}

case "${1:-}" in
--help | -h)
    usage
    exit 0
    ;;
esac

current_dir="$(pwd -P)"
search_root="$(cd "$current_dir/.." && pwd -P)"

found_repo=false

while IFS= read -r git_dir; do
    repo_dir="$(dirname "$git_dir")"
    repo_name="$(basename "$repo_dir")"
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        found_repo=true
        printf '../%s/%s\n' "$repo_name" "$file"
    done < <(git -C "$repo_dir" ls-files -- "$@" || true)
done < <(find "$search_root" -mindepth 2 -maxdepth 2 -type d -name .git | sort)

if [[ "$found_repo" == false ]]; then
    echo "No matching tracked files found in git repositories below: $search_root" >&2
    exit 1
fi
