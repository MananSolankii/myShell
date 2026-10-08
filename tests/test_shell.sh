#!/usr/bin/env bash
# Basic tests for the starter shell. Run from Bash, not inside myshell.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if (( $# > 1 )); then
    printf 'Usage: bash tests/test_shell.sh [source-file.c]\n' >&2
    exit 2
fi

if (( $# == 1 )); then
    source_file="$1"
elif [[ -f "$project_dir/myshell.c" ]]; then
    source_file="$project_dir/myshell.c"
elif [[ -f "$project_dir/myShell.c" ]]; then
    source_file="$project_dir/myShell.c"
else
    printf 'Cannot find myshell.c or myShell.c. Pass the source path as an argument.\n' >&2
    exit 2
fi

if [[ ! -f "$source_file" ]]; then
    printf 'Source file not found: %s\n' "$source_file" >&2
    exit 2
fi

for tool in gcc timeout; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Missing %s. On Ubuntu, install build-essential and coreutils.\n' "$tool" >&2
        exit 2
    fi
done

test_dir="$(mktemp -d)"
cleanup() {
    rm -f -- "$test_dir/myshell" "$test_dir/input" "$test_dir/stdout" "$test_dir/stderr"
    rmdir -- "$test_dir"
}
trap cleanup EXIT

printf 'Compiling %s\n' "$source_file"
gcc -Wall -Wextra -g "$source_file" -o "$test_dir/myshell"

passed=0
failed=0

run_case() {
    local name="$1" input="$2" expected="$3" error_expected="$4"
    local status=0 actual

    printf '%s' "$input" > "$test_dir/input"
    timeout 5s "$test_dir/myshell" < "$test_dir/input" \
        > "$test_dir/stdout" 2> "$test_dir/stderr" || status=$?

    # The starter prints a prompt even for redirected input. Strip that exact
    # prompt before comparing command output. None of the cases print it.
    actual="$(< "$test_dir/stdout")"
    actual="${actual//myshell> /}"
    while [[ "$actual" == *$'\n' ]]; do
        actual="${actual%$'\n'}"
    done

    if (( status != 0 )); then
        printf 'FAIL: %s (exit status %s; 124 means timeout)\n' "$name" "$status"
    elif [[ "$actual" != "$expected" ]]; then
        printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$name" "$expected" "$actual"
    elif [[ "$error_expected" == yes && ! -s "$test_dir/stderr" ]]; then
        printf 'FAIL: %s (expected an error message on stderr)\n' "$name"
    elif [[ "$error_expected" == no && -s "$test_dir/stderr" ]]; then
        printf 'FAIL: %s (unexpected stderr)\n' "$name"
        cat -- "$test_dir/stderr"
    else
        printf 'PASS: %s\n' "$name"
        passed=$((passed + 1))
        return
    fi
    failed=$((failed + 1))
}

run_case 'External command and PATH lookup' $'echo hello\nexit\n' 'hello' no
run_case 'Multiple arguments' $'echo one two three\nexit\n' 'one two three' no
run_case 'Repeated spaces and tabs' $'  echo\t hello   world  \nexit\n' 'hello world' no
run_case 'Blank input is skipped' $'\n   \n\t\necho ready\nexit\n' 'ready' no
run_case 'Absolute executable path' $'/bin/echo absolute\nexit\n' 'absolute' no
run_case 'Multiple commands' $'echo first\necho second\nexit\n' $'first\nsecond' no
run_case 'Missing command reports an error and shell continues' \
    $'/__myshell_test_missing_directory__/missing_command\necho recovered\nexit\n' 'recovered' yes
run_case 'exit prevents later commands from running' $'exit\necho should-not-run\n' '' no
run_case 'EOF after a command without a newline' 'echo eof' 'eof' no
run_case 'Empty input stream exits' '' '' no

printf '\n%s passed; %s failed.\n' "$passed" "$failed"
if (( failed > 0 )); then
    exit 1
fi
