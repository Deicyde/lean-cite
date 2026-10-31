#!/bin/zsh
# Usage: [LEAN_OVERRIDE=path/to/lean] [EXTRA_LP=dir] run-probe.sh <mathlib-checkout> <label>
# Compiles ProbeDecls with Elab.async at its default for command-line builds, then the importer,
# and writes the classified matrix to harness/out/<label>.tsv.
set -u
H=${0:A:h}; M=$1; L=$2; O=$H/out/$L; mkdir -p $O
cd $M
LP=$(lake env printenv LEAN_PATH | sed 's|:[^:]*/.elan/toolchains/[^:]*||')
LP=${EXTRA_LP:+$EXTRA_LP:}$LP
LEAN=${LEAN_OVERRIDE:-$(lake env which lean)}
print "lean: $LEAN"; $LEAN --version
cd $H
# `lean` writes .olean, .olean.server, .olean.private for a module given -o
LEAN_PATH=$LP:$O $LEAN -R $H -o $O/ProbeDecls.olean -i $O/ProbeDecls.ilean $H/ProbeDecls.lean > $O/decls.log 2>&1; rc1=$?
LEAN_PATH=$LP:$O $LEAN -R $H $H/ProbeImport.lean > $O/import.log 2>&1; rc2=$?
print "rc decls=$rc1 import=$rc2"
grep -v "PROBE" $O/decls.log | grep -E "error|PANIC" | head -20
grep -v "PROBE" $O/import.log | grep -E "error|PANIC" | head
python3 -I $H/classify.py $O/decls.log $O/import.log > $H/out/$L.tsv
