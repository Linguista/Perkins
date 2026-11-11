# HOWTO — Perkins `--narrow` (Allophonic Transcription)

Sequential steps, numbered with gaps (10, 20, 30…) for later insertion.

---

> **Currency check (261111).** This document is current as of Perkins
> **v2.0.38**, which changed no narrow rule but changed what the rules see
> in two places: the period of an abbreviation (Sr., art., Bs. As.) is no
> longer a pause, and `-noelp` and `-nosnp` now delete an ellipsis or a
> sentence end, so the rules apply across them. It also rebuilt the word
> and syllable lists (§60). v2.0.36 and v2.0.37 changed no output.
> **v2.0.35** changed no narrow rule but changed what the rules see:
> a comma is now the short pause | in running text too (as with `--tokens`),
> so the rules no longer apply across it (la lluvia, bajo: ˈba.xo), and
> several words are syllabified differently (narrow, as printed in token
> mode: el náufrago el ˈnãw.fɾa.ɣ̞o, el buitre el ˈvwi.t̪ɾe, Luis lwis, una
> huincha ˈũ.nã ˈwĩn̪.t͡ʃa). A colon is the long pause ‖ in every mode (it
> was | with `--tokens` and after a number), and a full stop after a number
> is ‖ in running text (it was deleted, so eran 12. Bajamos gave ʋa.ˈxã.mõs).
> Every output file except an `-mfa` dictionary is now Unicode NFC: a nasal
> vowel is one character (ã), not the vowel plus U+0303.
>
> **v2.0.32** REWROTE the b, d and ɡ lenition rules: a stop
> after a pause, after a nasal, and d after l; otherwise the coda and an
> onset after a consonant get v, ð̞, ɣ, and an onset after a vowel or glide
> gets ʋ, ð̞, ɣ̞. Until v2.0.31 only an onset between two vowels lenited, so
> lluvia, agua, adiós, árbol, algo and padre kept their stops. v2.0.32 also
> palatalizes velars before the glide j, stops `-oa` from blocking the
> rules, and makes `-phonword` honour `-f=`, `-nosd` and the rest. The
> rule-by-rule detail is in `perkins-narrow-transcription-ruleset_README.md`.
>
> It is the authoritative source for `--narrow`.

## 10. What this covers and why

`--narrow` is a new Perkins flag that applies Chilean Spanish
categorical (non-free-variation) allophonic rules — b/d/g
spirantization, yeísmo affrication, velar palatalization before front
vowels, nasal place assimilation, vowel nasalization — on top of
whatever transcription mode you're already using. It exists to give
allophonic transcriptions, for example for a TextGrid tier of allophones,
and the phonetic features of each segment. It does
**not** implement free-variation phenomena (spirantization
fricative-vs-approximant quality, /d̪/-elision, /θ/-as-/s/) — those stay
with forced alignment and phone recognition (for example MFA's `rules.yaml`).

---

## 20. Placing the new Perkins version

Install Perkins as described in `perkins_README.md` (binaries and
packages) or `HOWTO--Perkins-compilation.md` (building it).

Confirm the version:

```
perkins -h 2>&1 | grep -m1 'Perkins v'
```

It must show `Perkins v2.0.38` (or later). 2.0.33 added built-in phrase readings; 2.0.34 made an ellipsis token a pause in token mode; 2.0.35 made the comma a pause in running text and fixed syllable breaks and the -uir hiatus; 2.0.36 and 2.0.37 changed no output; 2.0.38 rebuilt the lists and stopped the period of an abbreviation from being a pause. None of them changed a narrow rule. An older number means the binary was not
recompiled: editing the `.pl` alone does not change it.

---

## 30. Basic usage

```
perkins -i=input.txt -o=output.txt --narrow
```

Also settable permanently via `perkins.ini` (`narrow_transcription = 1`)
if you want it on by default for a given run configuration.

Worked example, using the full confirmed rule set at once (from the
ruleset README, verified against real output, not hand-written):

```
Input:  Desde que mi abuelo dijo adiós a su padre bajo la lluvia, quien
        tenga una deuda con la iglesia habla de algo del siglo pasado
        mientras toma caldo y agua junto al árbol.
Output (-nocfg -nosbu -nt, v2.0.35; the comma is the pause |):
        ˈd̪es.ð̞e cẽ mĩ a.ˈʋwe.lo ˈð̞i.xo a.ˈð̞jos a su ˈpa.ð̞ɾe ˈʋa.xo la
        ˈʝu.ʋja | cjẽn̪ ˈt̪ẽŋ.ɡa ˈũ.nã ˈð̞ew.ð̞a kõn la i.ˈɣ̞le.sja ˈa.ʋla ð̞e
        ˈal.ɣo ð̞el ˈsi.ɣ̞lo pa.ˈsa.ð̞õ ˈmjẽn̪.t̪ɾas ˈt̪õ.mã ˈkal.d̪o i
        ˈa.ɣ̞wa ˈxũn̪.t̪o al ˈaɾ.vol
```

---

## 40. The rule set itself

Full rule-by-rule documentation, with the exact regex for each rule,
worked examples, and the reasoning behind every design decision
(including the two symbol-collision issues resolved during design —
`ɣ̞→ʝ̞` not bare `j`, and why), lives in:

```
perkins-narrow-transcription-ruleset_README.md
```

Keep this file alongside `perkins.pl` — it's been kept in sync with
every version through 2.0.15 and documents fixes that aren't obvious
from the code alone (e.g. why `$aproximants` must be checked before
`$fricatives` in the manner-classification function specifically).

---

## 50. Combining `--narrow` with other output modes

Confirmed working correctly (phoneme-level verified, not just
structurally):

```
perkins -i=in.txt -o=out.MFA -mfa --mfa-wl --narrow      # one-word-per-line dictionary
perkins -i=in.txt -o=out.MFA -mfa --mfa-rt --narrow      # running-text dictionary
perkins -i=in.txt -o=out.PHONWORD -phonword --narrow
perkins -i=in.txt -o=out.COSCACH -coscach --narrow
perkins -i=in.txt -o=out.vrt -vrt --narrow                # word list, one word per line
perkins -i=in.txt -o=out.MANNER.txt -manner --narrow
perkins -i=in.txt -o=out.PLACE.txt -place --narrow
perkins -i=in.tok -o=out.tok -tok --narrow                # v2.0.32: TAB-separated tokens per sentence
```

Since v2.0.32, `-phonword` also honours `-f=MANNER`, `-f=PLACE`, `-nosd`
and `-st`, and with `-wl` writes exactly one line per input line.

**Blocked, by design, with a clear error:**
```
perkins -i=in.txt -o=out.CV.txt -cv --narrow        # ERRORS -- see below
perkins -i=in.txt -o=out.CVG.txt -cvg --narrow      # ERRORS
perkins -i=in.txt -o=out.CVNLRG.txt -cvn --narrow   # ERRORS
perkins -i=in.txt -o=out.VOICING.txt -voicing --narrow  # ERRORS
```
These four formats reduce every phoneme to one category letter, so
`--narrow`'s allophonic distinctions can never actually show up in the
output — combining them is now a hard error rather than silently
producing plausible-but-meaningless output.

**Important, mode-specific limitation (by design, not a bug):**
`-mfa`'s *running-text* mode (`--mfa-rt`) builds one independent,
reusable dictionary entry per word — there is no next-word context
available when building that entry, so cross-word rules (`nb→ɱv`,
cross-word spirantization/nasalization) cannot apply there. Only
rules that don't need cross-word context still take effect in that
specific mode. `-mfa`'s *one-word-per-line* mode (`--mfa-wl`) and
`-phonword` do not have this limitation.

---

---

## 55. `-mfa --narrow` DROPS entries — read before combining them

**Since Perkins v2.0.20, `-mfa` output may contain nothing outside the
acoustic model's phone inventory.** Format validity was not enough on its
own: an out-of-inventory phone parses perfectly and then fails to align,
silently. Entries carrying one are therefore **dropped and reported**,
never repaired.

**Rule 10 produces the dental nasal n̪ before t̪, d̪, t and d, and the
dental nasal is not in the inventory.** Every word with a nasal in that
context is discarded from the dictionary. Measured on a seven-word list:

```
  3 entries DROPPED for a phone outside the model's inventory:
      anda: "n̪" (U+006E + U+032A)
      canto: "n̪" (U+006E + U+032A)
      gente: "n̪" (U+006E + U+032A)
    These parse fine and then fail to align. If they look
    like --narrow symbols, --narrow is the wrong mode here;
    use --mfa-rules instead.
```

Plain `-mfa` on the same seven words drops nothing.

**What does NOT drop, contrary to the obvious guess:** rule 11's nasalised
vowels. In `-mfa` output they are DECOMPOSED — base vowel plus U+0303 — and
that is the form the inventory holds; only the precomposed single codepoints
need aliasing, and they are aliased. **Rule 11 is safe in `-mfa` mode; rule
10 is not.** This is why `-mfa` is the one output that v2.0.35 does not
write in NFC: every other mode composes the nasal vowels (ã), which MFA
would read as phones the model has never seen.

| you want | use |
|---|---|
| a dictionary for a PRETRAINED model | `-mfa --mfa-rules`, not `--narrow` — everything it emits is in the inventory by construction |
| a dictionary for this project's OWN Chilean model | plain `-mfa`; allophones come from the allophone table with its context and rank |
| narrow transcription for a TextGrid tier, analysis or reading | `--narrow` with any non-`-mfa` mode — nothing is dropped, the check applies to `-mfa` output only |
| `--narrow` inside `-mfa` anyway | supply an inventory containing the dental nasal via `--mfa-phoneset FILE` (v2.0.23) |

**This is not a bug in either flag.** `--narrow` describes Chilean speech,
and Chilean /n/ genuinely dentalises before a dental stop. The inventory
describes what an acoustic model was trained on. They answer different
questions, and v2.0.20 exists so the disagreement is loud rather than
silent.


## 60. Known limitations — read before relying on either of these

1. **Punctuation and pauses.** In running text and with `--tokens`,
   `.` `...` `!` `?` `:` `;` `—` `…` are the long pause ‖ (|| with
   `-lp2`) and a comma is the short pause |, after a word or a number.
   v2.0.35 made a comma a pause in running text (it was deleted, and
   the narrow rules ran across it), made a colon the long pause as a
   token and after a number (it was |), and made a full stop after a
   number the long pause in running text (it was deleted).

2. **The lists (`-owl`, `-vrt`, `-sas`).** The narrow rules run on
   the whole line, as in running text, and the list is cut from the
   result, so a word in a word list shows the allophones it has in
   its sentence (en Concepción gives ẽŋ, not en). A word list runs
   with every pause off, so the rules also apply across what were
   commas and full stops; a syllable list keeps the pauses until the
   list is cut. v2.0.38 rebuilt the lists this way: until then they
   came out on one line, and the join between input lines lost its
   space (the spacing problem noted here before), which no longer
   happens in any mode.
3. **The period of an abbreviation** (Sr., art., Bs. As.) is not a
   pause since v2.0.38, so the rules apply across it like any word
   boundary (el Sr. Pérez: se.ˈɲoɾ.ˈpe.ɾes, one phrase).

---

## 70. Re-running the stress-test suite (if you make further changes)

The 41-combination test harness used to stress-test `--narrow` was not
kept in the project. To re-run something like it after future changes,
the shape was:

- Every output mode (default, `-mfa --mfa-wl`, `-mfa --mfa-rt`,
  `-phonword`, `-vrt`, `-word-list`, `-syl-list`, `-coscach`, `-cv`,
  `-cvg`, `-cvn`, `-manner`, `-place`, `-voicing`) × with/without
  `--narrow` (28 combinations).
- Plus 13 additional combinations layering `--narrow` with: `-st`,
  `-nosbs`, `-nodd`, `-nomulti`, `-ya`, `-ar`, `-gd`, `-nsm`, `-tg`,
  `-oa`, `-ss`, `-pl2`, and a "kitchen sink" stack of several at once.
- Run against real Spanish prose (the Wikipedia article Historia de
  Chile, ~1,245 words, was used), not synthetic text
  alone, plus a short sentence specifically constructed to exercise
  every rule at once.
- Checks: exit code, output file size sanity, `grep` for Perl
  warnings/errors in stderr, UTF-8 validity, and — critically —
  phoneme-by-phoneme correctness against hand-traced expected output,
  not just "did it crash."

---

## 80. Still open / future work

- Not yet tested: `--narrow` combined with numbers/dates/currency/
  temperature expansion sitting immediately adjacent to a new
  utterance-boundary character; a full (non-spot-check) scan of
  manner/place output across an entire large corpus, rather than a
  curated rule-coverage word list.
- Eventually: use `--narrow`'s output for a TextGrid tier of allophones,
  together with a phone recognizer.
- Deliberately **not** a `--narrow` job, recorded here so it is not
  proposed again: Chilean CH/TR allophony. It is sociolinguistically,
  not phonologically, conditioned, so neither `--narrow` nor MFA's
  `rules.yaml` can express when each variant applies. It belongs to the
  phone recogniser, discovered from real audio. A proposal to use
  `--narrow` output as a categorical prior for phone-recogniser training
  was raised and retracted for the same reason.
