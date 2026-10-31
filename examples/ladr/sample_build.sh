#!/bin/sh
# Run Lean on one module of a built checkout N times, as Lake runs it, and count the failures.
# `lake env lean` alone would skip the lakefile's leanOptions, doc.verso among them; Lake's setup
# file carries them. The Section_9C rows of "Intermittent build failures" ran Lean this way.
#
# usage: sample_build.sh <checkout> <module's file, relative to it> <N> [lean options]
#   sample_build.sh . LinearAlgebraDoneRightLean/Section_9C.lean 100
#   sample_build.sh . LinearAlgebraDoneRightLean/Section_9C.lean 100 -DElab.async=false
# The setup file overrides the command line: an option the lakefile also sets keeps the lakefile's
# value, so -Ddoc.verso=false does nothing here.
# At most JOBS (default 3) at once: each imports Mathlib, at several GB.
set -u
checkout=$1; file=$2; n=$3; shift 3
cd "$checkout" || exit 2
setup=.lake/build/ir/${file%.lean}.setup.json
[ -f "$setup" ] || { echo "no $setup: run lake build first" >&2; exit 2; }
LEAN_PATH=$(lake env printenv LEAN_PATH) || exit 2
lean=$(lake env which lean) || exit 2
work=$(mktemp -d) || exit 2
trap 'rm -rf "$work"' EXIT
export LEAN_PATH lean file setup work
one='
  i=$1; shift
  if "$lean" "$file" -o "$work/$i.olean" -i "$work/$i.ilean" -c "$work/$i.c" --setup "$setup" --json "$@" \
      > "$work/$i.log" 2>&1
  then echo ok
  else printf "failed: %s\n" "$(grep -m1 -o "has not been implemented\|failed to synthesize[^\"]*" "$work/$i.log" | cut -c1-80)"
  fi
  rm -f "$work/$i".*
'
seq 1 "$n" | xargs -P "${JOBS:-3}" -I{} sh -c "$one" sh {} "$@" | sort | uniq -c
