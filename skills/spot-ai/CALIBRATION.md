# spot-ai calibration record

Every number in `GRAYLIST.md` traces to here. Published so a deployer can judge whether
the shipped references apply to *their* writing — they were measured on one model family
and one human author, and the honest answer is often "re-measure."

Definitions epoch: **`measure_rates.py` v2.0** (2026-08-13). Rates are comparable only
within an epoch; v1.x figures are not comparable and are not quoted here.

## The AI corpus (source of every generic reference rate)

| | |
|---|---|
| Specimens | 35 documents, ~20.2k words |
| Round 1 | 10 specimens / 8.2k words — rich prompts (numbers, scenario, mechanism supplied) |
| Round 2 | 25 specimens / 12.0k words — thin prompts (confident deliverable demanded, key facts withheld) |
| Models | Fable 5, Opus 5, Haiku 4.5 (one vendor family) |
| Dates | 2026-08, single fortnight |
| Registers | 10: manuscript · peer review (reviewer + author-response) · professional email · public-web · creative · work chat · personal chat · notes-to-self · career documents |
| Generation | Subagents kept **blind to the detection purpose** — an agent told "we're hunting X" suppresses or performs X |
| Domain | One scientific domain (climate/hurricanes), which is a confound for lexical entries |

**Measured, per model tier** (v2.0 definitions, document-shaped input):

| Metric | Round 1 | R2 Fable | R2 Opus | R2 Haiku |
|---|---|---|---|---|
| em-dash /1kw | 14.9 | 15.5 | 10.6 | 17.4 |
| contrast-family /1kw | 5.7 | 3.9 | 5.0 | 5.7 |
| epigram closers (% paras) | 34 | 27 | 20 | 33 |
| punch fragments (% sents) | 7.5 | 4.8 | 7.4 | 7.5 |
| triads /1kw | 3.0 | — | — | — |
| rhetorical-? /1kw | 2.3 | 3.6 (all R2) | | |

Structural metrics held across all three capability tiers; the lexical tier did not
(see below). Cross-vendor and cross-date invariance is **unmeasured**.

## Human comparison (n = 1 author)

One author's verified solo-written archive, ~455k words across five genres, measured with
the same script. Genre-level rates are machine-local by design (they are personal writing
statistics) and are **not** published here. The two findings that generalize:

1. **Author baselines can sit far below the AI-derived references** — this author's
   em-dash rate ran roughly a quarter of the shipped generic reference, making a high rate
   a strong per-author discriminator *once a profile exists* and a weak one without.
2. **Author baselines can sit far above them too** — epigram closers and punch fragments
   exceeded the generic thresholds in most of that author's genres, i.e. the generic
   values would have false-fired repeatedly on ordinary human prose.

Both directions are why generic-reference confidence **caps at med** and why a voice
profile is the primary mechanism rather than a tweak (`PROFILE-GUIDE.md`).

## What calibration ruled out

- **The classic word list is near-dead against current frontier models.** ~40 of 48
  Tier L entries produced zero hits in ~20.2k words. The three that fired
  (`underscore`, `orchestrate`, `in an era`) concentrated at the smallest model.
  A 20k-word corpus cannot detect base rates below ~1/10k words, so this is
  **power-limited, not exhaustive**.
- **Style loudness does not rise when substance thins.** In the one rich-vs-thin
  comparison (same model, matched registers), style rates were flat to lower under thin
  grounding. Hence two independent lanes: lane-1 volume predicts nothing about lane 2.
- **Style detection does not survive style-guided impersonation.** Six drafts generated
  from a style profile of the calibrated author: the density and lexical tiers went to
  **zero**; judgment-tier entries and lane-2 substance tells still fired. Hence
  *dash presence is evidence only against a baseline; dash absence proves nothing*, and
  hence lane 2 exists at all.

## Validation runs

| Test | Result |
|---|---|
| Known-AI specimen | flagged, incl. the intended lane-2 fabrication |
| Known-human hand-written specimen | near-clean; no manufactured findings |
| Style-profile impersonation (6 drafts) | lane 1 dark; lane 2 caught both pre-registered candidates, judged blind |
| Blind labeled panel (12 docs: 4 human pre-2020, 4 AI incl. 2 suppression-constrained, 4 hybrid) | 12/12 documents, 16/16 hybrid paragraph attributions — **caveats below** |
| Adversarial inputs (8 attacks: override injection, illegal exemptions, in-document reviewer directives, fake exemption block, seeded prior-report suppression, unignored/symlinked archive) | 8/8 blocked, 0 false refusals |
| Low-effort executor | gates held; surfaced two spec gaps (length floor, template) since closed |

**Panel caveats, which travel with the 12/12:** the judge knew the 4/4/4 composition and
which registers the AI specimens covered — a structural assist no real deployment gets;
judge and generator were the same model family, so self-recognition is plausible and
unmeasured; n=12, one builder, one day. Read it as "discriminates cleanly under known
priors," not as an accuracy claim.

## Known limits, stated plainly

- One vendor family, one fortnight, one scientific domain, **n=1 human**.
- Two metrics (`punch-fragments`, `rhetorical-?`) are **not comparable across corpus
  shape**: record-shaped input (chat/email exports) reads structurally higher than
  document-shaped input on identical prose. See GRAYLIST's Tier D warning.
- Two Tier D references (epigram closers, punch fragments) sit *inside* the measured AI
  range, so they separate poorly on generic values alone — flagged in-place.
- The blacklist tier (violence idioms) detects nothing by design: 0 corpus hits. It
  enforces one deployer's house style and should be replaced with your own.
- `coinage density` and the anaphoric-possessive triad form are **judgment-assessed** —
  the script does not measure them, so no reference rate exists.

## Reproducing or replacing these numbers

The corpora and full analyses live in the author's gitignored `.ai/spot-ai-corpus/` and
`.ai/reviews/` and are not distributed (they contain personal-corpus provenance detail).
To build your own references: run `scripts/measure_rates.py` over a corpus you generate
the same way — blind subagents, multiple registers, per-genre, never pooled — and paste
its output into a repo override or a voice profile. **Do not re-implement the
measurements**: definition drift silently invalidates every comparison, which is the
single most common way these numbers go wrong.
