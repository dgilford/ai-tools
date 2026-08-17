# Building a spot-ai voice profile

Once-per-deployer guidance — deliberately **not** auto-loaded by the skill. A voice
profile turns spot-ai's generic, AI-corpus-derived reference rates into rates measured
on *your* verified writing. The skill works without one; with one, it is both more
sensitive and more specific (measured on one author, the generic references missed in
both directions: a reference ~25× above their real dash baseline meant lost
sensitivity, while two entries sat above the generic threshold in most genres of their
ordinary prose and would have false-fired repeatedly).

**Install path:** `~/.claude/spot-ai/voice-profile.md` — machine-local. **Never commit
it**: it contains your writing statistics and quoted exemplars.

## What the profile contains

1. Header: date, per-genre word counts, provenance rules applied, `measure_rates.py`
   version used. **The version line is load-bearing:** if the shipped script's version
   later differs from the profile's, spot-ai falls back to generic references until the
   profile is re-measured — cross-version rates are incomparable by design.
2. `## reference-rates` — per-genre Tier D rates, pasted **unmodified** from
   `scripts/measure_rates.py` output. Never re-implement the measurements: the script
   carries the same operational definitions as the shipped calibration, and definition
   drift silently invalidates every comparison.
3. `## voice-annotations` — gray-list entries (Tiers S/L) you demonstrably use in
   verified hand-written text: entry name, count, 2–3 verbatim quotes of ≤25 words with
   source and date. Floor: **n ≥ 2** — never annotate from a single instance.
   Annotations lower confidence and tag findings `author-voice (n=…)`; they are
   **not exemptions** — exemption is a human edit in a repo's `.ai/graylist.md`.

## Corpus hygiene (each rule below moved a measured number materially)

- **Provenance is the load-bearing rule.** Include only text you hand-wrote solo,
  from before your AI-adoption date or with known provenance. An author-voice note
  derived from post-adoption material describes the assistant, not the author —
  observed: one genre's dash rate fell by nearly half when AI-assisted pages were
  quarantined; the quarantined pages alone ran ~3× the clean rate.
- **Segment by genre; never pool.** Register variance is the signal. Slack and text
  messages are distinct registers (measurably different sentence length and
  contraction rates) — split them.
- **Floors:** below ~1,500 words a genre's rates are noise — record "insufficient"
  rather than a number. At or above the word floor but from fewer than 3 documents,
  carry the narrow-base caution the script emits.
- **Strip PDF apparatus before measuring.** Page furniture (contents entries,
  headings, table rows, captions, equations) inflates exactly the short-sentence and
  paragraph-close metrics — observed: punch-fragments 38.5%→13.5% after stripping.
  The diagnostic signature is those two metrics moving while everything else stays put.
- **Chat needs a provable direction field.** No sender field → the source is
  inadmissible (you can't certify a record as written rather than received), and
  greeting-based direction inference is actively unsafe (observed: a first-name
  greeting matched the author's own nickname, not the recipient).
- **No blanket blockquote rules.** Check each document's quotation convention — one
  real document carried the author's words *inside* the blockquotes and everyone
  else's outside them.
- **Screen sensitive content at the quote level, not document level.** A
  document-level keyword screen cost an entire genre its exemplars because `diagnos`
  matched "diagnostic" in ordinary scientific vocabulary.
- **Say which "solo-authored" reading you used** for multi-author work — strict
  (sole-authored only) vs first-author-inclusive can differ by ~2× in corpus size,
  and both are defensible. Record the choice in the profile header.

## Measurement

```
python3 ~/.claude/skills/spot-ai/scripts/measure_rates.py [--jsonl-field=NAME] email=<paths> chat-texts=<paths> ...
```

Quote glob arguments (zsh globs the whole `genre=path*` word otherwise). JSONL input
requires `--jsonl-field`; repeated genre keys merge. Profile genres may be finer-grained
than the skill's inference taxonomy — the skill uses the closest match and falls back
to generic references when none matches.

## Limits worth knowing before you trust it

- A style profile calibrates lane 1 only. Text generated *from* a style profile of the
  same author can suppress the density and lexical tiers by construction — verified
  empirically: those tiers went fully dark on profile-guided impersonation drafts
  (judgment-tier entries and lane-2 substance tells still fired). Dash presence is
  evidence only relative to a baseline; dash absence proves nothing.
- Rates drift with life and role changes. Re-measure occasionally; the profile header's
  date is there so staleness is visible.
