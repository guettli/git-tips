#!/usr/bin/env bash
#
# Source: https://github.com/guettli/git-tips
#
# Bash Strict Mode: https://github.com/guettli/bash-strict-mode
trap 'echo -e "\n🤷 🚨 🔥 Warning: A command has failed. Exiting the script. Line was ($0:$LINENO): $(sed -n "${LINENO}p" "$0" 2>/dev/null || true) 🔥 🚨 🤷 "; exit 3' ERR
set -Eeuo pipefail

POSITIONER_PIDS=()
LAST_BG_PID=""

function usage() {
    echo "Usage:"
    echo "  $0 <file>"
    echo "  $0 <BASE> <LOCAL> <REMOTE> <MERGED>"
    echo ""
    echo "This script helps to resolve Git merge conflicts with an overview first."
    echo ""
    echo "Standalone mode (<file>):"
    echo "  Creates <file>.BASE, <file>.LOCAL, and <file>.REMOTE"
    echo "  Opens DIFFTOOL twice:"
    echo "    BASE vs REMOTE"
    echo "    BASE vs LOCAL"
    echo "  Then launches meld for the three-way merge and stages <file> if resolved."
    echo ""
    echo "Mergetool mode (<BASE> <LOCAL> <REMOTE> <MERGED>):"
    echo "  Intended for git mergetool custom commands."
    echo "  Opens the same two overview diffs, then launches meld for the merge."
    echo ""
    echo "If env var DIFFTOOL is not set, it defaults to your git 'diff.tool' setting."
    echo "If no git 'diff.tool' is configured, it defaults to 'meld' when available, otherwise 'code -d'."
    echo "Set MELD_BIN if meld is not available as 'meld' in PATH."
    echo ""
    echo "The two file comparisons opened by the script can help you to see the changes."
    echo "  BASE vs LOCAL: These are the changes of your local branch. It is likely that you are more familiar with these changes."
    echo "  BASE vs REMOTE: The upstream branch (often 'main') changed. These changes are why the merge has conflicts."
    echo ""
    echo "With meld plus wmctrl/xdotool, the overview windows are tiled side by side:"
    echo "  BASE vs REMOTE on the left half of the screen"
    echo "  BASE vs LOCAL on the right half of the screen"
    echo ""
    echo "Related: https://github.com/guettli/git-tips/"
    exit 1
}

function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

function resolve_difftool_cmd() {
    local configured_tool configured_cmd meld_bin placeholder_local placeholder_remote

    placeholder_local="\$LOCAL"
    placeholder_remote="\$REMOTE"

    if [[ -n "${DIFFTOOL:-}" ]]; then
        echo "$DIFFTOOL"
        return
    fi

    configured_tool="$(git config --get diff.tool 2>/dev/null || true)"
    if [[ -n "$configured_tool" ]]; then
        configured_cmd="$(git config --get "difftool.${configured_tool}.cmd" 2>/dev/null || true)"
        if [[ -n "$configured_cmd" ]]; then
            echo "$configured_cmd"
        else
            printf '%q "%s" "%s"\n' "$configured_tool" "$placeholder_local" "$placeholder_remote"
        fi
        return
    fi

    meld_bin="${MELD_BIN:-meld}"
    if command_exists "$meld_bin"; then
        printf '%q "%s" "%s"\n' "$meld_bin" "$placeholder_local" "$placeholder_remote"
        return
    fi

    echo "code -d \"\$LOCAL\" \"\$REMOTE\""
}

function is_meld_difftool() {
    local diff_cmd="$1"
    [[ "$diff_cmd" == *meld* ]]
}

function run_shell_difftool_in_background() {
    local diff_cmd="$1"
    local left_file="$2"
    local right_file="$3"

    LOCAL="$left_file" REMOTE="$right_file" bash -lc "$diff_cmd" &
    LAST_BG_PID="$!"
}

function launch_meld_diff_in_background() {
    local meld_bin="$1"
    local left_label="$2"
    local right_label="$3"
    local left_file="$4"
    local right_file="$5"

    "$meld_bin" --label "$left_label" --label "$right_label" "$left_file" "$right_file" &
    LAST_BG_PID="$!"
}

function get_screen_geometry() {
    local geometry

    [[ -n "${DISPLAY:-}" ]] || return 1

    geometry="$(
        xrandr --query 2>/dev/null | awk '
            / connected primary / {print $4; exit}
            / connected / && first == "" {first = $3}
            END {if (first != "") print first}
        '
    )"

    [[ -n "$geometry" ]] || return 1
    echo "$geometry"
}

function wait_for_window_id() {
    local pid="$1"
    local attempt window_id

    for ((attempt = 1; attempt <= 15; attempt++)); do
        window_id="$(xdotool search --onlyvisible --pid "$pid" 2>/dev/null | head -n 1 || true)"
        if [[ -n "$window_id" ]]; then
            echo "$window_id"
            return 0
        fi
        sleep 0.2
    done

    return 1
}

function capture_window_ids_by_pattern() {
    local pattern="$1"

    xdotool search --onlyvisible --name "$pattern" 2>/dev/null || true
}

function wait_for_new_window_id_by_pattern() {
    local pattern="$1"
    local known_ids="$2"
    local attempt window_id

    for ((attempt = 1; attempt <= 15; attempt++)); do
        while IFS= read -r window_id; do
            [[ -n "$window_id" ]] || continue
            if ! grep -qxF "$window_id" <<<"$known_ids"; then
                echo "$window_id"
                return 0
            fi
        done < <(capture_window_ids_by_pattern "$pattern")
        sleep 0.2
    done

    return 1
}

function position_window_for_pid() {
    local pid="$1"
    local side="$2"
    local window_id

    command_exists xdotool || return 0

    window_id="$(wait_for_window_id "$pid")" || return 0
    position_window_id "$window_id" "$side"
}

function position_window_for_pattern() {
    local pattern="$1"
    local known_ids="$2"
    local side="$3"
    local window_id

    command_exists wmctrl || return 0
    command_exists xdotool || return 0

    window_id="$(wait_for_new_window_id_by_pattern "$pattern" "$known_ids")" || return 0
    position_window_id "$window_id" "$side"
}

function position_window_id() {
    local window_id="$1"
    local side="$2"
    local geometry screen_width screen_height screen_x screen_y
    local target_x target_width

    command_exists wmctrl || return 0
    command_exists xrandr || return 0

    geometry="$(get_screen_geometry)" || return 0
    IFS='x+' read -r screen_width screen_height screen_x screen_y <<<"$geometry"

    if [[ "$side" == "left" ]]; then
        target_x="$screen_x"
        target_width=$((screen_width / 2))
    else
        target_width=$((screen_width - screen_width / 2))
        target_x=$((screen_x + screen_width / 2))
    fi

    wmctrl -i -r "$window_id" -b remove,maximized_vert,maximized_horz >/dev/null 2>&1 || true
    sleep 0.1
    wmctrl -i -r "$window_id" -e "0,$target_x,$screen_y,$target_width,$screen_height" >/dev/null 2>&1 || true
}

function has_conflict_markers() {
    local file="$1"
    grep -qE '^(<<<<<<< |=======|>>>>>>> )' "$file"
}

function run_overview_diffs() {
    local diff_cmd="$1"
    local base_file="$2"
    local local_file="$3"
    local remote_file="$4"
    local meld_bin="${MELD_BIN:-meld}"
    local remote_pid local_pid
    local remote_known_ids local_known_ids

    if is_meld_difftool "$diff_cmd" && command_exists "$meld_bin"; then
        remote_known_ids="$(capture_window_ids_by_pattern 'BASE.*REMOTE')"
        local_known_ids="$(capture_window_ids_by_pattern 'BASE.*LOCAL')"

        launch_meld_diff_in_background "$meld_bin" "BASE" "REMOTE" "$base_file" "$remote_file"
        launch_meld_diff_in_background "$meld_bin" "BASE" "LOCAL" "$base_file" "$local_file"
    else
        run_shell_difftool_in_background "$diff_cmd" "$base_file" "$remote_file"
        remote_pid="$LAST_BG_PID"
        run_shell_difftool_in_background "$diff_cmd" "$base_file" "$local_file"
        local_pid="$LAST_BG_PID"
    fi

    POSITIONER_PIDS=()
    if is_meld_difftool "$diff_cmd" && command_exists "$meld_bin"; then
        position_window_for_pattern 'BASE.*REMOTE' "$remote_known_ids" left &
        POSITIONER_PIDS+=("$!")
        position_window_for_pattern 'BASE.*LOCAL' "$local_known_ids" right &
        POSITIONER_PIDS+=("$!")
    else
        position_window_for_pid "$remote_pid" left &
        POSITIONER_PIDS+=("$!")
        position_window_for_pid "$local_pid" right &
        POSITIONER_PIDS+=("$!")
    fi
}

function wait_for_positioners() {
    local pid

    for pid in "${POSITIONER_PIDS[@]}"; do
        wait "$pid" || true
    done
}

function run_meld_merge() {
    local base_file="$1"
    local local_file="$2"
    local remote_file="$3"
    local merged_file="$4"
    local meld_bin="${MELD_BIN:-meld}"
    local meld_base_file

    command_exists "$meld_bin" || {
        echo "Could not find meld. Set MELD_BIN to the meld executable." >&2
        return 1
    }

    meld_base_file="$base_file"
    if [[ ! -e "$meld_base_file" ]]; then
        meld_base_file="@blank"
    fi

    if ! "$meld_bin" --auto-merge -o "$merged_file" "$local_file" "$meld_base_file" "$remote_file"; then
        echo "meld exited without a successful merge for '$merged_file'." >&2
        return 1
    fi

    if [[ ! -f "$merged_file" ]]; then
        echo "Merge tool did not write '$merged_file'." >&2
        return 1
    fi

    if has_conflict_markers "$merged_file"; then
        echo "Conflict markers are still present in '$merged_file'." >&2
        return 1
    fi
}

function prepare_standalone_inputs() {
    local file="$1"
    local merge_head_path merge_head base_commit

    [[ -f "$file" ]] || {
        echo "Error: File '$file' does not exist."
        usage
    }

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

    # Stage :1 can be a synthetic merge base and may itself contain conflict markers.
    # Prefer the real common ancestor commit of HEAD and MERGE_HEAD for BASE.
    base_commit="$(git merge-base HEAD "$merge_head")"
    if ! git show "${base_commit}:$file" >"$file".BASE 2>/dev/null; then
        echo "Could not read '$file' from merge-base commit $base_commit." >&2
        echo "Refusing to fall back to index stage :1 because it may contain conflict markers." >&2
        exit 1
    fi

    git show :2:"$file" >"$file".LOCAL
    git show :3:"$file" >"$file".REMOTE

    printf '%s\n%s\n%s\n%s\n' "$file".BASE "$file".LOCAL "$file".REMOTE "$file"
}

function main() {
    local diff_cmd base_file local_file remote_file merged_file overview_base_file
    local -a inputs

    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        usage
    fi

    case $# in
    1)
        mapfile -t inputs < <(prepare_standalone_inputs "$1")
        base_file="${inputs[0]}"
        local_file="${inputs[1]}"
        remote_file="${inputs[2]}"
        merged_file="${inputs[3]}"
        ;;
    4)
        base_file="${1:-/dev/null}"
        local_file="$2"
        remote_file="$3"
        merged_file="$4"
        ;;
    *)
        usage
        ;;
    esac

    diff_cmd="$(resolve_difftool_cmd)"
    overview_base_file="$base_file"
    if [[ ! -e "$overview_base_file" ]]; then
        overview_base_file="/dev/null"
    fi

    run_overview_diffs "$diff_cmd" "$overview_base_file" "$local_file" "$remote_file"
    run_meld_merge "$base_file" "$local_file" "$remote_file" "$merged_file"
    wait_for_positioners

    if [[ $# -eq 1 ]] && git ls-files -u -- "$merged_file" | grep -q .; then
        git add -- "$merged_file"
    fi
}

main "$@"
