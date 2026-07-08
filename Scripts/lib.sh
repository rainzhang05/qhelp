#!/bin/bash

clipai_state_dir() {
    local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    printf '%s\n' "$state_home/clipai"
}

clipai_installed_commit_file() {
    printf '%s\n' "$(clipai_state_dir)/installed-commit"
}

clipai_installed_path_file() {
    printf '%s\n' "$(clipai_state_dir)/installed-path"
}

clipai_current_commit() {
    git rev-parse HEAD 2>/dev/null || true
}

clipai_short_commit() {
    local commit="$1"
    if [ "${#commit}" -gt 12 ]; then
        printf '%s\n' "${commit:0:12}"
    else
        printf '%s\n' "$commit"
    fi
}

clipai_record_install_metadata() {
    local installed_path="$1"
    local commit
    commit="$(clipai_current_commit)"

    mkdir -p "$(clipai_state_dir)"
    printf '%s\n' "$installed_path" >"$(clipai_installed_path_file)"

    if [ -n "$commit" ]; then
        printf '%s\n' "$commit" >"$(clipai_installed_commit_file)"
    fi
}

clipai_installed_commit() {
    local commit_file
    commit_file="$(clipai_installed_commit_file)"

    if [ -f "$commit_file" ]; then
        sed -n '1p' "$commit_file"
    fi
}

clipai_installed_path() {
    local path_file
    path_file="$(clipai_installed_path_file)"

    if [ -f "$path_file" ]; then
        sed -n '1p' "$path_file"
    fi
}

clipai_clear_install_metadata() {
    rm -f "$(clipai_installed_commit_file)" "$(clipai_installed_path_file)"
}
