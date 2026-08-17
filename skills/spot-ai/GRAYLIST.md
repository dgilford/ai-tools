# GRAYLIST — patterns that mark writing as likely AI-generated or AI-weakened

**Version: 2026-08-13 calibration (script v2.0 definitions epoch).** Companion file for `spot-ai`; every entry is a
*candidate* flag ("look closer"), never a verdict. Scoring, tier semantics, confidence
mapping, and layer/override rules live in SKILL.md — this file is the entry catalog.

**Evidence classes:**
- **AI corpus** — 35 blind specimens / ~20.2k words (`.ai/spot-ai-corpus/`: round 1 =
  10 rich-grounded / 8.2k; round 2 = 25 thin-prompt / 12.0k; Fable 5 / Opus 5 /
  Haiku 4.5, 2026-08). One vendor family, one date — cross-vendor unmeasured.
- **Human corpus** — ONE author's verified 455k-word archive (via the voice-profile
  mechanism). Per-author evidence, not a population baseline.
- AI and human rates come from the same script but different genre mixes and document
  lengths — **compare per-genre, never pooled**.
- `[author]` = deployer-supplied entry, kept regardless of corpus support.
  `(n=1, provisional)` = seen once; keep only if it recurs in real use.

---

## Tier S — single-instance structural tells (lane 1)

| Entry | What it looks like | Evidence | Legitimate use / scoping |
|---|---|---|---|
| Candor performance | "the honest answer/version", "I want to be upfront/straightforward", "to be clear" — announcing candor instead of exhibiting it | strong (both rounds) | Earned once in a genuinely delicate refusal; flag at 2+ or when nothing sensitive follows. **Surface = the announcing formulas ONLY** — sentence-initial/parenthetical `honestly,` and `to be honest` are discourse markers, never hits (the obvious regex false-fired ~20× on one human corpus) |
| Alignment flattery formula | "exactly/precisely the kind of X [the field needs / I'd like to see / where this belongs]" | strong (5 registers, incl. both peer-review stances) | Rare in human prose; flag on sight |
| Chiasmus / mirrored sentence pairs | "The science keeps the comics honest. The comics keep the science human." | strong | Once per *document* as a deliberate closer may be voice; twice is generation. Judgment-assessed |
| Register narration / instruction echo | The text names the constraint it was given: "none of them a pep talk", "without ceremony"; prompt words echoed verbatim ("expertly") | strong | In AI-assisted text this is the prompt leaking into the artifact; check against the ask. Judgment-assessed |
| Anthropomorphic gravitas | "The ocean… has time." | strong | Fine once in creative/op-ed; a tell in professional/technical prose. Judgment-assessed |
| Drama adverbs | "quietly", "simply" staging profundity: "we are quietly raising the limit" | moderate | Adverbs on physical actions are fine. **Judgment-only — never emit or read a raw count** (one human corpus: ~20 hits, all ordinary or allusive) |
| Unprompted denial | Rebutting an accusation nobody raised: "not a consensus born of groupthink"; a provenance assertion addressed to a reviewer ("human-authored and independently verified") | n=2, independent sources | Legitimate when the objection is live in the surrounding discourse — check whether anyone actually raised it. Judgment-assessed |
| Meta-calibration performance | Hedging *about* confidence instead of hedging the claim: "I notice I'm confident… a little too comfortable" | (n=1, provisional) | Genuine self-audit exists; flag when no claim is actually revised |

## Tier D — density tells (lane 1)

Always reported when present (semantics in SKILL.md). References below are per-1,000
words unless marked; **generic values are AI-corpus-derived placeholders** — the intended
replacement is a voice profile measured with `scripts/measure_rates.py` (primary), or a
repo-override re-rate (secondary). Where a chat/notes value is given explicitly, use it
as-is; halving applies only to single generic values (see SKILL.md).

**Length floor: below ~150 words of prose, do not score Tier D rates.** List the
instances and say why the rate is unscored — at 75 words a single instance reads as
13/1kw, which looks damning and means nothing. Instances still report; only the
rate-vs-reference scoring is suppressed. (Independently improvised by two separate
runs before it was written down.)

**Quoted material is excluded from Tier D rates.** Block quotes, fenced quotes, and
explicitly attributed excerpts are someone else's prose (or, in a fabricated quote,
the very thing lane 2 is flagging) — measure the author's prose and report the raw
figure alongside if it differs materially (observed: a document whose only punch
fragment sat inside a fabricated quote read 12.5% raw / 0% on prose).

**⚠ Two metrics are not comparable across corpus shape.** `punch-fragments` and
`rhetorical-?` are measured per block, so a **record-shaped** corpus (JSONL: chat,
email — every message its own boundary, short unpunctuated messages becoming ≤4-word
sentences) reads structurally higher than **document-shaped** input at identical
prose. Measured: the same AI text reads 7.0–7.5% punch as documents and 9.0% reshaped
into records; a real message corpus roughly doubles (one author's email 10→23%, chat
14→28% on the definition change alone). **A review target is always document-shaped**,
so for these two metrics a voice-profile rate derived from JSONL records is not a
valid reference — fall back to the generic value and say so. Profiles must state
input shape per genre; treat unstated as record-shaped for chat/email genres.

| Entry | Reference (generic) | Measured AI rate | Notes / scoping |
|---|---|---|---|
| Em-dash — incl. "— and/— but" beat [author] | 8 formal; 4 chat/notes | tier aggregates 10.6–17.4/1kw (v2.0) | Presence-only evidence: universal in *unsuppressed* generation, zero under profile-guided suppression (D2 run). The one measured human ran far below the generic reference — with a profile, a high rate is a strong per-author discriminator. The "— and/but" beat is the more diagnostic sub-form |
| Contrast-reframe family [author + corpus] | > 3 /1kw | 3.9–5.7 /1kw, all tiers | **Eight calibrated variants, counted together:** "X, not Y" · sentence-initial "It's/That's/This is not…" · "It's that…" · "doesn't X; it Ys" · "not A but B" · "not just/only X" · "rather than" · "instead of". Patterns overlap (one construct can count 2–3×) — deliberate; **rates compare only script-to-script**. The most consistent multi-variant signature in both rounds |
| Epigram paragraph closers | > 25% of ≥30-word paragraphs ending on a ≤12-word aphorism | AI 20–34% | ⚠ The generic threshold sits inside the AI range and *below* the one measured human (41% in email) — generic-reference confidence is low here; trust only profile genre rates |
| Punch fragments | > 5% of sentences ≤4 words (formal) | 4.8–7.5% | ⚠ Threshold sits inside the AI range — generic confidence low here too. Natural in chat; a tell at density in manuscripts and letters |
| Triadic parallelism, esp. anaphoric possessives [author] | > 3 /1kw (list-triads) | 3.0 /1kw both rounds (v2.0) | "your classrooms, your labs, and the communities…" — v2.0 counts list-triads (multi-word items) as `triads` and reports the **anaphoric count separately**: only 1 anaphoric instance in 20.7k AI words, so that form is rare-but-damning and **judgment-assessed**; the 3.0/1kw list-triad rate is the weak-signal number |
| Coinage density | > 1 minted label per ~300 words | qualitative | "credibility tax". One coinage is voice. Judgment-assessed; the script does not measure this |
| Colon-elaboration engine | > 4 clause-colons /1kw | qualitative | "The core logic is counterfactual: …" Often stacks with epigram closers |
| Rhetorical-question pacing / dramatic titles [author] | judgment | 2.3 (R1) – 3.6 (R2) /1kw (v2.0) | Incl. "X Is Not a Takeaway"-style headline dramatics |
| Summary sentences re-iterating prior points [author] | judgment | — | The "in short, as shown above" reflex; distinct from a requested abstract. Judgment-assessed |

## Tier L — lexical list (lane 1, low weight)

**~40 of these 48 words: zero hits in the ~20.2k-word AI corpus** — a corpus that size
cannot detect rates below ~1/10kw, so read this as power-limited, not exhaustive. The
entries that did fire (`underscore`⁴, `orchestrate`⁴, `in an era`⁴) concentrated at
Haiku. Low confidence alone; 3+ distinct entries co-occurring escalate.

delve · rich tapestry · multifaceted · nuanced¹ · foster · showcase · toolkit² · harness ·
landscape (abstract)³ · testament · realm · intricate · pivotal/crucial role · vibrant ·
meticulous · underscore⁴ · unveil · paradigm · boasts · valuable insights · indelible mark ·
garnered significant · sheds light on · leverage (verb) · seamless · interplay · beacon ·
adhere · paramount · elevate⁵ · comprehensive⁶ · profound · orchestrate⁴ · indelible ·
unlock · captivate · facilitate⁷ · scalable · in light of · in today's · it is evident that ·
revolutionary⁸ · game-changing · in many ways · when it comes to · it is important to
understand · in an era where/when⁴ · and that matters

**Scoping notes (from calibration):**
1. `nuanced` — suppress when the document's *topic* is nuance (all corpus hits were prompt echo).
2. `toolkit` — proper nouns exempt (all corpus hits were a product name).
3. `landscape` — literal/geographic use exempt, and so is image orientation ("portrait and landscape").
4. `underscore`, `orchestrate`, `in an era` — fired on current models AND returned zero on
   the one 455k-word human corpus. Strong *per-author* core; other authors (academics
   especially, for `underscore`) may use them routinely — re-weight per deployer.
5. `elevate` — scientific "elevated SSTs / elevated risk" exempt; flag the transitive marketing sense.
6. `comprehensive` — earned for genuinely exhaustive scope being *requested*; flag as self-description.
7. `facilitate` — the literal "lead or run a session" sense exempt (one human corpus: >100
   instances, every one literal); flag the abstract marketing sense.
8. `revolutionary` — proper-noun/historical use exempt (Revolutionary War, place names).

**Additions (fired at Haiku):** `I hope this finds you well` — flag on sight · hollow
paired intensifiers ("both scientifically and societally invaluable").

## Tier B — blacklist (house style; never exempt, flag on sight) [author]

Idioms or metaphors referring to weapons or violence: shoot · footgun · fire away ·
come out swinging · take a stab at · pull the trigger · under the gun · miss the mark ·
(and kin). Prohibited by the deploying author's house style regardless of AI-likelihood
(0 corpus hits — it enforces style, it doesn't detect). Verdict class: `blacklist`.

---

## Lane 2 — substance tells (severity = damage to the reader)

Runs on every document regardless of lane-1 results — in the one rich-vs-thin calibration
comparison, style rates were flat-to-lower under thin grounding, so lane-1 volume predicts
nothing about substance. Observed tier pattern (1–4 specimens per cell — **a prior to
check, not a law**): inflation (small models) → fabricated specificity (frontier) →
unrequested research (tool-bearing agents).

**MEMBERSHIP TEST — apply before reporting any lane-2 finding.** A lane-2 finding must
trace to a **generation mechanism**: a defect that arises from *how a model produces text*
(no ground truth behind a specific, no lived experience behind a stance, default formatting,
agreeableness, helpfulness overshoot). Name the mechanism in the finding.

Ask: *would a competent human writer, working carefully in this register, plausibly produce
this?* **If yes, it is out of scope — even if it is a real flaw.** spot-ai identifies AI
markers; it is not a copy-editor, a domain reviewer, or a risk auditor. Specifically out of
scope: typos, grammar, formatting, and stray markup · vagueness or wordiness as such ·
undefined acronyms · internal inconsistencies and numbering gaps · domain-specific risk
(hiring bias, legal exposure, methodological validity) · claim scope and evidence strength ·
any suggestion that amounts to "write this better."

Out-of-scope items may be acknowledged in **one line at the end of the report — counts and
tool names only, never descriptions or advice**: e.g. `Out of scope: 4 non-AI-marker items
(→ /reviewer-2 for claim rigor, /overbaked for verbosity)`. Never a table row, never a fix.

| Entry | What it looks like | Generation mechanism | Evidence | Notes |
|---|---|---|---|---|
| Fabricated provenance | Quoted output/results/demo carrying a provenance claim ("verbatim", "a real run") with no citable source | no artifact exists to quote from | 1 flagship specimen + class logic | The provenance claim is the defect; a labeled synthetic example passes. Highest severity |
| Grounded-but-wrong | Sourced-sounding specifics alongside genuinely sourced material | partial grounding, remainder generated | 1 specimen (repo-read, still invented facts) | Partial grounding camouflages the invented remainder; verify the checkable specifics (offline-unverifiable ⇒ `cant-assess`) |
| Invented affect of real people | "The kids are already excited!" — unverifiable states of named third parties as fact | no access to third parties' minds | 2 tiers independently, same slot | Personal-correspondence register |
| **Unearned authority (invented first-person testimony)** | First-person stances/experience the source never supplied: "my read is…", "I work on that kind of analysis", "this is the workflow I use most" | no lived experience behind the voice | n=3 (two correlated D2 sources + round 2) | The strongest lane-2 tell observed so far against voice-profiled text — thin base, but *by construction* a style profile cannot suppress what a document claims. Citations may all be real; the authority is what's fabricated |
| Unprompted structural scaffolding [author] | Bold-label bullets, emoji vote blocks, spec tables in registers that didn't ask | default output formatting | 3/3 tiers | Structure substituting for prose judgment |
| Confidence-boosterism closers | "I think we have a strong paper here" appended to status text | trained agreeableness | 3/3 tiers, same slot | Flag when nothing in the document supports the assurance |
| Vague progress-speak | "the work is converging", "actively in progress" | slot-filling where no state exists | 2 tiers | **Scope:** only when it fills a slot the document *promises to report* (a status update reporting no status). Not general vagueness — "be more specific" is out of scope |
| Scope expansion | Deliverable answers more than asked, burying the asked-for thing | helpfulness overshoot | 2 specimens (highest tier) | Reads as thoroughness |
| Unintended sophistry [author] | Bland ideas presented confidently in a profound style | fluency without content | corpus-wide | The core test: strip the styling, restate the claim — if nothing remains, flag |
| Underuse of epistemic hedging [author] | Confident assertion of a specific the writer cannot have grounds for | unhedged output regardless of grounding | corpus-wide | **Scope:** pairs with an unverifiable or invented specific — the missing hedge on *that*. A well-grounded claim stated plainly is not a finding, and "hedge more" is out of scope |

---

## Overrides (semantics in SKILL.md — this is the vocabulary)

Recognized re-rate keys (as emitted by `measure_rates.py`): `em-dash` · `contrast-family` ·
`epigram-closers` · `punch-fragments` · `clause-colons` · `triads` — mapping to the Tier D
rows of the same names. A repo override may also add entries and exempt lane-1 gray
entries (e.g. a stats manuscript exempting a domain term); never lane 2, never Tier B.
Withdrawn findings stay withdrawn. Building a voice profile: `PROFILE-GUIDE.md`.
