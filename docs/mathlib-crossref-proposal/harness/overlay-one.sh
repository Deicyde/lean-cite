#!/bin/zsh
# One job of overlay.sh: compile the file $1. Reads LEAN, LP, O, M, MIN_FREE_PCT, STATUS.
f=$1; m=${f%.lean}
free_pct=$(memory_pressure | sed -n 's/.*free percentage: \([0-9]*\)%.*/\1/p')
if (( free_pct < MIN_FREE_PCT )); then
  print "SKIP $f (free memory $free_pct%)" >> $STATUS
  exit 0
fi
OPTS=(-Dpp.unicode.fun=true -DautoImplicit=false -DmaxSynthPendingDepth=3 -Dweak.linter.mathlibStandardSet=false)
mkdir -p $O/${m:h}
if LEAN_PATH=$LP ${0:A:h}/with-timeout.sh ${FILE_TIMEOUT:-1200} $LEAN -R $M $OPTS -o $O/$m.olean -i $O/$m.ilean $M/$f > $O/$m.log 2>&1; then
  print "ok $f" >> $STATUS
else
  print "FAIL $f" >> $STATUS
fi
