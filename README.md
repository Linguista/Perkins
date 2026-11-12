# Perkins

![version](https://img.shields.io/badge/version-2.0.42-1f6feb?style=flat-square)
![license](https://img.shields.io/badge/license-AGPL--3.0-2da44e?style=flat-square)
![platforms](https://img.shields.io/badge/runs%20on-Linux%20%7C%20Windows%20%7C%20macOS-8250df?style=flat-square)
![processors](https://img.shields.io/badge/processors-x86--64%20%7C%20ARM64-0969da?style=flat-square)
![input](https://img.shields.io/badge/input-UTF--8-bf8700?style=flat-square)
![output](https://img.shields.io/badge/output-Unicode%20NFC-cf222e?style=flat-square)

Perkins turns Spanish orthographic text into phonemic or semi-narrow transcription (phonemic with all phonologically predictable changes), with syllabification and stress, or into category strings (CV, CVG, CVN, manner, place, voicing). It has modes for running text, lists of words or syllables, Montreal Forced Aligner dictionaries, Praat word tiers and token-aligned output for FreeLing CoNLL files. Its semi-narrow transcription follows Chilean Spanish.

Author: Scott Sadowsky (http://sadowsky.cl). License: GNU Affero General Public License, version 3 (`LICENSE.md`).

Every example on this page was produced by Perkins 2.0.42 itself.

This is essentially an entirely new program with regard to Perkins 1.0.x. Binaries for Linux, Windows and macOS on Intel and ARM processors, and .deb, .rpm and Arch Linux packages are all built and tested by GitHub. The source code is the original Perl script.

## Contents

- [Download and installation](#download-and-installation)
- [Running Perkins](#running-perkins)
- [The example sentence](#the-example-sentence)
- [Phonemic and semi-narrow transcription](#phonemic-and-semi-narrow-transcription)
- [Stress, syllables and symbols](#stress-syllables-and-symbols)
- [Pauses](#pauses)
- [Categories instead of phonemes](#categories-instead-of-phonemes)
- [Numbers](#numbers)
- [Word lists, tokens and dictionaries](#word-lists-tokens-and-dictionaries)
- [All options](#all-options)
- [The configuration file](#the-configuration-file)
- [Documents](#documents)
- [Building from source](#building-from-source)
- [Known problems](#known-problems)
- [Earlier versions](#earlier-versions)

## Download and installation

Ready-built binaries and Linux packages are attached to each release on the [Releases page](https://github.com/Linguista/Perkins/releases). None of them needs Perl. For version 2.0.42:

| File | For | Install with |
|---|---|---|
| `perkins_2.0.42-1_amd64.deb` | Debian, Ubuntu and their derivatives | `sudo apt install ./perkins_2.0.42-1_amd64.deb` |
| `perkins-2.0.42-1.x86_64.rpm` | Fedora | `sudo dnf install ./perkins-2.0.42-1.x86_64.rpm` |
| `perkins-2.0.42-1-x86_64.pkg.tar.zst` | Arch Linux | `sudo pacman -U perkins-2.0.42-1-x86_64.pkg.tar.zst` |
| `perkins_2.0.42-1_arm64.deb` | Debian, Ubuntu and Raspberry Pi OS on ARM processors (64-bit) | `sudo apt install ./perkins_2.0.42-1_arm64.deb` |
| `perkins-2.0.42-1.aarch64.rpm` | Fedora on ARM processors | `sudo dnf install ./perkins-2.0.42-1.aarch64.rpm` |
| `perkins-linux-x86_64` | any other Linux on Intel or AMD processors | see below |
| `perkins-linux-arm64` | any other Linux on ARM processors (64-bit) | see below |
| `perkins-windows-x86_64.exe` | Windows (also Windows on ARM, which runs it through its emulation) | rename it `perkins.exe` and put it in a folder on the PATH |
| `perkins-macos-arm64` | macOS on Apple Silicon (M1 and later) | see below |
| `perkins-macos-x86_64` | macOS on Intel processors | see below |

A package installs `perkins` in `/usr/bin` and its documents in `/usr/share/doc/perkins/`. The package names carry the version, so they change with every release.

Without a package, on Linux and macOS, rename the binary to `perkins`, make it executable and put it in a folder on the PATH:

```bash
mv perkins-linux-x86_64 perkins
chmod +x perkins
```

The macOS binary is not signed, so macOS blocks it the first time. Remove the block with `xattr -d com.apple.quarantine perkins`, or allow it under System Settings → Privacy & Security.

## Running Perkins

```bash
perkins -i=input.txt
perkins -i=input.txt -o=output.txt
perkins -i=input.txt -o=output.txt -nt -st
```

| Rule | |
|---|---|
| Input | plain text, **UTF-8**, given with `-i=`; normalized to Unicode NFC as it is read (`-nonfc` turns this off) |
| Output | the file given with `-o=`, which may not be the input file; without it, a name made from the input's name and the mode (`input.PHNM.txt`, `input.MFA.dict`, `input.PHONWORD`, `input.vrt`) |
| Options | `-x` and `--x` are the same; their order does not matter; there is no limit to how many are used |
| Turning an option off | put `no` after the dash: `-nomc`, `-nocmp`, `-nosd` |
| File names with spaces | in quotation marks: `-i="mi archivo.txt"` |
| Messages | `-b` (batch mode) prints none; `-sm` (silent mode) not even errors |

> [!TIP]
> Perkins reads `perkins.ini` only when it is run with `-cfg`. The examples below add `-nocfg`, which makes sure it is not read, so that they give the same result on every machine.

> [!IMPORTANT]
> Every file Perkins writes is Unicode NFC, so a nasal vowel such as ã is one character. The one exception is an MFA dictionary (`-mfa`), which spells every phone exactly as the acoustic model does.
>
> Perkins also reads its input as NFC: an accent written as a separate combining character (a followed by U+0301, as text copied from macOS, some PDFs and some web pages has it) is joined to its vowel before anything else, so á is read as á. Text already in NFC is unchanged. `-nonfc` turns this off; `-mfa` never does it, so its headwords stay exactly as written. A replacement character (�, U+FFFD) marks a character lost before the text reached Perkins, and no normalization can restore it.

## The example sentence

Unless another input is shown, every example transcribes this file, `source.txt`:

```text
En Concepción, se trata de aguantar la lluvia durante 5 meses del año. ¿Cachái?
```

In the examples, the command is on the colored `@@` line and Perkins' output on the green `+` line.

## Phonemic and semi-narrow transcription

**Phonemic** transcription is the default: IPA, syllables separated by dots, stress marked with ˈ before the stressed syllable, a comma as the short pause | and a full stop as the long pause ‖.

```diff
@@ perkins -nocfg -i=source.txt @@
+ en.kon.sep.ˈsjon | se.ˈt̪ɾa.t̪a.d̪e.a.ɡwan.ˈt̪aɾ.la.ˈʝu.bja.d̪u.ˈɾan.t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt͡ʃaj
```

**Semi-narrow** transcription (`-nt`, `--narrow`) adds every change that the context predicts in Chilean Spanish: b, d and ɡ lenite (aguantar a.ɣ̞wãn̪.ˈt̪aɾ, lluvia ˈʝu.ʋja), n takes the place of the next consonant (cinco ˈsĩŋ.kõ, aguantar ɣ̞wãn̪), velars palatalize before front vowels, and vowels next to a nasal are nasalized.

```diff
@@ perkins -nocfg -i=source.txt -nt @@
+ ẽŋ.kõn.sep.ˈsjõn | se.ˈt̪ɾa.t̪a.ð̞e.a.ɣ̞wãn̪.ˈt̪aɾ.la.ˈʝu.ʋja.ð̞u.ˈɾãn̪.t̪e.ˈsĩŋ.kõ.ˈmẽ.ses.ð̞e.ˈlã.ɲõ ‖ ka.ˈt͡ʃaj
```

> [!NOTE]
> A pause stops the rules: after the comma, se keeps its s, and after a pause b, d and ɡ stay stops. Every rule, with its code, is in [`perkins-narrow-transcription-ruleset_README.md`](perkins-narrow-transcription-ruleset_README.md).

## Stress, syllables and symbols

### Stress

| Option | Stress is marked | Example |
|---|---|---|
| (default) | ˈ before the stressed syllable | `en.kon.sep.ˈsjon` |
| `-st` | an accent on the stressed vowel | `en.kon.sep.sjón` |
| `-oa` | the ordinary apostrophe ' (Praat cannot show ˈ) | `en.kon.sep.'sjon` |
| `-nsm` | not at all | `en.kon.sep.sjon` |

```diff
@@ perkins -nocfg -i=source.txt -nt -st @@
+ ẽŋ.kõn.sep.sjó̃n | se.t̪ɾá.t̪a.ð̞e.a.ɣ̞wãn̪.t̪áɾ.la.ʝú.ʋja.ð̞u.ɾá̃n̪.t̪e.sí̃ŋ.kõ.mé̃.ses.ð̞e.lá̃.ɲõ ‖ ka.t͡ʃáj
```

### Syllables

By default Perkins syllabifies whole sentences, as they are spoken: del año is d̪e.ˈla.ɲo.

| Option | Syllables | Example |
|---|---|---|
| (default) | across words, separated by dots | `d̪e.ˈla.ɲo` |
| `-nosbu` | word by word; words separated by spaces | `d̪el ˈa.ɲo` |
| `-ss` | separated by spaces | `d̪e ˈla ɲo` |
| `-nosd` | not separated | `d̪eˈlaɲo` |

```diff
@@ perkins -nocfg -i=source.txt -nosbu @@
+ en kon.sep.ˈsjon | se ˈt̪ɾa.t̪a d̪e a.ɡwan.ˈt̪aɾ la ˈʝu.bja d̪u.ˈɾan.t̪e ˈsin.ko ˈme.ses d̪el ˈa.ɲo ‖ ka.ˈt͡ʃaj
```

### Symbols

| Option | Effect | lluvia | Cachái |
|---|---|---|---|
| (default) | ye is the fricative ʝ; ch is t͡ʃ with a tie bar | `ˈʝu.bja` | `ka.ˈt͡ʃaj` |
| `-ya` | ye is the affricate | `ˈʤu.bja` | `ka.ˈt͡ʃaj` |
| `-ya -nooye` | the affricate with a tie bar, like ch | `ˈd͡ʒu.bja` | `ka.ˈt͡ʃaj` |
| `-ya -nooye -ar` | affricates with the retracted diacritic | `ˈd̠͡ʒu.bja` | `ka.ˈt̠͡ʃaj` |
| `-gd` | glides as vowels with the non-syllabic diacritic | `ˈʝu.bi̯a` | `ka.ˈt͡ʃai̯` |
| `-nomc` | one character per phoneme, no dental diacritic | `ˈʝu.bja` | `ka.ˈʧaj` |

The cluster tr can be treated as one phoneme, as many Chilean speakers pronounce it:

```diff
@@ perkins -nocfg -i=source.txt -tg @@
+ en.kon.sep.ˈsjon | se.ˈt̪͡ɾa.t̪a.d̪e.a.ɡwan.ˈt̪aɾ.la.ˈʝu.bja.d̪u.ˈɾan.t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt͡ʃaj
@@ perkins -nocfg -i=source.txt -tg -nomc @@
+ en.kon.sep.ˈsjon | se.ˈʂa.ta.de.a.ɡwan.ˈtaɾ.la.ˈʝu.bja.du.ˈɾan.te.ˈsin.ko.ˈme.ses.de.ˈla.ɲo ‖ ka.ˈʧaj
```

## Pauses

A comma or a parenthesis is the short pause |. A full stop, question mark, exclamation mark, colon, semicolon, ellipsis or dash is the long pause ‖, after a word or a number. The period of an abbreviation is not: Sr. Pérez is se.ˈɲoɾ.ˈpe.ɾes.

A word without a vowel right before an ellipsis is a false start, a word cut off, and is read as its sounds: no s ... no logró is no s ‖ no lo.ˈɡɾo, not no ˈe.se. An acronym in capitals and an interjection (mmm ..., sh ...) keep their reading.

Text in square brackets is a transcription marker, not speech: Mira [risas] eso gives `ˈmi.ɾa.???.ˈe.so`. `--marker-symbol=X` writes X instead of ???, and `--no-markers` reads the text in the brackets.

| Option | Effect |
|---|---|
| `-lp2` | the long pause as two bars, `\|\|`, because Praat cannot show ‖ |
| `-noip` | pauses as `(.)`, `(...)`, `##` and `###` instead of IPA bars |
| `-nocmp`, `-noclp`, `-noscp` | commas, colons, semicolons are no pause at all |
| `-nosnp`, `-noelp` | full stops, question and exclamation marks / ellipses are no pause at all |
| `-nopnp` | parentheses are no pause |

```diff
@@ perkins -nocfg -i=source.txt -lp2 @@
+ en.kon.sep.ˈsjon | se.ˈt̪ɾa.t̪a.d̪e.a.ɡwan.ˈt̪aɾ.la.ˈʝu.bja.d̪u.ˈɾan.t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo || ka.ˈt͡ʃaj
@@ perkins -nocfg -i=source.txt -noip @@
+ en.kon.sep.ˈsjon.(.).se.ˈt̪ɾa.t̪a.d̪e.a.ɡwan.ˈt̪aɾ.la.ˈʝu.bja.d̪u.ˈɾan.t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo.##.ka.ˈt͡ʃaj
```

## Categories instead of phonemes

Each segment can be replaced by its category. Stress marks and syllables are kept.

| Option | Each segment becomes |
|---|---|
| `-cv` | C consonant, V vowel |
| `-cvg` | C consonant, V vowel, G glide |
| `-cvn` | C consonant, V vowel, G glide, N nasal, L liquid, R rhotic |
| `-f=MANNER`, `-man` | P plosive, N nasal, R trill, T tap, F fricative, L lateral, A affricate, X approximant, V vowel |
| `-f=PLACE`, `-pl` | B bilabial, L labiodental, D dental, A alveolar, T postalveolar, P palatal, V velar, W labiovelar, G glottal (the h of hmm); vowels in lower case: f front (i, e), c central (a), b back (o, u) |
| `-f=V`, `-voicing` | S voiced (vowels included), A voiceless |

```diff
@@ perkins -nocfg -i=source.txt -cv @@
+ VC.CVC.CVC.ˈCVVC | CV.ˈCCV.CV.CV.V.CVVC.ˈCVC.CV.ˈCV.CVV.CV.ˈCVC.CV.ˈCVC.CV.ˈCV.CVC.CV.ˈCV.CV ‖ CV.ˈCVV
@@ perkins -nocfg -i=source.txt -cvn @@
+ VN.CVN.CVC.ˈCGVN | CV.ˈCRV.CV.CV.V.CGVN.ˈCVR.LV.ˈCV.CGV.CV.ˈRVN.CV.ˈCVN.CV.ˈNV.CVC.CV.ˈLV.NV ‖ CV.ˈCVG
@@ perkins -nocfg -i=source.txt -f=MANNER @@
+ VN.PVN.FVP.ˈFXVN | FV.ˈPTV.PV.PV.V.PXVN.ˈPVT.LV.ˈFV.PXV.PV.ˈTVN.PV.ˈFVN.PV.ˈNV.FVF.PV.ˈLV.NV ‖ PV.ˈAVX
@@ perkins -nocfg -i=source.txt -f=PLACE @@
+ fA.VbA.AfB.ˈAPbA | Af.ˈDAc.Dc.Df.c.VWcA.ˈDcA.Ac.ˈPb.BPc.Db.ˈAcA.Df.ˈAfA.Vb.ˈBf.AfA.Df.ˈAc.Pb ‖ Vc.ˈTcP
@@ perkins -nocfg -i=source.txt -f=V @@
+ SS.ASS.ASA.ˈASSS | AS.ˈASS.AS.SS.S.SSSS.ˈASS.SS.ˈSS.SSS.SS.ˈSSS.AS.ˈASS.AS.ˈSS.ASA.SS.ˈSS.SS ‖ AS.ˈASS
```

> [!CAUTION]
> `-cv`, `-cvg`, `-cvn` and `-f=V` cannot be combined with `-nt`, because every allophone of a phoneme falls in the same category: Perkins stops with an error. `-f=MANNER` and `-f=PLACE` can, and then show the lenited and nasalized segments.

## Numbers

Numbers are read out in full. A number before a noun agrees with it in gender, a time is read with its minutes, and an amount in pesos is read with the currency at the end.

```diff
@@ perkins -nocfg -i=numbers.txt @@
  Llegaron 21 personas a las 12:30 y pagaron $1.500 por 2 entradas.
+ ʝe.ˈɡa.ɾon.bejn.ˈt̪ju.na.peɾ.ˈso.na.sa.las.ˈd̪o.se.ˈt̪ɾejn.t̪a.i.pa.ˈɡa.ɾon.mil.ki.ˈnjen.t̪os.ˈpe.sos.poɾ.d̪o.sen.ˈt̪ɾa.d̪as
```

By default the comma is the decimal separator and the point separates thousands, as in Chile. `-dp` swaps them:

```diff
@@ perkins -nocfg -i=decimal.txt @@
  El total es $12,35.
+ el.t̪o.ˈt̪a.les.ˈd̪o.se.ˈpe.sos.kon.ˈt̪ɾejn.t̪a.i.ˈsin.ko.sen.ˈt̪a.bos
@@ perkins -nocfg -i=decimal.txt -dp @@
+ el.t̪o.ˈt̪a.les.mil.d̪o.ˈsjen.t̪os.ˈt̪ɾejn.t̪a.i.ˈsin.ko.ˈpe.sos
```

| Option | Effect |
|---|---|
| `-non2w` | leave numerals out |
| `-sn=SYMBOL` | replace every numeral with SYMBOL |
| `-nyr`, `-byr`, `-ayr` | read 1900-2000 (four digits), 43-103 (one to four digits), or any such pair, as a range of years: 1900 a 2000 |
| `-bcy` | also years before the Common Era |
| `-notwc` | do not read 14:30 as a time |
| `-cur=TEXT` | read $ as TEXT instead of pesos |

## Word lists, tokens and dictionaries

### Tokens (`-tok`)

Each input line is one sentence, its tokens separated by TABs. Each output line has exactly one transcription per token, also separated by TABs, so the columns line up with the input; the semi-narrow rules still see the whole sentence. This is how the transcription columns of a FreeLing CoNLL file are made.

```diff
@@ perkins -nocfg -i=sentence.tok -tok -nt @@
  Desde	que	mi	abuelo	dijo	adiós	,	bajo	la	lluvia	.
+ ˈd̪es.ð̞e	cẽ	mĩ	a.ˈʋwe.lo	ˈð̞i.xo	a.ˈð̞jos	|	ˈba.xo	la	ˈʝu.ʋja	‖
@@ perkins -nocfg -i=sentence.tok -tok -nt -nosd -st @@
+ d̪ésð̞e	cẽ	mĩ	aʋwélo	ð̞íxo	að̞jós	|	báxo	la	ʝúʋja	‖
```

| Column | Options |
|---|---|
| phonemic, syllables, stress mark | `-tok` |
| phonemic, no syllables, accent on the vowel | `-tok -nosd -st` |
| semi-narrow, syllables, stress mark | `-tok -nt` |
| semi-narrow, no syllables, accent on the vowel | `-tok -nt -nosd -st` |
| manner, place, voicing | `-tok -f=MANNER`, `-tok -f=PLACE`, `-tok -f=V` |

### Lists of words and syllables (`-owl`, `-vrt`, `-sas`)

`-owl` writes one transcribed word per line, in the order of the text, and `-sas` (`-osl`) one syllable per line. A list has no pauses. Words are syllabified word by word. Syllables are cut from running text, as it is spoken, or with `-nosbu` from each word on its own; they carry no stress mark. `-vrt` is a word list with its own settings (stress as an accent on the vowel, one character per phoneme) and a default output file ending in `.vrt`; `-vrt -sas` is a syllable list with the same settings.

```diff
@@ perkins -nocfg -i=source.txt -owl @@
+ en
+ kon.sep.ˈsjon
+ se
+ ˈt̪ɾa.t̪a
@@ perkins -nocfg -i=source.txt -vrt @@
+ en
+ kon.sep.sjón
+ se
+ tɾá.ta
@@ perkins -nocfg -i=source.txt -sas @@
+ ses
+ d̪e
+ la
+ ɲo
@@ perkins -nocfg -i=source.txt -sas -nosbu @@
+ ses
+ d̪el
+ a
+ ɲo
```

The `-sas` lines shown are the syllables of meses del año: across the words by default, word by word with `-nosbu`.

### Word lists as input (`-wl`, `-pw`)

`-wl` treats each line as a separate word or phrase. With `-pw` (`-phonword`), each output line is the input line, a TAB and its transcription: one output line for each input line. Without `-wl`, `-pw` writes one word per line, keeping its capital letters: Concepción, then a TAB and kon.sep.ˈsjon.

```diff
@@ perkins -nocfg -i=words.txt -pw -wl @@
  concepción
  aguantar
  lluvia
  cachái
+ concepción	kon.sep.ˈsjon
+ aguantar	a.ɡwan.ˈtaɾ
+ lluvia	ˈʝu.bja
+ cachái	ka.ˈʧaj
```

### MFA dictionaries (`-mfa`)

`-mfa` writes a pronunciation dictionary for the Montreal Forced Aligner: each word once, a TAB, and its phones separated by spaces, with no stress and no syllables. Perkins sees by itself whether the input is a word list or running text (`--mfa-wl` and `--mfa-rt` force one or the other).

```diff
@@ perkins -nocfg -i=words.txt -mfa @@
+ concepción	k o n s e p s j o n
+ aguantar	a ɡ w a n t̪ a ɾ
+ lluvia	ʝ u b j a
+ cachái	k a tʃ a j
```

> [!IMPORTANT]
> An `-mfa` entry is written only if every phone is in the acoustic model's inventory; any other is left out and counted. `--mfa-phoneset FILE` replaces the built-in inventory, and `--mfa-rules` applies the MFA Spanish dictionary's own allophonic rules. Details in [`HOWTO--Perkins-narrow-transcription.md`](HOWTO--Perkins-narrow-transcription.md).

### Ready-made settings

| Option | For |
|---|---|
| `-rt`, `--corpus` | corpora of running text: accent on the vowel, one character per phoneme |
| `-sl`, `--syl-list` | working with syllables: syllables separated by spaces, ' as the stress mark |
| `-csc`, `--coscach` | the transcription conventions of the COSCACH and CODICACH corpora |
| `-vrt` | a word list: one word per line, accent on the vowel, one character per phoneme |

```diff
@@ perkins -nocfg -i=source.txt -rt @@
+ en.kon.sep.sjón | se.tɾá.ta.de.a.ɡwan.táɾ.la.ʝú.bja.du.ɾán.te.sín.ko.mé.ses.de.lá.ɲo ‖ ka.ʧáj
@@ perkins -nocfg -i=source.txt -csc @@
+ en kon sep sjón | se tɾá ta de a ɡwan táɾ la ʝú bja du ɾán te sín ko mé ses de lá ɲo || ka tʃáj
```

## All options

The same list, in English or Spanish, is shown by `perkins -h` (`perkins -h -es` in Spanish). Most options without a value can be turned off by putting `no` after the dash.

### Main options

| Option | Effect |
|---|---|
| `-i=FILE`, `--input=FILE` | the file to transcribe (required) |
| `-o=FILE`, `--output=FILE` | the file to write (default: a name made from the input's) |
| `-h`, `--help` | the option list |
| `-u`, `--usage` | usage notes and examples |
| `-cfg`, `-ini` / `-nocfg`, `-noini` | read / do not read `perkins.ini` (not read by default) |
| `-cf=NAME`, `--config-file=NAME` | read NAME instead of `perkins.ini` |
| `-b`, `--batch` | print no messages |
| `-sm`, `--silent-mode` | print nothing, not even errors, and write no log |
| `-l=en`, `-l=es`, `-en`, `-es` | messages in English or Spanish |
| `-d`, `--debug` / `-dl`, `--debug-log` | show debugging information / save it to a `.log` file |
| `-nonfc` | do not normalize the input to Unicode NFC (normalized by default; never in `-mfa`) |

### Ready-made settings

| Option | Effect |
|---|---|
| `-rt`, `--corpus` | corpora of running text |
| `-sl`, `--syl-list` | work at the level of the syllable |
| `-mfa` | an MFA pronunciation dictionary |
| `-vrt` | a word list (with `-sas`, a syllable list) with its own settings |
| `-wl`, `--word-list` | word lists: syllables word by word |
| `-csc`, `--coscach` | COSCACH transcriptions |

### MFA dictionaries

| Option | Effect |
|---|---|
| `--mfa-rules` | apply the MFA Spanish dictionary's own allophonic rules (off by default) |
| `--mfa-phoneset FILE` | the phone inventory to check entries against, one phone per line |
| `--mfa-wl`, `--mfa-rt` | the input is a word list / running text |

### Transcription mode

| Option | Effect |
|---|---|
| `-f=MODE`, `--format=MODE` | PH phonemic, CV, CVG, CVN, M or MANNER, P or PLACE, V voicing |
| `-phon`, `-ph` | phonemic transcription (the default) |
| `-cv`, `-cvg`, `-cvn` | consonant and vowel categories |
| `-manner`, `-man` | manner of articulation |
| `-place`, `-pl` | place of articulation |
| `-voicing`, `-v` | voicing |
| `-phonword`, `-pw` | one word per line: the word, a TAB, its transcription |
| `-tokens`, `-tok` | token mode: TAB-separated tokens in, one transcription per token out |
| `-nt`, `--narrow` | semi-narrow transcription, on top of any mode but `-cv`, `-cvg`, `-cvn` and `-f=V` |

### Phoneme symbols

| Option | Effect |
|---|---|
| `-multi`, `-mc` | multi-character symbols for some phonemes (t͡ʃ); `-nomc` for one character each (ʧ) |
| `-och` | ch is ʧ whatever the other settings |
| `-tg` | tr is one phoneme: t͡ɾ with `-mc`, ʂ with `-nomc` |
| `-yf` / `-ya` | ye is the fricative ʝ / the affricate ʤ |
| `-oye` / `-nooye` | ye with one character (ʝ, ʤ) whatever the other settings (the default) / following them (d͡ʒ) |
| `-ar` | the retracted diacritic in the affricates (t̠͡ʃ) |
| `-lig` / `-nolig` | tie bars in t͡ʃ and d͡ʒ / none (with `-mc`) |
| `-dd`, `--dent` | the dental diacritic on t and d (with `-mc`) |
| `-aeg` | an epenthetic ɡ before w (hueco ˈɡwe.ko) |
| `-chsc`, `-chrl`, `-chrnl`, `-chnrl`, `-chnrnl` | ch as ʧ, t̠͡ʃ, t̠ʃ, t͡ʃ or tʃ, overriding the settings above |
| `-gd`, `--glides-dia` / `-nogd` | glides as i̯ and u̯ / as j and w |
| `-wv`, `-yv` | only wau, only yod, with the non-syllabic diacritic |

### Stress and syllables

| Option | Effect |
|---|---|
| `-st` | stress as an accent on the vowel |
| `-oa` | stress as the ordinary apostrophe |
| `-nsm`, `--no-stress-marks` | no stress marks |
| `-sd`, `--syl-dots` | syllables separated by dots (the default) |
| `-ss`, `--syl-spaces` | syllables separated by spaces |
| `-nosd` | syllables not separated |
| `-sbu` / `-nosbu` | syllables across the sentence (the default) / word by word |

### Pauses

| Option | Effect |
|---|---|
| `-ip`, `--ipa-pauses` | pauses as the IPA bars \| and ‖ (the default) |
| `-lp2` | the long pause as \|\| |
| `-cmp`, `-clp`, `-scp` | commas, colons, semicolons are pauses (the default) |
| `-snp`, `-ppp` | sentence breaks, paragraph breaks are pauses (the default); every input line keeps its own output line either way |
| `-elp`, `-brp`, `-pnp` | ellipses, brackets, parentheses are pauses (the default) |
| `--markers` / `--no-markers` | text in square brackets is a marker (the default) / is read |
| `--marker-symbol=X` | what a marker becomes (default ???) |

### Numbers and substitutions

| Option | Effect |
|---|---|
| `-n2w` | numerals read as words (the default) |
| `-sn=SYMBOL` | numerals replaced by SYMBOL |
| `-nyr`, `-byr`, `-ayr`, `-bcy` | ranges of years |
| `-twc`, `--times-colon` | 14:30 as a time (the default) |
| `-dc`, `--decimal-comma` / `-dp`, `--decimal-period` | the comma (the default) / the point as the decimal separator |
| `-cur=TEXT` | $ read as TEXT |
| `-lo=TEXT` | / read as TEXT |
| `-pu`, `-pe` | read URLs, e-mail addresses (otherwise they are deleted) |

### Presentation

| Option | Effect |
|---|---|
| `-kp` | keep paragraph breaks |
| `-tvd` | three or more identical vowels become two: nooo noo (the default) |
| `-owl` | one word per line, no pauses |
| `-sas`, `-osl`, `--split-syls` | one syllable per line, no pauses, no stress marks; across words, or word by word with `-nosbu` |

## The configuration file

`perkins.ini` holds every setting, each documented beside it. Perkins reads it only when it is run with `-cfg`, from the folder it is run in; `-cf=NAME` reads another file. An option given on the command line overrides the file.

```bash
perkins -cfg -i=input.txt
perkins -cfg -cf=corpora.ini -i=input.txt
```

## Documents

| | |
|---|---|
| `perkins_README.md` | what Perkins does, its built-in pronunciations, its version history |
| `perkins-narrow-transcription-ruleset_README.md` | every narrow-transcription rule, with its code |
| `HOWTO--Perkins-narrow-transcription.md` | using `--narrow` |
| `HOWTO--Perkins-compilation.md` | building, checking and installing the binary, and how the binaries and packages here are built |
| `perkins.ini` | every setting |
| `tests/README.md` | the build check |

## Building from source

Perkins is a single Perl script, `perkins.pl`, that needs two modules besides core Perl: `Roman` and `Lingua::ES::Numeros`. It is packed into a binary with PAR::Packer:

```bash
cpanm PAR::Packer Roman Lingua::ES::Numeros
pp -M Roman -M Lingua::ES::Numeros -o perkins perkins.pl
bash tests/run-test.sh "$PWD/perkins"
```

The tests must end with ALL TESTS PASSED.

When a release is published here, GitHub builds the five binaries and tests each of them (the Linux ones also on Fedora), makes the Linux packages (`packaging/nfpm.yaml`) and tests them on Fedora, Debian, Ubuntu and Arch Linux, and attaches everything to the release (`.github/workflows/build.yml`).

## Known problems

> [!WARNING]
> These are known and not yet fixed in 2.0.42:
>
> - A single letter with a period is read as the letter's name, before anything else: p. m. and a. m. are pe eme and a eme, and i. e. is i e. EE. UU. is e ‖ u u.
> - The period of an abbreviation is never a sentence end, even when it ends one: Vino el Sr. Luego se fue has no pause after se.ˈɲoɾ.

## Earlier versions

Perkins 1.0.6, published here in 2016, with its Linux and Windows binaries, is in the history of this repository: https://github.com/Linguista/Perkins/tree/27a8c9c83b2b8fcfddb430b5c2af2e33d2513f70. It is very, very deprecated.
