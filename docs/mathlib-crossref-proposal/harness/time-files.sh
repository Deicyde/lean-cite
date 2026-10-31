#!/bin/zsh
# Usage: time-files.sh <lean> <label> <list>; wall-clock seconds per file, one process at a time.
zmodload zsh/datetime
L=${1:A}; N=$2; H=${0:A:h}
M=$H/../mathlib-master; cd $M
LP=$(lake env printenv LEAN_PATH | sed 's|:[^:]*/.elan/toolchains/[^:]*||')
OPTS=(-Dpp.unicode.fun=true -DautoImplicit=false -DmaxSynthPendingDepth=3 -Dweak.linter.mathlibStandardSet=false)
for f in $(cat $3); do
  s=$EPOCHREALTIME
  LEAN_PATH=$LP $H/with-timeout.sh 900 $L -R . $OPTS $f > /dev/null 2>&1; rc=$?
  e=$EPOCHREALTIME
  printf '%s\t%s\t%.1f\trc=%d\n' $N $f $((e-s)) $rc
done
