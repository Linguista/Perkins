# Perkins `--narrow` — Chilean Spanish Narrow-Transcription Ruleset

> **A note on the `-mfa` spelling.** In v2.0.17 the flag `-g2p` was renamed
> `-mfa`, `--g2p-wl`/`--g2p-rt` became `--mfa-wl`/`--mfa-rt`, the
> `perkins.ini` key `g2p_format` became `mfa_format`, and the default output
> extension changed from `.G2P` to `.MFA`. The old spellings are now a **hard
> error (exit 2)** naming the replacement, not a silent alias. This document
> uses the current names throughout, **including in the sections describing
> work done before the rename** — the flag was called `-g2p` at the time, and
> saying so in every historical paragraph would make none of them runnable.

## Purpose

`--narrow` (alias `-nt`) applies a set of **phonologically-conditioned**
narrow-transcription rules for Chilean Spanish on top of whatever
phonemic output Perkins' current transcription mode already produces.
It is a standalone flag, independent of output mode — it works the same
way whether combined with `-mfa`, plain running-text phonemic
transcription, `-phonword`, `-vrt`, or any other mode.

The ruleset covers **only** phenomena that are fully determined by
phonological context — give the rule the same sound in the same
environment, and it always produces the same answer, with no reference
to audio required. This is a deliberate, principled boundary:

- **Categorical, rule-based phenomena** (this document) — implemented
  directly in Perkins via `--narrow`, since text alone determines the
  outcome.
- **Free-variation phenomena** (fricative-vs-approximant spirantization
  quality, /d̪/-elision, /θ/ as a sociolinguistic allophone of /s/) —
  deliberately **excluded** from `--narrow`. These cannot be determined
  from text; they require either an MFA `rules.yaml` optional-
  pronunciation entry (letting the forced aligner pick whichever
  candidate the real audio supports) or a separate phone recognizer
  fine-tuned for allophone identification. See "What's deliberately NOT
  here" below.

## Usage

```
perkins -i=input.txt -o=output.txt --narrow
perkins -i=input.txt -o=output.MFA -mfa -nt
```

Can be combined with any other flag or metaconfiguration. Also settable
via `perkins.ini` (`narrow_transcription = 1`).

> **The second example is lossy.** Since v2.0.20, `-mfa --narrow` DROPS every
> entry containing the dental nasal that rule 10 produces — in a seven-word
> test, three of them. See *v2.0.20 — `-mfa --narrow` DROPS entries containing
> the dental nasal* below before using this combination for a dictionary.

## Where it runs in the pipeline

`narrow_transcription()` is called during the output-file cleanup
pass, right after `word_level_syllab_adjust()` (the existing cross-word
resyllabification routine) and independently of
`$syllabify_by_sentence` — it runs whether or not sentence-level
syllabification is on.

**This matters for how the rules are written.** By the time
`--narrow` runs, per-word stress-marking and (if active) cross-word
resyllabification have already happened — so the string it receives
already has syllable dots (`.`) and stress marks (`ˈ`/`ˌ`) sitting
between phonemes, not just plain word-boundary spaces. Every rule below
uses a general separator class —

```perl
my $SEP = "[. ˈˌ'\x01]*";
```

— matching any combination of dot/space/stress-mark (zero or more)
between two phonemes, rather than a bare optional space. This was
**not** the original design — the first implementation assumed plain
spaces only, and testing against real Perkins output (not just a
synthetic string) is what surfaced the gap. A real pause (`|`/`‖`)
still blocks every rule, since a pause character sitting between two
segments simply isn't part of the separator class and breaks the
match — no separate boundary-detection logic is needed.

**Since v2.0.32 the class also contains the plain apostrophe `'`**, the
stress mark written by `-oa`. Before that, every rule stopped at a
stressed syllable when `-oa` was on (trabajo stayed `tɾa.'ba.xo`).

## The rules, in order

Rule order matters throughout: several rules are stated as exceptions
to, or depend on the output of, earlier ones.

### 1. `nb` → `ɱv` (atomic)

```perl
$s =~ s/n($SEP)b/ɱ$1v/g;
```

Runs **first**, before generic `b`-spirantization (rule 2) — it is an
*exception* to the general pattern, not a consequence of it. The
labiodental nasal `ɱ` here reflects the nasal assimilating to `b`'s own
already-spirantizing surface place (labiodental), not to `b`'s
underlying bilabial place. Crosses a word boundary (e.g. "un beso" →
`ũɱ.ˈve.so`), but not a pause.

Confirmed this is **Chilean-specific**, not standard descriptive
Spanish phonology, which would normally have `b` surface as a stop
after any nasal (nasal-triggered *blocking* of spirantization). This
was checked and confirmed directly, twice, since it's the kind of
assumption that's been wrong before.

### 2 to 4. Lenition of `b`, `d̪` and `ɡ` (rewritten in v2.0.32)

A stop after a pause or at the start of the string, after a nasal, and
for `d̪` also after `l`. A continuant everywhere else:

| Position | `b` | `d̪` | `ɡ` | Examples |
|---|---|---|---|---|
| after a pause, or at the start | `b` | `d̪` | `ɡ` | Desde `ˈd̪es…` |
| after a nasal, also the syllabic nasal of mm and hmm | `b` | `d̪` | `ɡ` | tenga `ˈt̪ẽŋ.ɡa`, mm bueno m̩ː ˈbwẽ.nõ (and rule 1: un beso `ũɱ.ˈve.so`) |
| `d̪` after `l` | | `d̪` | | caldo `ˈkal.d̪o` |
| coda (before a syllable or word boundary) | `v` | `ð̞` | `ɣ` | club, absoluto |
| onset after a vowel or a glide | `ʋ` | `ð̞` | `ɣ̞` | lluvia `ˈʝu.ʋja`, agua `ˈa.ɣ̞wa`, padre `ˈpa.ð̞ɾe`, siglo `ˈsi.ɣ̞lo`, deuda `ˈð̞ew.ð̞a` |
| onset after any other consonant | `v` | `ð̞` | `ɣ` | árbol `ˈaɾ.vol`, algo `ˈal.ɣo`, desde `ˈd̪es.ð̞e` |

```perl
my $VOC = "$V|j|w";
# 2. coda
$s =~ s/b(?=[ .|‖]|$)/v/g;
$s =~ s/ɡ(?=[ .|‖]|$)/ɣ/g;
$s =~ s/(?<!l)(?<!l )(?<!l\.)(?:d̪|d)(?=[ .|‖]|$)/ð̞/g;
# 3. onset after a vowel or a glide
$s =~ s/($VOC)($SEP)b/$1$2ʋ/g;
$s =~ s/($VOC)($SEP)(?:d̪|d)/$1$2ð̞/g;
$s =~ s/($VOC)($SEP)ɡ/$1$2ɣ̞/g;
# 4. onset after any other consonant (a nasal, and l before d, keep the stop)
$s =~ s{((?![. ˈˌ'\x01|‖])\Xː?)($SEP)(d̪|d|b|ɡ)}{ _narrow_after_consonant($1, $2, $3) }ge;
```

All three steps cross word boundaries and none crosses a pause.

**v2.0.39.** In step 4 a length mark (ː) belongs to the segment before it.
The backchannels mm and mmm are the syllabic nasal m̩ː (hmm is hm̩ː), and
the length mark, a character of its own, was the "consonant" step 4 saw before the
next word, so b, d and ɡ after them lenited as after any non-nasal
consonant: mm bueno m̩ː ˈvwẽ.nõ, mmm dale m̩ː ˈð̞a.lẽ, mm gracias
m̩ː ˈɣɾa.sjas. Now the nasal is seen and the stop stays: m̩ː ˈbwẽ.nõ,
m̩ː ˈd̪a.lẽ, m̩ː ˈɡɾa.sjas. A vowel after m̩ː is not nasalized (rule 11
needs the nasal right before the vowel, and that is kept).

**What changed, and why.** Until v2.0.31 these were rules 2 to 7, and
an onset `b`, `d̪` or `ɡ` lenited only BETWEEN TWO VOWELS, with the
glides `j` and `w` excluded from the vowel class. This file described
"lluvia" → `bja` as correct. It was not: `b`, `d̪` and `ɡ` stayed stops
next to every glide (lluvia, abuelo, agua, adiós, deuda), after every
non-nasal consonant (árbol, algo, desde) and before every consonant
(padre, habla, siglo, iglesia). This was ruled an error in narrow
transcription on 261030, and the table above was approved by checking
the test sentence in "Verification" below. Phonemic output is unaffected.

The choices carried over from v2.0.31 rather than made new: `d̪`
lenites to the lowered `ð̞` everywhere, and the plain fricatives `v`
and `ɣ` appear only in the coda and after a consonant.

### 8. Yeísmo: `ɟʝ` → `dʒ` utterance-initially, `ʝ` everywhere else

```perl
$s =~ s/(^|‖|\|)($SEP)ɟʝ/$1$2dʒ/g;
$s =~ s/ɟʝ/ʝ/g;
```

"Utterance-initial" means the very start of the string, or immediately
after a pause marker (`|`/`‖`) — matching the fact that this is a
positional-strengthening pattern (affrication of `/ʝ/` at a genuine
utterance boundary), not sociolinguistic free variation, which is why
it qualifies for `--narrow` at all. The second substitution catches
whatever's left — i.e., every non-utterance-initial occurrence — and
downgrades it to the plain fricative.

### 9. Velar palatalization before /i/ or /e/ (v2.0.12)

```perl
my $FRONT_V = "i|e|í|é|j";
$s =~ s/k(?=$SEP(?:$FRONT_V))/c/g;
$s =~ s/x(?=$SEP(?:$FRONT_V))/ç/g;
$s =~ s/ɡ(?=$SEP(?:$FRONT_V))/ɟ/g;
$s =~ s/ɣ(?=$SEP(?:$FRONT_V))/ʝ/g;
$s =~ s/ɣ̞(?=$SEP(?:$FRONT_V))/ʝ̞/g;
```

**Since v2.0.32 the glide `j` is a front context too** (quien
`cjẽn`, colegios `ko.ˈle.çjos`).

Runs **after** spirantization (rules 2–4), so it correctly sees
whichever surface form those rules already produced for `/ɡ/`
specifically: `ɟ` only catches a `ɡ` that's *still a stop* (utterance-
initial or after a nasal) — an intervocalic or word-final `ɡ` before a
front vowel has already become `ɣ̞` or `ɣ` by the time this rule runs,
which is why this rule also separately covers `ɣ`→`ʝ` and `ɣ̞`→`ʝ̞`, not
just `ɡ`→`ɟ`. Runs **before** nasal place assimilation (renumbered rule
10, below), so a nasal preceding a newly-palatalized consonant
correctly assimilates to palatal place, not the velar place the
consonant no longer has by the time rule 10 would otherwise see it.

**`ɣ̞`→`ʝ̞`, not a bare `j` glide, deliberately.** A bare `j` was briefly
considered and rejected during design, specifically because Perkins
already uses plain `j` as its default representation for the ordinary
rising-diphthong glide `/j/` (e.g. "unión", "hielo") — completely
unrelated to this rule. Had this stayed as `j`, rule 10's expanded
palatal list (below) would have also wrongly triggered nasal
palatalization before every ordinary glide `j` already in the
language, not just the newly-palatalized velar-derived one. Using the
distinct `ʝ̞` (`ʝ` plus the same lowering diacritic already used in
`ɣ̞`) avoids this collision entirely.

Verified directly, individually and in combination: "queso" → `ce.so`
(`k`→`c`); "kilo" → `ci.lo`; "jinete" → `çi.ne.t̪e` (`x`→`ç`, with
correct incidental vowel nasalization from the following `/n/`); "un
guiso" → `uɲɟi.so` (`ɡ`→`ɟ` in blocked/stop context, plus rule 10's
nasal palatalization below); "seguir" → `se.ʝ̞iɾ` and "aguila" →
`a.ʝ̞i.la` (intervocalic `ɡ`→`ɣ̞`→`ʝ̞`); "tengo" → `t̪ẽŋ.ɡo` (`ɡ`
correctly *not* palatalized before "o", a non-front vowel).

### 10. Nasal place assimilation (`/n/` only — `/m/` never changes on its own)

> **Caution in `-mfa` mode.** The dental n̪ this rule produces before t̪, d̪, t
> and d is outside the acoustic model's phone inventory, so since v2.0.20 any
> `-mfa` entry containing one is dropped and reported. See the v2.0.20 section
> below. The other outputs of this rule — m, ɱ, ɲ, ŋ — are all in the
> inventory and are unaffected.

```perl
$s =~ s/n($SEP)(tʃ|ʝ|ɟʝ|ɲ|c|ç|ɟ)/ɲ$1$2/g;   # palatal -- MUST run before the dental rule below
$s =~ s/n($SEP)p/m$1p/g;
$s =~ s/n($SEP)f/ɱ$1f/g;
$s =~ s/n($SEP)(t̪|d̪|t|d)/n̪$1$2/g;
$s =~ s/n($SEP)(k|ɡ|x)/ŋ$1$2/g;
# n before s/l/ɾ/r -> n, i.e. no actual change: nothing to do.
```

Full correspondence table:

| Following consonant | `/n/` → | Consonant itself |
|---|---|---|
| `p` | `m` | unchanged |
| `b` | `ɱ` | → `v` (rule 1's special atomic case, handled there, not here) |
| `f` | `ɱ` | unchanged |
| `t̪`, `d̪`, `t`, `d` | `n̪` | unchanged |
| `s`, `l`, `ɾ`, `r` | `n` | unchanged (no real change) |
| `tʃ`, `ʝ`, `ɟʝ`, `ɲ`, `c`, `ç`, `ɟ` | `ɲ` | unchanged |
| `k`, `ɡ`, `x` | `ŋ` | unchanged (and `ɡ` here stays a stop: after a nasal, rules 2 to 4 keep the stop) |

**v2.0.12: expanded to include the new palatalized velars** (`c`, `ç`,
`ɟ`) alongside the original `tʃ`/`ʝ`/`ɟʝ`/`ɲ` set — note `j`/`ʝ̞` are
*not* in this list (see rule 9's collision note above for why `ʝ̞` was
chosen specifically to avoid needing to add anything here at all: the
existing bare `ʝ` alternative already matches `ʝ̞`'s leading character,
since the substitution only consumes `n`+separator and leaves the
matched consonant capture group untouched, diacritic and all).
Verified directly: "un guiso" → `uɲɟi.so` (`/n/`→`ɲ` before the newly-
palatalized `ɟ`, not the `ŋ` it would otherwise get before a plain
velar); "unión" → `ũ.njõn` (ordinary glide `j`, unaffected — confirming
the collision described in rule 9 is genuinely avoided, not just
theoretically).

**Real ordering bug found and fixed during testing**: the palatal rule
(`tʃ`/`ʝ`/`ɟʝ`/`ɲ`) must run *before* the dental rule (`t̪`/`d̪`/`t`/`d`).
`tʃ` starts with a literal `t`, so if the dental rule ran first, its
bare `t` alternative would greedily consume the `t` of `tʃ`, and the
palatal rule would never get a chance to see the full digraph. Caught
directly: `"un chico"` was producing `ũn̪ tʃiko` (wrong — dental)
instead of the correct `ũɲ tʃiko` (palatal), traced to exactly this,
and fixed by reordering.

`/m/` is deliberately excluded from all of this — it never changes on
its own before any following consonant (only the atomic `nb`→`ɱv`
exception in rule 1 touches it, and that's really about `/n/`
assimilating to match `b`'s own surface place, with the two segments
treated as one unit).

### 11. Vowel nasalization

```perl
$s =~ s/($N)($SEP)($V)(?!\x{0303})/$1$2$3\x{0303}/g;
$s =~ s/($V)(?!\x{0303})($SEP)($N)/$1\x{0303}$2$3/g;
```

Any vowel in **direct, immediate, one-segment** contact with a nasal —
before or after, crossing a word boundary but never a pause — gets a
combining tilde (U+0303). "One segment, no intervening segments
allowed, ever" — this is strictly V-N/N-V adjacency, never V-C-N or
similar.

The rule writes the vowel and U+0303 as two characters, and every later
rule works on that form. Since v2.0.35 the finished output file is
Unicode NFC, which joins them into one character for the five plain
vowels (ã ẽ ĩ õ ũ); an accented vowel with the tilde (`-st`, á̃) has no
single character and stays two. `-mfa` output is the exception and keeps
the vowel and U+0303, because that is how the acoustic model spells the
phone (see the v2.0.20 section).

Uses the nasal's **surface** form (`m|ɱ|n̪|ɲ|ŋ|n`) — i.e., *after* rule
9's place assimilation has already run, not the underlying `/n/`/`/m/`
phoneme. Confirmed directly: nasalization is sensitive to whatever the
nasal actually surfaces as, not its underlying identity.

**Idempotency**: each pass's negative lookahead (`(?!\x{0303})`)
prevents ever adding a *second* tilde to a vowel that the *other* pass
already nasalized — this matters for a vowel sitting directly between
two nasals (e.g. "nan" → `nãn`, not a malformed double-tilde). Tested
explicitly and confirmed correct.

**Stress-mark interaction**: since stress in most output modes is
marked at the syllable boundary (before the onset), not stacked onto
the vowel itself, there's normally no conflict between the stress mark
and the nasalization tilde. In modes where stress *is* shown as a tilde
over the vowel (`-st`), the nasalization tilde is added to the same,
already-accented vowel (e.g. `á` → `á̃`) — there is no dedicated
handling needed beyond what the general separator class and the
existing accented-vowel entries in `$V` already provide.

## What's deliberately NOT here

Three phenomena were identified during the design discussion and
explicitly excluded from `--narrow`, each for a different, specific
reason:

- **Fricative-vs-approximant spirantization quality** (whether a
  lenited `b`/`d̪`/`ɡ` surfaces as a fricative or an approximant) — this
  is free variation, not predictable from context even in principle.
  Left to a phone recognizer, for a tier of allophones.
- **`d̪`-elision** (`-ado`/`-ido`, word-final) — explicitly described as
  "may be elided," i.e. optional, not categorical. This is exactly the
  kind of thing MFA's `rules.yaml` is built for: offering multiple
  candidate pronunciations and letting the forced aligner pick whichever
  one the actual audio supports for that specific utterance, rather than
  Perkins guessing at a single answer from text alone.
- **`/θ/` as a sociolinguistic allophone of `/s/`** — some Chilean
  speakers have this variably; it's sociolinguistically, not
  phonologically, conditioned. Perkins never generates it. It's noted
  here only as a **whitelist reminder**: if the phone recognizer's own
  output includes `/θ/`, don't discard it as noise.

## Verification

**v2.0.37.** The test sentence approved on 261030, run with
`-nocfg -nosbu -nt` and matching the expected line character for
character:

```
Desde que mi abuelo dijo adiós a su padre bajo la lluvia, quien tenga
una deuda con la iglesia habla de algo del siglo pasado mientras toma
caldo y agua junto al árbol.

ˈd̪es.ð̞e cẽ mĩ a.ˈʋwe.lo ˈð̞i.xo a.ˈð̞jos a su ˈpa.ð̞ɾe ˈʋa.xo la
ˈʝu.ʋja | cjẽn̪ ˈt̪ẽŋ.ɡa ˈũ.nã ˈð̞ew.ð̞a kõn la i.ˈɣ̞le.sja ˈa.ʋla ð̞e
ˈal.ɣo ð̞el ˈsi.ɣ̞lo pa.ˈsa.ð̞õ ˈmjẽn̪.t̪ɾas ˈt̪õ.mã ˈkal.d̪o i
ˈa.ɣ̞wa ˈxũn̪.t̪o al ˈaɾ.vol
```

The comma is the short pause | (since v2.0.35; until v2.0.34 it was
deleted in running text and the rules applied across it). Here the word
after it, quien, begins with k, which no rule changes after a pause or a
vowel, so only the pause symbol differs from the line approved on 261030.
The nasal vowels are single characters, since v2.0.35 writes NFC; until
v2.0.34 each was the vowel and U+0303.

**Earlier versions:**

Every rule was tested individually and in combination, first against a
standalone Perl harness, then — after finding that the harness's plain-
space assumption didn't match real Perkins output — against the actual
compiled pipeline, using real Perkins output as input rather than
hand-constructed strings. Confirmed cases include:

- `"un beso"` → `ũɱ.ˈve.so` (rule 1 + rule 11)
- `"la bota"` → `la.ˈʋo.t̪a` (rule 3, crossing a word boundary)
- `"el chico anda"` → `el.ˈt͡ʃi.ko.ˈãn̪.d̪a` (rule 10's palatal-before-dental
  ordering fix; `d̪` in "anda" correctly stays a stop since it's not
  intervocalic)
- A pause marker correctly blocks rule 1 from crossing it (confirmed
  with a real `‖` present in the string)
- The full standard usage-guide sentence ("En Concepción, se trata de
  aguantar la lluvia durante 5 meses del año. ¿Cachái?") → `ẽŋ.kõn.sep.
  ˈsjõn.se.ˈt̪ɾa.t̪a.ð̞e.a.ɡwãn̪.ˈt̪aɾ.la.ˈʝu.bja.ð̞u.ˈɾãn̪.t̪e.ˈsĩŋ.kõ.ˈmẽ.
  ses.d̪e.ˈlã.ɲõ.ka.ˈt͡ʃaj` — exercising nearly every rule at once,
  including the "after a consonant, no change" case (`"del"` → `d̪e`,
  since the preceding `s` in `"meses"` isn't a vowel) and nasalization
  from all three surface nasal places (`ŋ`, `n̪`, `ɲ`) in the same
  sentence.

## Pauses from punctuation (formerly an open item)

Whether ordinary punctuation reliably produces a pause marker was once
an open question. It is settled: since v2.0.13 a full stop, question or
exclamation mark, colon, semicolon, ellipsis or dash after a word is the
long pause ‖ in running text, and since v2.0.35 a comma is the short
pause |, a colon is ‖ with `--tokens` and after a number too, and a full
stop after a number is ‖ in running text. `tests/pauses.txt` and
`tests/pauses.tok` check it.

## `-mfa`/`-phonword` interaction — a real bug found and fixed (v2.0.11)

`-mfa` and `-phonword` both write their "already in final form" output
directly during the first processing pass and then `exit` before the
Stage-2 cleanup pass — which is where `narrow_transcription()` normally
runs. **`--narrow` silently had no effect at all when combined with
either mode** until this was found and fixed directly.

Fixing this surfaced two further, genuinely separate problems, each
found by testing the fix rather than assumed correct:

1. **Cross-word rules need the whole line, not one word at a time.**
   Applying `narrow_transcription()` to each word's phoneme string
   separately, before joining, meant a cross-word rule like `nb → ɱv`
   could never see the boundary between two words — confirmed directly
   ("un beso" produced two independently-narrowed fragments, never the
   correct combined result). Fixed for `-mfa`'s one-word-per-line mode
   by deferring `narrow_transcription()` until *after* a line's words
   are joined with real spaces, mirroring how the Stage-2 pass already
   works.

   **`-mfa`'s running-text mode is a genuine, permanent exception, not
   a further bug**: each word there becomes its own independent,
   reusable dictionary entry, with no next-word context available at
   all when the entry is built — so cross-word rules (rule 1's `nb`,
   and cross-word spirantization/nasalization) simply cannot apply in
   this mode, by design. Only the rules that don't need cross-word
   context still take effect there.

2. **`-mfa`'s own output convention conflicts with the rules'
   separator assumptions.** When `$space_between_phonemes` is on
   (`-mfa`'s default), it puts a literal space between *every* phoneme,
   not just between words — indistinguishable, to the rules' own
   separator class, from a genuine word-boundary space. Confirmed
   directly: an isolated word, `"beso"` (phonemes `"b e s o"`), had its
   word-*initial* `b` wrongly treated as word-*final* and turned into
   `v`, since rule 3's word-final pattern matches `b` followed by any
   space, and `-mfa`'s own spacing put one right there. Fixed with a
   `\x01` placeholder: each word's internal `-mfa` phoneme-spacing is
   converted to `\x01` before `narrow_transcription()` ever sees it (so
   it's correctly ignored as a within-word boundary, exactly like a
   period or stress mark already was), while genuine word-boundary
   spaces are left as real spaces so cross-word rules still fire
   correctly. `\x01` is converted back to a plain space afterward.
   `$SEP` now includes `\x01` alongside its other separator characters.

All three fixes verified together: `"un beso"` via
`-mfa --mfa-wl --narrow` → `unbeso\tũ ɱ v e s o` (cross-word rule
correctly fires); an isolated `"beso"` via the same flags → `b e s o`
(no longer wrongly narrowed); `-mfa --mfa-rt --narrow` correctly
narrows each word independently with no cross-word effect (the
documented limitation above, not a bug); `-phonword --narrow`, default
mode with `--narrow`, and `-mfa` without `--narrow` all confirmed
unaffected by any of this (regression-checked).

## Utterance-boundary fix (v2.0.13) — the semicolon bug, actually fixed

The stress-test finding from earlier ("cross-word rules can fire across
clause punctuation") is now fixed, not just documented. Root cause was
precise: `normalize_structured_tokens()` silently discarded utterance-
boundary punctuation (`.`, `...`, `!`, `?`, `:`, `;`) at the line level,
before word-splitting — long before any pause-detection code got a
chance to see it. Fixed by replacing that punctuation with a bracketed
sentinel (`[UtteranceBoundary]`, matching the existing
`[MalformedNumber]`-style convention) instead of discarding it. The
sentinel survives word-splitting and phonemicization untouched, and is
converted to the real `‖` symbol during Stage 2 cleanup — right where
`word_level_syllab_adjust()` and `narrow_transcription()` already
correctly treat `‖` as a hard boundary.

Per direct instruction, the boundary character set also includes em
dash (`—`) and the single-character ellipsis symbol (`…`, distinct from
three literal periods), both handled with a simpler unconditional
substitution since neither is reliably attached to a preceding word.
Comma is deliberately excluded — it remains a separate, shorter pause.

`-mfa` (both submodes) and `-phonword` needed their own explicit skip
for the sentinel, for the same reason `narrow_transcription()` itself
needed one in v2.0.11: both exit before Stage 2. Found as a real leak
during testing — without the skip, `-mfa` tried to phonemicize the
sentinel as an ordinary word, producing garbage.

Verified at full scale: 33 correctly-placed pause markers across the
~1,245-word real Wikipedia stress-test corpus, zero sentinel leaks,
zero regressions to any other mode.

## CV/CVG/CVNLRG/voicing + `--narrow`: now a hard error

Per direct instruction: these four output modes reduce every phoneme
to a single category letter, and `--narrow`'s allophonic distinctions
collapse to the same letter either way, so the combination can never
change the output — it was silently producing plausible-looking output
that didn't actually reflect `--narrow` at all. Combining them now
dies immediately with a clear error message (in both English and
Spanish, matching the rest of Perkins), checked right after all flags
and metaconfigs have been fully resolved, before any file processing
begins.

## Manner and place: made to work correctly with `--narrow`

Unlike CV/CVG/CVNLRG/voicing, manner and place output genuinely can
differ under `--narrow` (a stop vs. a fricative /b/ are different
manners), so these were fixed rather than blocked. Every new `--narrow`
phoneme (ʋ, ð̞, ɣ̞, ɣ, ɟ, ç, ʝ̞, ɱ, c) was added to the relevant
character-class variables. Two real bugs found and fixed in the
process, not just additions:

1. **n̪ (dental nasal) was wrongly classified as alveolar in place
   mode.** `$alveolars`' own bare `n` entry was catching it before
   `$dentals` got a chance to. Fixed by adding `n̪` explicitly to
   `$dentals`, which already correctly runs before `$alveolars`.
2. **ɣ̞/ʝ̞ (the lowered, approximant-quality outputs) share a base
   character with an existing bare entry already in `$fricatives`.**
   Since `$fricatives` ran before `$aproximants` in the manner
   function's existing order, it would wrongly consume just the base
   character as a plain fricative before `$aproximants` ever saw the
   full sequence. Fixed by reordering those two substitutions
   specifically in `opt_convert_phonemes_manners()`. (Place mode
   needed no such reordering — ɣ and ɣ̞ correctly map to the same place
   category either way.)

Verified phoneme-by-phoneme, not spot-checked: every rule-coverage
word ("un beso, un guiso, la bota, aguila, seguir, tengo, queso") now
produces a real, correct category letter for every single phoneme in
both manner and place mode — zero unclassified fallthrough characters
remain.

---

## v2.0.14 — the sentinel was being deleted, not used (`-mfa --mfa-wl`)

Found by direct adversarial testing after v2.0.13 was believed finished,
not by waiting for it to surface.

`-mfa`'s one-word-per-line mode was **silently discarding** the
utterance-boundary sentinel rather than using it to block cross-word
rules. The boundary information reached the mode and was then stripped
before it could do its job, so a boundary inside a headword sequence had
no effect at all.

The exact failing case: `un pan; beso` wrongly produced a nasal
assimilation and spirantization straight across the semicolon
(ũmpãɱveso) instead of stopping at it.

Fixed by pushing a real pause marker **before** `narrow_transcription()`
runs, then stripping it from the final dictionary entry — so the rule
engine sees the boundary while the written entry stays clean. Verified
against the exact bug case and against a headword sequence carrying
multiple boundaries; the full 41-combination regression was re-run
clean.

---

## v2.0.15 — a pre-existing `-vrt` bug, and one deliberately left alone

**Fixed.** `do_vrt_preprocessing()` converted every space to its own
internal marker before word-splitting, which swallowed the spaces around
**any** bracketed sentinel token. Confirmed this predates all `--narrow`
work — the pre-existing `[InvalidDate]` sentinel was equally broken in
`-vrt` mode in the untouched v2.0.8 baseline, so this was not something
`--narrow` introduced. Fixed by excluding only the spaces directly
touching a bracket, rather than treating all spaces alike.

**Found and deliberately NOT fixed** at the time (fixed in v2.0.38, see
below), flagged rather than silently patched: a separate, deeper `-vrt`
architectural quirk. Stage 2's
read/chomp/rewrite cycle does not reinsert newlines or spaces between
what were originally separate output lines, so a pause symbol can end up
touching the word before or after it. Confirmed identical in the
untouched v2.0.8 baseline. **Purely cosmetic — the rules themselves
still fire and block correctly across that join**, which is why it was
left: fixing it is a separate and larger undertaking than it looks, and
doing it quietly inside a `--narrow` release would have buried a real
change to shared code.

**v2.0.38.** Stage 2 now ends every line with its own line break, so no
two lines are joined in any mode. `-vrt` no longer has a pipeline of its
own: `do_vrt_preprocessing()` and the other code for Connexor VRT input
are gone, and `-vrt` is a word list made like `-owl`. The narrow rules
are unchanged.

---

## v2.0.20 — `-mfa --narrow` DROPS entries containing the dental nasal

**Read this before combining the two flags.** It is the one interaction in
which `--narrow` and `-mfa` actively disagree, and it fails by discarding
data rather than by erroring.

Since v2.0.20, `-mfa` output may contain nothing outside the acoustic model's
phone inventory. Format validity was not enough on its own: an
out-of-inventory phone parses perfectly and then fails to align, silently.
Entries carrying one are therefore **dropped and reported**, never repaired
into something plausible.

Rule 10 produces the dental nasal n̪ before t̪, d̪, t and d — and the dental
nasal is **not in the inventory**. So every word with a nasal in that context
is discarded from the dictionary.

Measured on a seven-word list:

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

**What does NOT drop, contrary to what one would guess:** the nasalized
vowels from rule 11. They are emitted DECOMPOSED — base vowel plus U+0303 —
and that is the form the inventory holds. Only the precomposed single
codepoints need aliasing, and they are aliased. Rule 11 is therefore safe in
`-mfa` mode; rule 10 is not.

**What to do about it depends on what the output is for.**

| you want | use |
|---|---|
| a dictionary for a PRETRAINED model | `-mfa --mfa-rules`, not `--narrow`. That routine applies the MFA Spanish dictionary's own allophonic rules using its own exact characters, so everything it emits is in the inventory by construction |
| a dictionary for the project's OWN Chilean model | plain `-mfa` — canonical phonemes, one pronunciation per word. Allophones come from the project's allophone table with its context and rank, not from here |
| narrow transcription for a TextGrid tier, analysis, or reading | `--narrow` with any non-`-mfa` mode. Nothing is dropped; the inventory check applies only to `-mfa` output |
| `--narrow` inside `-mfa` anyway | supply an inventory containing the dental nasal via `--mfa-phoneset FILE` (v2.0.23), which overrides the built-in list |

**This is not a bug in either flag.** `--narrow` describes Chilean speech, and
Chilean /n/ genuinely dentalizes before a dental stop. The inventory describes
what an acoustic model was trained on. They are answering different questions,
and v2.0.20 exists precisely so that the disagreement is loud instead of
silent.


## Other changes since v2.0.15 that touch this document

None of them altered a single rule above — all eleven are unchanged, and were
re-diffed against `narrow_transcription()` at v2.0.31 to confirm it. They
change the surroundings.

- **v2.0.17** — the `-g2p` → `-mfa` rename described at the top of this file,
  plus MFA output-format enforcement: exactly one tab, phones separated by
  spaces, no collision with the reserved `sil`/`spn`/`<unk>`/`<eps>` tokens.
- **v2.0.18** — no stress mark or acute accent may appear in the phone column.
  `-mfa` already forced this via `no_stress_marks` since v2.0.9; v2.0.18 makes
  it an invariant checked where the output is written rather than a
  consequence of configuration that one metaconfig edit could undo.
- **v2.0.19** — `--mfa-rules` added. A **separate routine for a separate job**:
  its target is not correct Chilean allophony but whatever the acoustic model
  was trained to expect. `--narrow` is untouched by it and keeps serving its
  own purposes.
- **v2.0.20** — the inventory enforcement described in the section above.
- **v2.0.22** — three rules removed from `--mfa-rules` as not occurring in
  Chilean Spanish. Listed here only to be explicit that **`--narrow` was not
  among the things changed**: the removals were lateral palatalization before
  a high front vocoid, coda obstruent lenition, and s-voicing before a voiced
  consonant, none of which this ruleset ever implemented.
- **v2.0.23 / v2.0.24 / v2.0.25** — the voiced palatal affricate became
  postalveolar, /b/ began leniting to a labiodental, and /d/ and /ɡ/ to the
  approximant forms. **All three are changes to `--mfa-rules`, not to
  `--narrow`** — and they moved `--mfa-rules` toward what the rules above
  had been doing since v2.0.9. Rules 2, 3, 4, 6 and 7 here are unaffected and
  were already emitting the labiodental and lowered forms.


## Currency

This document is in sync with Perkins through **v2.0.37**. v2.0.33 to v2.0.37 changed no narrow rule, and v2.0.36 and v2.0.37 changed no output. v2.0.33 added built-in phrase readings; v2.0.34 made an ellipsis token a pause in token mode; v2.0.35 made a comma the short pause in running text, a colon the long pause in every mode and a full stop after a number the long pause in running text, all of which block the rules as every pause does; changed some syllable breaks (after a diphthong with a written accent, before a liquid and a glide, and the -uir hiatus), which the rules then see; writes every output file except an `-mfa` dictionary in NFC, so a nasal vowel is one character; and with `-nopi` the rules treat the non-IPA pause symbols ## (...) (..) (.) as the pauses ‖ and |, turning them back afterwards (a b after (...) was lenited until then).

v2.0.32 rewrote the lenition rules (now 2 to 4, with rule numbers 5 to 7
no longer used), added the glide `j` to rule 9 and the apostrophe to the
separator class. Rules 1 and 8 to 11 are otherwise unchanged. The rule
code quoted above was copied from the 2.0.32 source.

Earlier currency notes: audited 2026-07-31 against v2.0.31; before
that the file had once drifted sixteen versions behind the source
without anything in it revealing so, which is why every release now
re-checks it against the code.
