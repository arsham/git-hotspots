#!/bin/sh
set -eu

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT" || exit 1

args_file=$(mktemp)
trap 'rm -f "$args_file"' EXIT HUP INT TERM

append_arg() {
    printf '%s\0' "$1" >> "$args_file"
}

append_arg build
append_arg validate-all
append_arg -Dcloseout=true

while [ "$#" -gt 0 ]; do
    case "$1" in
        --smoke-repo|--smoke-label|--smoke-skip-reason)
            [ "$#" -ge 2 ] || { echo "flow-closeout-check: $1 requires a value" >&2; exit 2; }
            option=${1#--}
            append_arg "-D$option=$2"
            shift 2
            ;;
        --smoke-repo=*|--smoke-label=*|--smoke-skip-reason=*)
            option=${1%%=*}
            value=${1#*=}
            option=${option#--}
            append_arg "-D$option=$value"
            shift
            ;;
        *)
            append_arg "$1"
            shift
            ;;
    esac
done

printf '%s\n' 'flow-closeout-check: RUN full close-out validation and proof aggregate'
xargs -0 zig < "$args_file"
