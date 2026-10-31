#!/bin/zsh
# Usage: count-overlay.sh <mathlib-checkout> <lean-binary> <label>
# Clones the checkout's oleans (APFS clone, no extra disk), lays overlays/<label> over them, then
# reports the link count and dumps every docstring. One Mathlib-importing process at a time.
set -eu
H=${0:A:h}; M=${1:A}; LEAN=${2:A}; L=$3; O=$H/overlays/$L; X=$H/overlays/$L-merged
rm -rf $X; mkdir -p $X
cp -cR $M/.lake/build/lib/lean/ $X/
cd $O; find . -type f ! -name '*.log' | while read f; do mkdir -p $X/${f:h}; rm -f $X/$f; cp -c $f $X/$f; done
cd $M
LP=$X:$(lake env printenv LEAN_PATH | sed 's|:[^:]*/.elan/toolchains/[^:]*||')
cd $H/overlays
LEAN_PATH=$LP $LEAN $H/CountLinks.lean 2>&1 | tail -4
mv crossref-links.tsv $H/crossref-links-$L.tsv
DOCS_OUT=$H/docs-$L.tsv LEAN_PATH=$LP $LEAN $H/DumpDocs.lean 2>&1 | tail -3
LC_ALL=C sort -o $H/docs-$L.tsv $H/docs-$L.tsv
rm -rf $X
wc -l $H/docs-$L.tsv
