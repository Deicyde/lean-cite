#!/bin/zsh
# Usage: overlay.sh <mathlib-checkout> <lean-binary> <overlay-dir> [jobs] [file-list]
# Re-elaborates every Mathlib file containing a cross-reference tag with `lean-binary`, against the
# existing oleans of its imports, writing .olean files to overlay-dir. Nothing else is rebuilt.
#
# `xargs -P` enforces the job limit; an earlier version counted `jobs -r` inside a command
# substitution, which sees an empty job table, started every file at once and crashed the machine.
# At most 3 jobs on this Mac. Stops launching when free memory falls under MIN_FREE_PCT.
set -u
M=${1:A}; LEAN=${2:A}; O=${3:A}; J=${4:-3}; LIST=${5:+${5:A}}
H=${0:A:h}
if (( J > 3 )); then print "refusing more than 3 jobs on this machine"; exit 2; fi
mkdir -p $O
cd $M
if [[ -n $LIST ]]; then [[ $LIST -ef $O.list ]] || cp $LIST $O.list; else python3 -I $H/tagged_files.py > $O.list; fi
: > $O.status
export LP=${EXTRA_LP:+$EXTRA_LP:}$(lake env printenv LEAN_PATH | sed 's|:[^:]*/.elan/toolchains/[^:]*||') LEAN O M
export MIN_FREE_PCT=${MIN_FREE_PCT:-15} STATUS=$O.status
xargs -n 1 -P $J $H/overlay-one.sh < $O.list
print "done: $(grep -c '^ok' $O.status) ok, $(grep -c '^FAIL' $O.status) failed, $(grep -c '^SKIP' $O.status) skipped"
