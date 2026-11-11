# README.md (Perkins tests)

Documents `run-test.sh` 1.6.0 and the files beside it.

## Purpose

Checks that a Perkins build prints exactly what Perkins 2.0.35 printed on 261110 for:

- the test sentence approved on 261030 (`sentence.txt`), phonemic and narrow; its comma is now the short pause |, which is the only difference from the approved line;
- a TAB-separated token file (`tokens.tok`) in token mode, once for each of the seven COSCACH CoNLL columns: phonemic and narrow, each with syllable dots and the stress mark and each with no syllabification and an accented vowel; manner, place and voicing.

- the built-in phrase readings (`phrases.txt`, `phrases.tok`): Guns N' Roses and guns and roses as gansenróses, rock and roll in its spellings as rocanról, AC/DC and ACDC as ej.si.ˈd̪i.si, in running text and in token mode, where a phrase over several tokens puts its reading on the first token and leaves the others empty.

- an ellipsis token in token mode (`ellipsis.tok`), which must be the long pause and block the narrow rules: titular ... voy keeps the stop in boj.

- the cases of `features.txt` and `features.tok`: commas as the short pause after a word and after a number, and no pause with `-nocmp`; a written uno kept; a diphthong with a written accent (náufrago); a liquid between a glide and a glide (dinosaurio) or a consonant (bourbon); ui as a diphthong outside the -uir verbs (Luis, buitre, huincha, intuición) and the hiatus in construir and in vos incluis written without its accent; y as a vowel (Lynn, whisky) and as a glide (Reynaldo); a final double n (Lynn); the any-case table with its exact-case exceptions (PSU and psu, AND and and, UP and up, WoW and wow); and in token mode the initials J. and Dr., aylwin, WhatsApp and a comma token.

- pauses (`pauses.txt`, `pauses.tok`): a colon after a word and after a number, a semicolon and a full stop after a number are the long pause ‖ in running text and in token mode, || with `-lp2` and (...) or ## with `-nopi`; after the pause b keeps its stop (ben, bajamos).

- `-nopi` and `-noclp -noscp` on `pauses.txt`, narrow: ## and (...) after a word, with b keeping its stop after them; and with the colon and semicolon switched off, no pause, so the rules apply across (ʋẽn, ˈpa.sã nõ).

- numbers (`numbers.txt`, `numbers.tok`): a number before a noun agreeing in gender (un perro, una casa, veintiún años, veintiuna horas, doscientas personas, doscientas mil personas, veintiún mil, mil quinientas personas, ciento una noches) and left alone before a word that is not a noun (uno de cada tres); 12.30 as doce punto treinta and 3.75 as tres punto setenta y cinco; ordinals (1a primera, 1er primer, 3as terceras, 1.ª primera, 21a veintiuna).

Every output is Unicode NFC: a nasal vowel is one character (ã ẽ ĩ õ ũ). `-mfa` dictionaries are the exception, and no test here uses `-mfa`.

`tokens.tok` covers the cases that 2.0.32 changed: lenition across words and after a pause, the stand-ins XXXREDACTEDXXX and XXXUNINTELLIGIBLEXXX, a backchannel, a spelled acronym (PDI), an underscore, a number, and an empty line.

## Usage

In the folder holding `tests/`:

```bash
bash tests/run-test.sh
bash tests/run-test.sh "$PWD/perkins"
```

With no argument it checks `perkins` on the PATH; with an argument it checks that command. Give a full path: the script works from its own folder. Every run uses `-nocfg -b`, so no `perkins.ini` changes the result.

Line endings are ignored, so a Windows build, which writes CRLF, is checked against the same expected files.

Output: `ok` or `FAIL` per test, with a `diff` (expected first) for each failure, then `ALL TESTS PASSED` or `SOME TESTS FAILED`. Exit code 0 when all pass, 1 otherwise, 2 when the folder cannot be entered.

| Test | Input | Options | Expected |
|---|---|---|---|
| sentence-phonemic | sentence.txt | `-nosbu` | expected/sentence-phonemic.txt |
| sentence-narrow | sentence.txt | `-nosbu -nt` | expected/sentence-narrow.txt |
| tokens-phonemic | tokens.tok | `-tok` | expected/tokens-phonemic.txt |
| tokens-phonemic-nd | tokens.tok | `-tok -nosd -st` | expected/tokens-phonemic-nd.txt |
| tokens-narrow | tokens.tok | `-tok -nt` | expected/tokens-narrow.txt |
| tokens-narrow-nd | tokens.tok | `-tok -nt -nosd -st` | expected/tokens-narrow-nd.txt |
| tokens-manner | tokens.tok | `-tok -f=MANNER` | expected/tokens-manner.txt |
| tokens-place | tokens.tok | `-tok -f=PLACE` | expected/tokens-place.txt |
| tokens-voicing | tokens.tok | `-tok -f=V` | expected/tokens-voicing.txt |
| phrases-phonemic | phrases.txt | `-nosbu` | expected/phrases-phonemic.txt |
| phrases-narrow | phrases.txt | `-nosbu -nt` | expected/phrases-narrow.txt |
| phrases-tokens | phrases.tok | `-tok` | expected/phrases-tokens.txt |
| ellipsis-narrow | ellipsis.tok | `-tok -nt` | expected/ellipsis-narrow.txt |
| features-phonemic | features.txt | `-nosbu` | expected/features-phonemic.txt |
| features-narrow | features.txt | `-nosbu -nt` | expected/features-narrow.txt |
| features-nocomma | features.txt | `-nosbu -nocmp` | expected/features-nocomma.txt |
| features-tokens | features.tok | `-tok` | expected/features-tokens.txt |
| features-tokens-narrow | features.tok | `-tok -nt` | expected/features-tokens-narrow.txt |
| pauses-narrow | pauses.txt | `-nosbu -nt` | expected/pauses-narrow.txt |
| pauses-tokens-narrow | pauses.tok | `-tok -nt` | expected/pauses-tokens-narrow.txt |
| pauses-tokens-lp2 | pauses.tok | `-tok -lp2` | expected/pauses-tokens-lp2.txt |
| pauses-tokens-nopi | pauses.tok | `-tok -nopi` | expected/pauses-tokens-nopi.txt |
| pauses-nopi-narrow | pauses.txt | `-nosbu -nopi -nt` | expected/pauses-nopi-narrow.txt |
| pauses-noclp-narrow | pauses.txt | `-nosbu -noclp -noscp -nt` | expected/pauses-noclp-narrow.txt |
| numbers-phonemic | numbers.txt | `-nosbu` | expected/numbers-phonemic.txt |
| numbers-tokens | numbers.tok | `-tok` | expected/numbers-tokens.txt |

## When a change is intended

When a new version changes an output on purpose, check the new output by eye, replace the file in `expected/`, and record the change in the version's changelog. 2.0.35 changed four: `sentence-phonemic` and `sentence-narrow` (the comma pause) and `phrases-phonemic` and `phrases-narrow` (Bon Jovi: jovi is respelled yóbi in the COSCACH review, so it is ˈʝo.bi, not ˈxo.bi). It also rewrote the six narrow expected files (`sentence-narrow`, `tokens-narrow`, `tokens-narrow-nd`, `phrases-narrow`, `features-narrow`, `features-tokens-narrow`) in NFC: each is exactly the NFC form of what it was, so only the nasal vowels changed bytes.

## Platform

bash on Linux and macOS; on Windows, Git Bash or WSL. GitHub runs it on every build of the public repository (Linux, Fedora, Windows and macOS).
