# perkins_README.md

Documents Perkins 2.0.37, the Spanish phonological transcriber (Scott Sadowsky, GNU AGPL v3).

The source, the binaries for Linux, Windows and macOS and the Linux packages are at https://github.com/Linguista/Perkins, whose main page also shows every option with examples.

## Purpose

Perkins turns Spanish orthographic text into phonemic or narrow (allophonic) transcription, with syllabification and stress, or into category strings (CV, CVG, CVN, manner, place, voicing). It has modes for running text, word lists, verticalized text, Montreal Forced Aligner dictionaries, Praat word tiers (`-phonword`) and token-aligned output for FreeLing CoNLL files (`--tokens`).

The full option list is `perkins -h`; examples are `perkins -u`.

## Usage

Always run the compiled binary, `perkins`, not the `.pl`.

```bash
perkins -i=input.txt -o=output.txt
perkins -i=input.txt -o=output.txt -nt
perkins -nocfg -b -wl -pw -i=words.txt -o=words.out
perkins -nocfg -b -tok -nt -i=sentences.tok -o=sentences.out
```

### Pauses

A comma is the short pause |; a full stop, question mark, exclamation mark, colon, semicolon, ellipsis or dash is the long pause ‖ (|| with `-lp2`), after a word or a number, in running text and in token mode. A pause blocks the narrow rules that apply across words: in "la lluvia, bajo el techo" bajo keeps its stop (ˈba.xo), while in "la lluvia bajo el techo" it is lenited (ˈʋa.xo). `-nocmp` makes the comma no pause at all; `-mfa`, `-phonword` and vertical output switch comma pauses off themselves.

### Numbers

A number before a noun agrees with it in gender: 1 perro un perro, 1 casa una casa, 21 años veintiún años, 21 horas veintiuna horas, 200 personas doscientas personas, 200 mil personas doscientas mil personas. The gender comes from the common nouns of the es-CL FreeLing dictionary that have a single gender, built into Perkins; a word that is not one of them (de, que, a verb) leaves the number alone (1 de cada 3 uno de cada tres). With the decimal comma, a number written with a point and not three digits after it is a decimal read with punto, one or two digits after the point as a number (12.30 doce punto treinta, 3.75 tres punto setenta y cinco); a time is written with a colon (12:30 doce treinta). Ordinals follow their suffix: 1.ª and 1a primera, 2os segundos, 3as terceras, 1er primer, 3er tercer.

### Unicode

Every output file is NFC, so a nasal vowel is one character (ã ẽ ĩ õ ũ); a diacritic with no precomposed form stays a combining mark (d̪, ɣ̞, n̪), which is already NFC. The one exception is `-mfa`: an MFA dictionary spells every phone exactly as the acoustic model does, and the models in use spell the nasal vowels as the vowel plus U+0303, so `-mfa` keeps them that way.

### Token mode (`--tokens`, `-tok`)

Each input line is one sentence whose tokens are separated by TABs. Each output line has exactly one transcription per token, separated by TABs: the same number of fields as the input line, and an empty line for an empty line. Punctuation that Perkins reads as a pause gets the pause symbol (a comma |; a full stop, question mark, colon or semicolon ‖); a token that produces nothing (an opening ¿ or ¡) gets an empty field.

The narrow rules see the whole sentence, so "padre bajo" gives ˈʋa.xo for bajo, while a pause token blocks them. A token that is only an ellipsis (..., or …) is the long pause, as in running text. Any output format, stress convention and syllable option can be combined with it.

The seven transcription columns of the COSCACH CoNLL files are produced with:

| Column | Options |
|---|---|
| phonemic, syllable dots and stress mark | `-tok` |
| phonemic, no syllabification, stress as an accent on the vowel | `-tok -nosd -st` |
| narrow, syllable dots and stress mark | `-tok -nt` |
| narrow, no syllabification, stress as an accent on the vowel | `-tok -nt -nosd -st` |
| manner, place, voicing | `-tok -f=MANNER`, `-tok -f=PLACE`, `-tok -f=V` |

### `-phonword` with `-wl`

Exactly one output line per input line: the input line verbatim, a TAB, and the transcription of everything that line produced (14 gives catorce; a multiword gives its words joined by a space). `-phonword` honours `-f=`, `-nosd`, `-ss`, `-nsm` and `-st`.

## Built-in pronunciations

Perkins carries its special readings in the program itself, in four tables applied to whole tokens before any other processing. They work in every mode. To add an entry, edit the table in the source and recompile.

| Table | Matched | Holds |
|---|---|---|
| `%BUILTIN_RESPELL` | exact case | acronyms and codes read as letters (PDI as pedeí, B-32 as betreintaidós) and other overrides, from the COSCACH inventory |
| `%BUILTIN_IPA` | exact case, then lowercase | fixed phonemic transcriptions: backchannels and fillers (mmhm as m̩.ˈhm̩, mmm as m̩ː, nn as n̩ː), and three names: aylwin ˈejl.win, revenge re.ˈbenʝ, selj selʝ |
| `%BUILTIN_RESPELL_ANYCASE` | lowercase, after the two above | 2,655 respellings of the COSCACH spelling review |
| `@BUILTIN_PHRASES` | a pattern, without regard to case | multiword names read as one Spanish word |

A respelling is an ordinary Spanish spelling that Perkins then transcribes: a written accent marks the stressed letter, a space keeps two letters out of a diphthong, and an empty respelling removes the token.

How the tables meet:

- The exact-case table is looked up first, so a word in capitals that is another word keeps its own reading: AND is aenedé while and is an, UP is upé while up is ap, WoW (the game) is wow while wow is waw, RR is erreérre while rr stays the backchannel r̩.
- Letters respelled as separate letter names are joined, with the stress on the last letter, as an acronym is said: psu (pe ese u) is peeseú, pe.e.se.ˈu. A space stays where two vowels would make a diphthong (u ese bé) or three identical vowels would meet.
- An entry that ends in a period (J., Dr., C.C.U.) is looked up with its period, before anything else, so Dr. is doctor, while Dr without the period stays the backchannel dɾ̩.
- mm is deliberately absent everywhere: filler or millimetres is a judgement call, so it keeps Perkins' ordinary handling.

The phrase table:

| Phrase | Read as |
|---|---|
| Guns N' Roses, guns and roses, Guns_N_'_Roses | gansenróses |
| rock and roll, rock n' roll, rock 'n' roll, rock & roll | rocanról |
| baby shower | béibi cháuer |
| bass house | bas jáus |
| pokémon go | pókemon gó |
| ray bradbury | réi brádberi |
| scrum master | escrám máster |

A phrase's words may be separated by spaces, underscores (FreeLing multiwords) and apostrophes. In running text the phrase is replaced before transcription. With `--tokens`, a phrase spread over several tokens (rock, and, roll) gets its reading on its first token and empty fields on the others; a joined token gets it whole.

AC/DC, ACDC, AC-DC and acdc are read eisidísi (ej.si.ˈd̪i.si).

Other fixed behaviour:

- XXXREDACTEDXXX and XXXNUMXXX become the long pause ‖ (|| with `-lp2`); XXXUNINTELLIGIBLEXXX becomes the short pause |.
- An all-capitals token that can be pronounced as a Spanish word is read as a word (INACAP); one that cannot is spelled (PDI).
- The underscore separates words; it is read aloud only inside URLs and e-mail addresses.
- A written uno is never cut to un (uno nunca sabe, me quedé con uno solo). Only a number written in digits is: before a unit or a currency (1 km un kilómetro, $1 un peso) and before a masculine noun, with which it agrees (1 perro un perro; see Numbers).
- The -uir verbs keep u and i apart with the stress on i (huir u.ˈiɾ, construir kons.tɾu.ˈiɾ, incluido in.klu.ˈi.do); every other ui is a diphthong (buitre ˈbwi.tɾe, Luis lwis, intuición in.twi.ˈsjon, huincha ˈwin.ʧa).
- The letter y is the vowel i when no vowel is next to it (Lynn, sexy, whisky, nylon) and the glide between a vowel and a consonant (Reynaldo rej.ˈnal.do); before a vowel it is the consonant ʝ (yo, playa).

## Installing

Ready-built binaries and packages are attached to each release on the Releases page of https://github.com/Linguista/Perkins:

| File | For | Install with |
|---|---|---|
| `perkins_2.0.37-1_amd64.deb` | Debian, Ubuntu and their derivatives | `sudo apt install ./perkins_2.0.37-1_amd64.deb` |
| `perkins-2.0.37-1.x86_64.rpm` | Fedora | `sudo dnf install ./perkins-2.0.37-1.x86_64.rpm` |
| `perkins-2.0.37-1-x86_64.pkg.tar.zst` | Arch Linux | `sudo pacman -U perkins-2.0.37-1-x86_64.pkg.tar.zst` |
| `perkins_2.0.37-1_arm64.deb` | Debian, Ubuntu and Raspberry Pi OS on ARM processors (64-bit) | `sudo apt install ./perkins_2.0.37-1_arm64.deb` |
| `perkins-2.0.37-1.aarch64.rpm` | Fedora on ARM processors | `sudo dnf install ./perkins-2.0.37-1.aarch64.rpm` |
| `perkins-linux-x86_64` | any other Linux on Intel or AMD processors | as described below the table |
| `perkins-linux-arm64` | any other Linux on ARM processors (64-bit) | as described below the table |
| `perkins-windows-x86_64.exe` | Windows (also Windows on ARM, which runs it through its emulation) | rename it `perkins.exe` and put it in a folder on the PATH |
| `perkins-macos-arm64` | macOS on Apple Silicon (M1 and later) | as described below the table |
| `perkins-macos-x86_64` | macOS on Intel processors | as described below the table |

A package installs `perkins` in `/usr/bin`. Without a package, on Linux and macOS, rename the binary to `perkins`, make it executable (`chmod +x perkins`) and put it in a folder on the PATH. The macOS binaries are not signed, so macOS blocks them the first time: `xattr -d com.apple.quarantine perkins` removes the block.

The package names carry the version. Building the binary from the source, and how GitHub builds the binaries and packages, are in `HOWTO--Perkins-compilation.md`. In short:

```bash
pp -M Roman -M Lingua::ES::Numeros -o perkins perkins.pl
./perkins -h 2>&1 | grep -m1 'Perkins v'
```

It must print `Perkins v2.0.37`.

## Checking a build

`tests/` holds the test sentence approved on 261030 with its expected phonemic and narrow output, a token file with its expected output for each of the seven CoNLL columns, the phrase readings, an ellipsis token, and the cases of commas, uno, diphthongs, ui, the any-case table, the colon and the full stop after a number as long pauses, NFC output. In the folder holding `tests/`, check the binary on the PATH:

```bash
bash tests/run-test.sh
```

or a binary not yet installed, by giving its full path:

```bash
bash tests/run-test.sh "$PWD/perkins"
```

It prints ok or FAIL for each test, with the differences, and ALL TESTS PASSED at the end. Details in `tests/README.md`.

## Documents

| | |
|---|---|
| `README.md` | installation, and every option with examples of what Perkins writes |
| `perkins-narrow-transcription-ruleset_README.md` | every narrow rule, with its code |
| `HOWTO--Perkins-narrow-transcription.md` | using `--narrow` |
| `HOWTO--Perkins-compilation.md` | building, checking and installing the binary; the binaries and packages built by GitHub |
| `perkins.ini` | every setting, and the changes no setting controls |
| `tests/` | the build check |

## Version history

- **2.0.37** (2026-11-10): no change in output. Comments and documents no longer name files, folders and projects that are not part of Perkins; the help banner names the licence file as `LICENSE.md`; every option with real examples on the main page of the repository (`README.md`); binaries for Linux and macOS on both Intel and ARM processors, and `.deb` and `.rpm` packages for ARM; the GitHub build checks the repository for private information before building.
- **2.0.36** (2026-11-10): no change in output. Comments and documents reworded, version numbers taken out of the comments outside the changelog, the error for the old -g2p option no longer names a version; the source published at https://github.com/Linguista/Perkins, where GitHub builds and tests binaries for Linux, Windows and macOS; the tests ignore line endings, so they also run on Windows.
- **2.0.35** (2026-11-10): 2,655 respellings of the COSCACH spelling review as a built-in table matched in any case, five more phrases, aylwin ˈejl.win, revenge re.ˈbenʝ and selj selʝ as fixed transcriptions; entries ending in a period (J., Dr., C.C.U.) now match; a comma is the short pause in running text, as with `--tokens`; a written uno is never cut to un; syllable breaks after a diphthong with a written accent (náufrago, máicro) and before a liquid and a glide (dinosaurio, bourbon); the -uir hiatus only in -uir verb forms (buitre, Luis, huincha, intuición); y as a vowel or glide beside a consonant (Lynn, whisky, Reynaldo); no syllable without a vowel; a colon is always the long pause, and so is a full stop after a number; `--tokens` honours `-lp2`; every output file except an `-mfa` dictionary is NFC; a number before a noun agrees with it in gender (una casa, veintiún años, doscientas personas); 12.30 is doce punto treinta; feminine and plural ordinals (1.ª and 1a primera, 3as terceras, 1er primer); `-nopi` symbols after a word and for commas; `-noclp` and `-noscp` work in running text.
- **2.0.34** (2026-10-30): in token mode an ellipsis token is the long pause, as in running text (it produced nothing, and the narrow rules ran across it).
- **2.0.33** (2026-10-30): built-in phrase readings (Guns N' Roses gansenróses, rock and roll rocanról); AC/DC read eisidísi.
- **2.0.32** (2026-10-30): narrow lenition of b, d and ɡ rewritten; velar palatalization before j; `-oa` no longer blocks narrow rules; `-phonword` honours output format, dots and stress options, and with `-wl` writes one line per input line; new `--tokens`; built-in pronunciation tables; stand-ins become pauses; pronounceable acronyms read as words; "mi" no longer spelled "eme i"; underscore as a separator; runs of three or more identical consonants collapse. Full list in the source's changelog.
- **2.0.31** (2026-07-31): `--mfa-rules` and `--mfa-phoneset` documented in `-h`.
- Earlier versions: see the changelog at the top of the source.

## Platform

Perl 5 with `Roman` and `Lingua::ES::Numeros`; Linux, macOS and Windows. Ready-built binaries are on the Releases page of https://github.com/Linguista/Perkins.
