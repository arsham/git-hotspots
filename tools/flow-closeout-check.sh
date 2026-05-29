#!/bin/sh
set -eu

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT" || exit 1

printf '%s\n' 'flow-closeout-check: RUN full close-out validation and proof aggregate'
zig build validate-all -Dcloseout=true "$@"
