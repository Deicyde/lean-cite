#!/bin/zsh
# Usage: run-candidate.sh <label> <lean-branch> <mathlib-branch>
# Builds Lean with the candidate's source applied to the working tree (HEAD stays at the rc2 tag so
# the githash matches the cached Mathlib oleans), then tests it. Steps run strictly one after another.
set -u
L=$1; LB=$2; MB=$3
R=~/Desktop/LEAN/crossref-proposal; H=$R/harness; S1=$R/lean4/build/release/stage1/bin/lean
export PATH=$R/.tools/bin:$PATH
free() { memory_pressure | tail -1 }
TO=$H/with-timeout.sh
STEP=1200  # a hung step counts as a failure
cd $R/lean4
git checkout -- src
git diff crossref/base $LB -- src | git apply || exit 1
print "== build $(date +%T)"; free
make -C build/release -j4 stage1 > $R/.tools/lean-$L-build.log 2>&1 || { tail -30 $R/.tools/lean-$L-build.log | cut -c1-200; exit 1 }
print "githash $($S1 --githash)"
cd $R/mathlib-master
git checkout -q $MB || exit 1
LP=$(lake env printenv LEAN_PATH | sed 's|:[^:]*/.elan/toolchains/[^:]*||')
X=$H/overlays/$L-attr; rm -rf $X; mkdir -p $X
cp -cR .lake/build/lib/lean/ $X/
OPTS=(-Dpp.unicode.fun=true -DautoImplicit=false -DmaxSynthPendingDepth=3 -Dweak.linter.mathlibStandardSet=false)
print "== attribute file $(date +%T)"
LEAN_PATH=$X:$LP $TO $STEP $S1 -R . $OPTS -o $X/Mathlib/Tactic/CrossRefAttribute.olean -i $X/Mathlib/Tactic/CrossRefAttribute.ilean Mathlib/Tactic/CrossRefAttribute.lean > $H/out/$L-attr.log 2>&1 || { cut -c1-220 $H/out/$L-attr.log | head -20; print "attribute file failed; stopping"; git checkout -q crossref-proposal/pr44898-merged; exit 1 }
print "== upstream test file"
LEAN_PATH=$X:$LP $TO $STEP $S1 -R . -Dpp.mvars.anonymous=false MathlibTest/CrossRefAttribute.lean > $H/out/$L-upstream-test.log 2>&1; print "rc $?"
grep -c "error" $H/out/$L-upstream-test.log
print "== probe $(date +%T)"
LEAN_OVERRIDE=$S1 EXTRA_LP=$X $TO $STEP $H/run-probe.sh $R/mathlib-master $L | tail -3
print "== sweep $(date +%T)"; free
EXTRA_LP=$X $H/overlay.sh $R/mathlib-master $S1 $H/overlays/$L 3 | tail -1
print "== count $(date +%T)"; free
$TO $STEP $H/count-overlay.sh $R/mathlib-master $S1 $L 2>&1 | cut -c1-300
python3 -I $H/diff-docs.py $H/docs-master.tsv $H/docs-$L.tsv 2>&1 | cut -c1-300 | head -24
git checkout -q crossref-proposal/pr44898-merged
rm -rf $X
print "== Lean tests except Lake $(date +%T)"; free
if [[ -z ${SKIP_CTEST:-} ]]; then
  cd $R/lean4/build/release/stage1
  ctest -j4 --timeout 900 -E 'tests/lake' > $H/ctest-$L.log 2>&1
  tail -25 $H/ctest-$L.log | grep -E "tests passed|\(Failed\)|\(Timeout\)|\(Not Run\)" | cut -c1-120
fi
print "== done $(date +%T)"; free
