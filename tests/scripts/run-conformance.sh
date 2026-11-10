#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=${TMPDIR:-/tmp}/forge-conformance-$$
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

command -v racket >/dev/null 2>&1 || { echo "missing racket" >&2; exit 2; }
command -v cmp >/dev/null 2>&1 || exit 2
command -v nasm >/dev/null 2>&1 || { echo "missing nasm" >&2; exit 2; }
command -v cc >/dev/null 2>&1 || { echo "missing C linker" >&2; exit 2; }
: "${FORGE_OBERON_COMPILE:?set FORGE_OBERON_COMPILE to an Oberon runner command that invokes Driver.Compile(input, output)}"
: "${FORGE_FACTOR_RUN:?set FORGE_FACTOR_RUN to a Factor runtime command that loads and runs the IR fixture}"

racket "$ROOT/compiler/expand.rkt" \
  "$ROOT/tests/fixtures/multiply.forge" "$TMP/multiply.fir"
cmp "$TMP/multiply.fir" "$ROOT/tests/fixtures/multiply.fir"

# The Oberon driver parses canonical IR and emits NASM source.
sh -c "$FORGE_OBERON_COMPILE '$TMP/multiply.fir' '$TMP/multiply.asm'"
nasm -f elf64 "$TMP/multiply.asm" -o "$TMP/multiply.o"
cc -no-pie "$TMP/multiply.o" -o "$TMP/multiply-native"
set +e
"$TMP/multiply-native"
NATIVE_STATUS=$?
set -e
[ "$NATIVE_STATUS" -eq 96 ] || { echo "native result mismatch: $NATIVE_STATUS" >&2; exit 1; }

# Factor runner must execute the same generated .fir file and print one integer.
sh -c "$FORGE_FACTOR_RUN '$TMP/multiply.fir'" > "$TMP/factor.out"
FACTOR_RESULT=$(cat "$TMP/factor.out")
[ "$FACTOR_RESULT" = "96" ] || { echo "Factor result mismatch: $FACTOR_RESULT" >&2; exit 1; }

echo "FORGE IR v1 Racket/Oberon/Factor conformance passed"
