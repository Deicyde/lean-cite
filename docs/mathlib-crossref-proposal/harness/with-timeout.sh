#!/bin/zsh
# Usage: with-timeout.sh <seconds> <command...>. SIGALRM survives exec, so the command dies at the
# deadline and exits 142, which callers count as a failure. macOS has no `timeout`.
exec perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "$@"
