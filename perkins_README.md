# perkins_README.md

Documents Perkins 2.0.42, the Spanish phonological transcriber (Scott Sadowsky, GNU AGPL v3).

The source, the binaries for Linux, Windows and macOS and the Linux packages are at https://github.com/Linguista/Perkins, whose main page also shows every option with examples.

## Purpose

Perkins turns Spanish orthographic text into phonemic or narrow (allophonic) transcription, with syllabification and stress, or into category strings (CV, CVG, CVN, manner, place, voicing). It has modes for running text, lists of words or syllables (`-owl`, `-vrt`, `-sas`), Montreal Forced Aligner dictionaries, Praat word tiers (`-phonword`) and token-aligned output for FreeLing CoNLL files (`--tokens`).

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

A comma is the short pause |; a full stop, question mark, exclamation mark, colon, semicolon, ellipsis or dash is the long pause ‖ (|| with `-lp2`), after a word or a number, in running text and in token mode. The period of an abbreviation (Sr., Sra., art., Bs. As., no. 5) is not a pause, so the abbreviation is read in full. A pause blocks the narrow rules that apply across words: in "la lluvia, bajo el techo" bajo keeps its stop (ˈba.xo), while in "la lluvia bajo el techo" it is lenited (ˈʋa.xo). `-nocmp`, `-noclp`, `-noscp`, `-nosnp` and `-noelp` make the comma, colon, semicolon, sentence end and ellipsis no pause at all; `-mfa`, `-phonword` and the lists switch pauses off themselves. Each input line gives its own output line.

### Lists of words and syllables

`-owl` writes one transcribed word per line and `-sas` (`-osl`) one syllable per line, in the order of the text, with no pauses. Words are syllabified word by word. Syllables are cut from running text (del año gives d̪e, la, ɲo) or, with `-nosbu`, from each word (d̪el, a, ɲo), and carry no stress mark. `-vrt` is a word list with its own settings: stress as an accent on the vowel, one character per phoneme, a default output name ending in `.vrt`; with `-sas` it gives a syllable list.

### Numbers

A number before a noun agrees with it in gender: 1 perro un perro, 1 casa una casa, 21 años veintiún años, 21 horas veintiuna horas, 200 personas doscientas personas, 200 mil personas doscientas mil personas. The gender comes from the common nouns of the es-CL FreeLing dictionary that have a single gender, built into Perkins; a word that is not one of them (de, que, a verb) leaves the number alone (1 de cada 3 uno de cada tres). With the decimal comma, a number written with a point and not three digits after it is a decimal read with punto, one or two digits after the point as a number (12.30 doce punto treinta, 3.75 tres punto setenta y cinco); a time is written with a colon (12:30 doce treinta). Ordinals follow their suffix: 1.ª and 1a primera, 2os segundos, 3as terceras, 1er primer, 3er tercer.

### Unicode

Every output file is NFC, so a nasal vowel is one character (ã ẽ ĩ õ ũ); a diacritic with no precomposed form stays a combining mark (d̪, ɣ̞, n̪), which is already NFC. The one exception is `-mfa`: an MFA dictionary spells every phone exactly as the acoustic model does, and the models in use spell the nasal vowels as the vowel plus U+0303, so `-mfa` keeps them that way.

The input is read as NFC (since 2.0.42): an accent written as a separate combining character (a + U+0301) is joined to its vowel before any rule runs, because every rule expects the precomposed letter. Decomposed triángulo, canción and piña were t̪ɾján.ˈɡu.lo, kan.ˈsjón and piña; they are now ˈt̪ɾjan.ɡu.lo, kan.ˈsjon and ˈpi.ɲa, as their NFC spelling gives. Text already in NFC, the COSCACH and CODICACH texts among it, is unchanged. `-nonfc`, or `normalize_nfc_input = 0` in `perkins.ini`, turns it off; `-mfa` never normalizes its input, so its dictionary headwords stay exactly as written. A replacement character (U+FFFD) is a character lost before the text reached Perkins: NFC cannot restore it, and inside a word it does not make the rest a new word (the Mapudungun ng rule leaves "�ngeles" alone).

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

### `-phonword`

One word per line: the word as written, with its capital letters and accents, a TAB, and its transcription with syllables and stress.

With `-wl`, exactly one output line per input line: the input line verbatim, a TAB, and the transcription of everything that line produced (14 gives catorce; a multiword gives its words joined by a space). `-phonword` honours `-f=`, `-nosd`, `-ss`, `-nsm` and `-st`.

## Built-in pronunciations

Perkins carries its special readings in the program itself, in four tables applied to whole tokens before any other processing. They work in every mode. To add an entry, edit the table in the source and recompile.

| Table | Matched | Holds |
|---|---|---|
| `%BUILTIN_RESPELL` | exact case | acronyms and codes read as letters (PDI as pedeí, B-32 as betreintaidós) and other overrides, from the COSCACH inventory |
| `%BUILTIN_IPA` | exact case, then lowercase | fixed phonemic transcriptions: backchannels and fillers (mmhm as m̩.ˈhm̩, mmm as m̩ː, nn as n̩ː), four of them also by their shape (see below), and three names: aylwin ˈejl.win, revenge re.ˈbenʝ, selj selʝ |
| `%BUILTIN_RESPELL_ANYCASE` | lowercase, after the two above | 2,655 respellings of the COSCACH spelling review |
| `@BUILTIN_PHRASES` | a pattern, without regard to case | multiword names read as one Spanish word |

A respelling is an ordinary Spanish spelling that Perkins then transcribes: a written accent marks the stressed letter, a space keeps two letters out of a diphthong, and an empty respelling removes the token.

How the tables meet:

- The exact-case table is looked up first, so a word in capitals that is another word keeps its own reading: AND is aenedé while and is an, UP is upé while up is ap, WoW (the game) is wow while wow is waw, RR is erreérre while rr stays the backchannel r̩ (before an ellipsis it is a false start, r; see below).
- Letters respelled as separate letter names are joined, with the stress on the last letter, as an acronym is said: psu (pe ese u) is peeseú, pe.e.se.ˈu. A space stays where two vowels would make a diphthong (u ese bé) or three identical vowels would meet.
- An entry that ends in a period (J., Dr., C.C.U.) is looked up with its period, before anything else, so Dr. is doctor, while Dr without the period stays the backchannel dɾ̩.
- mm is deliberately absent everywhere: filler or millimetres is a judgement call, so it keeps Perkins' ordinary handling (which reads it m̩ː).
- Four interjections are also read by their shape, in any case, whatever the spelling: every run of three or more m (mmm, mmmmm, mmmmmmm) is m̩ː; h then m (hm, Hm, hmmm) hm̩ː; m then h or j then m (mhm, mhmm, mmhmm, mmmhm, mjm, mm-hm) m̩.ˈhm̩; s then h (sh, shh, shhh, ssh, SH) ʃ̩ː, with F, T and A in manner, place and voicing.
- With the stress written as an accent (`-st`, `-csc`), a stressed syllable without a vowel takes the accent on its syllabic consonant: mmhm is m̩ hḿ̩ with `-csc`.

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
- A false start, a token without a vowel right before an ellipsis, in running text or as the token before an ellipsis token, is a word cut off and is read as its sounds: "no s ... no logró" is no s ‖ no lo.ˈɡɾo, "de ch ..." d̪e t͡ʃ ‖, pr ... pɾ, cl... kl. c and q are k, g ɡ, j x, v b, z s, x ks, ll ʝ, h nothing; r is the trill at the start and after l, n or s, the tap after another consonant. Not a false start: two or more capitals (PS ... and LGB ... stay spelled) and the interjections, which keep their reading before an ellipsis (mmm ..., nn ..., sh ..., pf ...). Without an ellipsis after it, a lone letter is still its name (la s is la ˈe.se).
- The underscore separates words; it is read aloud only inside URLs and e-mail addresses.
- A written uno is never cut to un (uno nunca sabe, me quedé con uno solo). Only a number written in digits is: before a unit or a currency (1 km un kilómetro, $1 un peso) and before a masculine noun, with which it agrees (1 perro un perro; see Numbers).
- The -uir verbs keep u and i apart with the stress on i (huir u.ˈiɾ, construir kons.tɾu.ˈiɾ, incluido in.klu.ˈi.do); every other ui is a diphthong (buitre ˈbwi.tɾe, Luis lwis, intuición in.twi.ˈsjon, huincha ˈwin.ʧa).
- The letter y is the vowel i when no vowel is next to it (Lynn, sexy, whisky, nylon) and the glide between a vowel and a consonant (Reynaldo rej.ˈnal.do); before a vowel it is the consonant ʝ (yo, playa).

## Installing

Ready-built binaries and packages are attached to each release on the Releases page of https://github.com/Linguista/Perkins:

| File | For | Install with |
|---|---|---|
| `perkins_2.0.42-1_amd64.deb` | Debian, Ubuntu and their derivatives | `sudo apt install ./perkins_2.0.42-1_amd64.deb` |
| `perkins-2.0.42-1.x86_64.rpm` | Fedora | `sudo dnf install ./perkins-2.0.42-1.x86_64.rpm` |
| `perkins-2.0.42-1-x86_64.pkg.tar.zst` | Arch Linux | `sudo pacman -U perkins-2.0.42-1-x86_64.pkg.tar.zst` |
| `perkins_2.0.42-1_arm64.deb` | Debian, Ubuntu and Raspberry Pi OS on ARM processors (64-bit) | `sudo apt install ./perkins_2.0.42-1_arm64.deb` |
| `perkins-2.0.42-1.aarch64.rpm` | Fedora on ARM processors | `sudo dnf install ./perkins-2.0.42-1.aarch64.rpm` |
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

It must print `Perkins v2.0.42`.

## Checking a build

`tests/` holds the test sentence approved on 261030 with its expected phonemic and narrow output, a token file with its expected output for each of the seven CoNLL columns, the phrase readings, an ellipsis token, and the cases of commas, uno, diphthongs, ui, the any-case table, the colon and the full stop after a number as long pauses, NFC output, the word and syllable lists, abbreviations, `-noelp` and `-nosnp`, the syllabic nasal of mm and hmm in narrow transcription and in the manner, place and voicing categories, decimals and thousands before a full stop or a comma, the interjections by their shape, and false starts. In the folder holding `tests/`, check the binary on the PATH:

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

- **2.0.42** (2026-11-12): the input is normalized to Unicode NFC before anything else, so an accent written as a separate combining character is read as part of its vowel (decomposed triángulo ˈt̪ɾjan.ɡu.lo, canción kan.ˈsjon, piña ˈpi.ɲa; they were t̪ɾján.ˈɡu.lo, kan.ˈsjón, piña); on by default, `-nonfc` or `normalize_nfc_input = 0` turns it off, and `-mfa` never does it. A replacement character (U+FFFD) inside a word no longer makes the ng after it word-initial for the Mapudungun rule of 2.0.41 (�ngeles kept its n). 68 tests.
- **2.0.41** (2026-11-12): ts is the affricate t͡s, one phoneme (tsunami t͡su.ˈna.mi; it was t̪.su.ˈna.mi), with its categories in every mode (ʦ in the single-character modes, ts with `-csc`); ü is u everywhere but in güe and güi (küni ˈku.ni, kütral ku.ˈt̪ɾal; they were k.wni, k.wt̪ɾal); a Mapudungun ng at the start of a word, before a vowel, is g, gu before e and i (ngenechén ɡe.ne.ˈt͡ʃen, nguillatún ɡi.ʝa.ˈt̪un), and ng inside a word is never touched; new built-in readings (Bryan ˈbɾa.ʝan, Ryan ˈra.ʝan, Schlyer ˈt͡ʃlaj.eɾ, Django ˈʝan.ɡo, nocauts no.ˈkawts, APK a.pe.ˈka, CPU se.pe.ˈu, glüh, nürr, pürrüm and eight Mapudungun words); grr is ɡr̩ː (long), brr br̩ː, brbrbr br̩.br̩.br̩, and brr and brbrbr keep their reading before an ellipsis; the ch of a built-in reading (fch, tsh, pch) is written as every other ch (t͡ʃ, tʃ with `-csc`; it was always ʧ); a grave ù is fixed to ú. 65 tests.
- **2.0.40** (2026-11-11): a false start (a token without a vowel right before an ellipsis) is read as its sounds: s ... is s, pr ... pɾ, ch ... t͡ʃ (it was read as letter names: s ˈe.se, pr pe.ˈe.re, cl se ˈe.le); mmm, hmm, mmhm and sh are recognized by their shape in any spelling and case (mmmmm was mmm, hmmm mm, mhm mm, mjm mxm, shh t͡ʃ, SH the letters); ʃ (sh, ch) has its categories, F, T and A (it was written Ʃ); with an accent for stress, the stressed syllabic m of mmhm takes the accent (m̩ hḿ̩; it kept ˈ).
- **2.0.39** (2026-11-11): `-f=PLACE` writes a vowel by its place, in lower case: f front (i, e), c central (a), b back (o, u) (it was -); with `--narrow`, b, d and ɡ keep their stop after the syllabic nasal of mm, mmm and hmm (mm bueno m̩ː ˈbwẽ.nõ; they were lenited); the h of hmm and mmhm is F in manner, G (glottal) in place, A in voicing and C in the CV categories (it was written as H); in running text a decimal or a number with thousands separators before a full stop or a comma is read whole (3,5. gave an internal placeholder, 3,5, lost its comma, 1.500. was uno quinientos, 2.000, dos cero).
- **2.0.38** (2026-11-11): `-owl`, `-sas` and the new `-osl` and `-usl` write one word or syllable per line, without pauses (they wrote one line, words run together); syllable lists cut from running text or, with `-nosbu`, from each word; `-vrt` is a word list with its own settings, through the ordinary pipeline (its old pipeline for Connexor VRT files gave kon.sep.si.ón), and an input ending in .vrt no longer selects it; every input line keeps its own output line (with `-noppp` they were glued together); `-noelp` and `-nosnp` work; the period of an abbreviation is not a sentence end (Sr. Pérez was esr ‖ ˈpe.ɾes); `-f=PLACE` writes a vowel as -, not V; `-phonword` keeps capital letters and writes no line for a full stop; the output file may not be the input file; `perkins -u` shows real output, with the voicing key corrected (S voiced, A voiceless).
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
