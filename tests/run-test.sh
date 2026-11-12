#!/usr/bin/env bash
# VERSION 1.11.0
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
check lists-words        lists.txt    expected/lists-words.txt        -owl
check lists-vrt          lists.txt    expected/lists-vrt.txt          -vrt
check lists-syllables    lists.txt    expected/lists-syllables.txt    -sas
check lists-syllables-word lists.txt  expected/lists-syllables-word.txt -sas -nosbu
check lists-vrt-syllables lists.txt   expected/lists-vrt-syllables.txt -vrt -sas
check lists-lines        lists.txt    expected/lists-lines.txt        -nosbu -noppp
check lists-phonword     lists.txt    expected/lists-phonword.txt     -phonword
check lists-place        lists.txt    expected/lists-place.txt        -nosbu -f=PLACE
check abbreviations      abbreviations.txt expected/abbreviations.txt -nosbu
check ellipsis-phonemic  ellipsis.txt expected/ellipsis-phonemic.txt  -nosbu
check ellipsis-noelp     ellipsis.txt expected/ellipsis-noelp.txt     -nosbu -noelp
check ellipsis-nosnp     ellipsis.txt expected/ellipsis-nosnp.txt     -nosbu -nosnp
check ellipsis-nopi-noelp ellipsis.txt expected/ellipsis-nopi-noelp.txt -nosbu -nopi -noelp
check ellipsis-tokens-noelp ellipsis.tok expected/ellipsis-tokens-noelp.txt -tok -nt -noelp
check nasal-tokens-narrow nasal.tok  expected/nasal-tokens-narrow.txt -tok -nt
check nasal-narrow       nasal.txt    expected/nasal-narrow.txt       -nosbu -nt
check nasal-tokens-manner nasal.tok   expected/nasal-tokens-manner.txt -tok -f=MANNER
check nasal-tokens-place nasal.tok    expected/nasal-tokens-place.txt -tok -f=PLACE
check nasal-tokens-voicing nasal.tok  expected/nasal-tokens-voicing.txt -tok -f=V
check decimals-phonemic  decimals.txt expected/decimals-phonemic.txt  -nosbu
check interjections-tokens interjections.tok expected/interjections-tokens.txt -tok
check interjections-tokens-csc interjections.tok expected/interjections-tokens-csc.txt -tok -csc
check interjections-tokens-manner interjections.tok expected/interjections-tokens-manner.txt -tok -f=MANNER
check interjections-tokens-place interjections.tok expected/interjections-tokens-place.txt -tok -f=PLACE
check interjections-tokens-voicing interjections.tok expected/interjections-tokens-voicing.txt -tok -f=V
check falsestart-tokens  falsestart.tok expected/falsestart-tokens.txt -tok
check falsestart-tokens-narrow falsestart.tok expected/falsestart-tokens-narrow.txt -tok -nt
check falsestart-tokens-csc falsestart.tok expected/falsestart-tokens-csc.txt -tok -csc
check falsestart-tokens-manner falsestart.tok expected/falsestart-tokens-manner.txt -tok -f=MANNER
check falsestart-phonemic falsestart.txt expected/falsestart-phonemic.txt -nosbu
check falsestart-narrow  falsestart.txt expected/falsestart-narrow.txt -nosbu -nt
check round9-tokens      round9.tok   expected/round9-tokens.txt     -tok
check round9-tokens-narrow round9.tok expected/round9-tokens-narrow.txt -tok -nt
check round9-tokens-csc  round9.tok   expected/round9-tokens-csc.txt -tok -csc
check round9-tokens-manner round9.tok expected/round9-tokens-manner.txt -tok -f=MANNER
check round9-tokens-place round9.tok  expected/round9-tokens-place.txt -tok -f=PLACE
check round9-tokens-voicing round9.tok expected/round9-tokens-voicing.txt -tok -f=V
check round9-phonemic    round9.txt   expected/round9-phonemic.txt   -nosbu
check round9-utter-phnm  round9.txt   expected/round9-utter-phnm.txt -mc -dd -sd -ip -nost
check nfc-phonemic      nfc.txt      expected/nfc-phonemic.txt      -nosbu
check nfc-off           nfc.txt      expected/nfc-off.txt           -nosbu -nonfc
check nfc-tokens        nfc.tok      expected/nfc-tokens.txt        -tok

if [ "$fail" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; fi
exit "$fail"
