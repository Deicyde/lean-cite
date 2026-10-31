#!/bin/zsh
# verify-branch.sh <lean-branch> <mathlib-branch>: build Lean from the branch's source, run the
# Mathlib branch's attribute file and upstream test file against it. Expect silence from the test.
set -u
R=~/Desktop/LEAN/crossref-proposal; S1=$R/lean4/build/release/stage1/bin/lean; export PATH=$R/.tools/bin:$PATH
cd $R/lean4; git checkout -- src; git diff crossref/base $1 -- src | git apply || exit 1
$R/harness/with-timeout.sh 1200 make -C build/release -j4 stage1 > $R/.tools/verify.log 2>&1 || { tail -5 $R/.tools/verify.log; exit 1 }
cd $R/mathlib-master; git checkout -q $2
LP=$(lake env printenv LEAN_PATH | sed 's|:[^:]*/.elan/toolchains/[^:]*||')
X=$R/harness/overlays/verify; rm -rf $X; mkdir -p $X; cp -cR .lake/build/lib/lean/ $X/
OPTS=(-Dpp.unicode.fun=true -DautoImplicit=false -DmaxSynthPendingDepth=3 -Dweak.linter.mathlibStandardSet=false)
LEAN_PATH=$X:$LP $S1 -R . $OPTS -o $X/Mathlib/Tactic/CrossRefAttribute.olean -i $X/Mathlib/Tactic/CrossRefAttribute.ilean Mathlib/Tactic/CrossRefAttribute.lean 2>&1 | head -5 | cut -c1-200
LEAN_PATH=$X:$LP $R/harness/with-timeout.sh 600 $S1 -R . -Dpp.mvars.anonymous=false MathlibTest/CrossRefAttribute.lean > $X.log 2>&1; print "$1 + $2: upstream test rc=$?, $(grep -c error $X.log) errors"
grep -E "error" $X.log | cut -c1-140 | head -5
rm -rf $X; git checkout -q crossref-proposal/pr44898-merged
