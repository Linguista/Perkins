#!/usr/bin/env bash
# VERSION 1.6.0
#
# run-test.sh -- checks a Perkins build against the expected outputs in this
# folder. Usage: ./run-test.sh [PERKINS_COMMAND]
# PERKINS_COMMAND defaults to "perkins" (the binary on the PATH); give a path
# to check another build, for example ./run-test.sh ../perkins
# Line endings are ignored (CRLF on Windows). Exit 0 when every test passes,
# 1 otherwise.

set -u
cd "$(dirname "$0")" || exit 2
P="${1:-perkins}"
TMP="$(mktemp -d)"
trap '\rm -rf "$TMP"' EXIT

fail=0
check() {
	local name="$1" input="$2" expected="$3"
	shift 3
	if ! $P -nocfg -b "$@" -i="$input" -o="$TMP/$name.out" >/dev/null 2>"$TMP/$name.err"; then
		echo "FAIL  $name  (Perkins exited with an error; see below)"
		cat "$TMP/$name.err"
		fail=1
		return
	fi
	if diff -q --strip-trailing-cr "$expected" "$TMP/$name.out" >/dev/null; then
		echo "ok    $name"
	else
		echo "FAIL  $name"
		diff --strip-trailing-cr "$expected" "$TMP/$name.out"
		fail=1
	fi
}

check sentence-phonemic  sentence.txt expected/sentence-phonemic.txt  -nosbu
check sentence-narrow    sentence.txt expected/sentence-narrow.txt    -nosbu -nt
check tokens-phonemic    tokens.tok   expected/tokens-phonemic.txt    -tok
check tokens-phonemic-nd tokens.tok   expected/tokens-phonemic-nd.txt -tok -nosd -st
check tokens-narrow      tokens.tok   expected/tokens-narrow.txt      -tok -nt
check tokens-narrow-nd   tokens.tok   expected/tokens-narrow-nd.txt   -tok -nt -nosd -st
check tokens-manner      tokens.tok   expected/tokens-manner.txt      -tok -f=MANNER
check tokens-place       tokens.tok   expected/tokens-place.txt       -tok -f=PLACE
check tokens-voicing     tokens.tok   expected/tokens-voicing.txt     -tok -f=V
check phrases-phonemic   phrases.txt  expected/phrases-phonemic.txt   -nosbu
check phrases-narrow     phrases.txt  expected/phrases-narrow.txt     -nosbu -nt
check phrases-tokens     phrases.tok  expected/phrases-tokens.txt     -tok
check ellipsis-narrow    ellipsis.tok expected/ellipsis-narrow.txt    -tok -nt
check features-phonemic  features.txt expected/features-phonemic.txt  -nosbu
check features-narrow    features.txt expected/features-narrow.txt    -nosbu -nt
check features-nocomma   features.txt expected/features-nocomma.txt   -nosbu -nocmp
check features-tokens    features.tok expected/features-tokens.txt    -tok
check features-tokens-narrow features.tok expected/features-tokens-narrow.txt -tok -nt
check pauses-narrow      pauses.txt   expected/pauses-narrow.txt      -nosbu -nt
check pauses-tokens-narrow pauses.tok expected/pauses-tokens-narrow.txt -tok -nt
check pauses-tokens-lp2  pauses.tok   expected/pauses-tokens-lp2.txt  -tok -lp2
check pauses-tokens-nopi pauses.tok   expected/pauses-tokens-nopi.txt -tok -nopi
check pauses-nopi-narrow pauses.txt   expected/pauses-nopi-narrow.txt -nosbu -nopi -nt
check pauses-noclp-narrow pauses.txt  expected/pauses-noclp-narrow.txt -nosbu -noclp -noscp -nt
check numbers-phonemic   numbers.txt  expected/numbers-phonemic.txt   -nosbu
check numbers-tokens     numbers.tok  expected/numbers-tokens.txt     -tok

if [ "$fail" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; fi
exit "$fail"
