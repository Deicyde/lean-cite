#!/bin/zsh
# Alternate full site builds of two built clones of the demo, as a Pages deploy runs them, and record
# how each went. A build after a success clears the library's build products first. A build after a
# failure clears nothing, so it retries what had not finished, as a person would. At Lake's default
# concurrency, so run nothing else heavy beside it.
#
# usage: site_builds.sh <rounds> <clone> <clone>
# Appends to site-builds.tsv and writes site-builds/<clone's name>-<round>.log in the current directory.
setopt null_glob
here=$PWD; rounds=$1; shift; mkdir -p site-builds
typeset -A failed
for i in {1..$rounds}; do
  for clone in $@; do
    cd $clone; name=${clone:t}; log=$here/site-builds/$name-$i.log
    if [[ -z ${failed[$name]} ]]; then
      rm -rf .lake/build/lib/lean/LinearAlgebraDoneRightLean{,.*} .lake/build/ir/LinearAlgebraDoneRightLean{,.*} \
             .lake/build/literate{,-*}
      kind=full
    else
      kind=retry
    fi
    t0=$SECONDS
    lake query :literateHtml > $log 2>&1; rc=$?
    failed[$name]=${rc:#0}
    printf '%s\t%s\t%s\trc=%s\t%ss\t%s\n' $name $i $kind $rc $((SECONDS-t0)) "$(grep -E '^- ' $log | tr '\n' ' ')" >> $here/site-builds.tsv
    cd $here
  done
done
