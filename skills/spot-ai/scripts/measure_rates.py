#!/usr/bin/env python3
"""Measure spot-ai Tier D rates on a text corpus, per genre.

These are the operational definitions behind GRAYLIST.md's reference rates.
Run this — do not re-implement — so numbers stay comparable to the shipped
calibration. **Rates are comparable only within a definitions VERSION**: a voice
profile measured under an older version must be re-measured before use (spot-ai
falls back to generic references on a version mismatch).

Usage:
    measure_rates.py [--jsonl-field=NAME] <genre>=<path>[,<path>...] ...

- Repeated genre keys merge: `email=a.jsonl email=b.jsonl` is one email corpus.
- A directory means all *.md/*.txt within (recursive; *.jsonl too when
  --jsonl-field is given). Glob patterns are expanded and filtered the same way;
  matched directories are recursed, odd extensions skipped with a warning.
- JSONL requires --jsonl-field=<name>; each record's field is one text block
  (its own sentence/paragraph boundary — unpunctuated chat never merges).
  Non-dict or field-less records are skipped and counted, never fatal.
- QUOTE glob arguments in zsh ('academic=path/Thesis-*.md').
- Markdown apparatus is stripped before measuring: YAML frontmatter, fenced
  code blocks, heading lines, table rows, horizontal rules. Bold/italic
  markers are removed, their content kept.

Output: per-genre report + `## reference-rates` block in the voice-profile /
.ai/graylist.md override syntax. Un-computable rates are omitted from the block
with an explicit marker — never NaN.

Stdlib only. No corpus text is stored or echoed.
"""
import glob
import json
import math
import os
import re
import sys

VERSION = "2.0 (2026-08-13; NEW DEFINITIONS EPOCH — incomparable with 1.x rates)"
MIN_WORDS = 1500   # below this, a genre's rates are too noisy to quote
MIN_DOCS = 3       # a JSONL record counts as one document; .md/.txt files one each

# --- operational definitions (keep in lockstep with GRAYLIST.md Tier D) ---
# NOTE: patterns overlap on purpose (one construct may count 2–3×); the family
# rate is a calibrated index, not an instance count. Do not "fix" the overlap —
# that would silently break comparability with the shipped reference rates.
CONTRAST_FAMILY = [
    r"(?i)\b\w+, not \w+",
    r"(?im)(?:^|[.!?]\s+)(?:It|That|This|He|She|They)(?:'s| is|'re| are)(?:n't| not)\b",
    r"(?i)\bIt(?:'s| is) that\b",
    r"(?i)\b(?:does|do|is|was|did|are)n't \w+[^;]{0,25}; (?:it|they|she|he|that)\b",
    r"(?i)\bnot\b[^.!?;]{0,50}\bbut\b",
    r"(?i)\bnot (?:just|only)\b",
    r"(?i)\brather than\b",
    r"(?i)\binstead of\b",
]
TRIAD = r"\b(?:[\w'-]+ ){0,3}[\w'-]+, (?:[\w'-]+ ){0,3}[\w'-]+, and (?:[\w'-]+ ){0,3}[\w'-]+\b"
ANAPHORIC = r"(?i)\b(your|our|their|my|his|her|its) [^,.!?]{1,30}, \1 [^,.!?]{1,30},? and \1\b"
LIST_TOKEN = re.compile(r"^\d+[.)]$")
FRAG_EXCLUDE = ("-", "#", ">", "`", "•", "*", "|")

def normalize(text):
    """Unicode punctuation → ASCII; strip markdown apparatus, keep prose."""
    text = text.replace("’", "'").replace("‘", "'")
    text = text.replace("“", '"').replace("”", '"')
    text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)          # YAML frontmatter
    text = re.sub(r"^```.*?^```\s*$", "", text, flags=re.S | re.M)     # fenced code
    lines = [
        ln for ln in text.split("\n")
        if not re.match(r"^\s*(#{1,6}\s|\||---+\s*$)", ln)             # headings/tables/rules
    ]
    text = "\n".join(lines)
    return re.sub(r"\*{1,2}([^*\n]+)\*{1,2}", r"\1", text)            # bold/italic markers only

def sentences(block):
    parts = re.split(r"""(?<=[.!?])["')\]]*\s+""", block)
    return [s.strip() for s in parts if len(s.strip()) > 1]

def measure(blocks):
    """blocks: list of prose blocks (a file, or one JSONL record, each)."""
    text = "\n\n".join(blocks)
    w = len(text.split())
    per1kw = lambda n: 1000 * n / w if w else float("nan")
    m = {"words": w}
    m["em-dash /1kw"] = per1kw(text.count("—"))
    m["  (dash + and/but beat, count)"] = len(re.findall(r"—\s?(?:and|but)\b", text))
    m["  (en-dash used as punctuation, count)"] = len(re.findall(r"\s–\s", text))  # dash-evasion sentinel — no GRAYLIST row, keep
    fam = sum(len(re.findall(p, text)) for p in CONTRAST_FAMILY)
    m["contrast-family /1kw"] = per1kw(fam)
    paras = [p.strip() for b in blocks for p in b.split("\n\n") if len(p.strip().split()) >= 30]
    closers = sum(
        1 for p in paras
        if 0 < len(sentences(p)[-1].split()) <= 12
    ) if paras else 0
    m["epigram-closer %paras"] = 100 * closers / len(paras) if paras else float("nan")
    m["  (paragraphs measured)"] = len(paras)
    ss = [s for b in blocks for s in sentences(b)]
    frags = sum(
        1 for s in ss
        if 0 < len(s.split()) <= 4
        and not s.startswith(FRAG_EXCLUDE)
        and not LIST_TOKEN.match(s)
    )
    m["punch-fragment %sents"] = 100 * frags / len(ss) if ss else float("nan")
    m["clause-colon /1kw"] = per1kw(len(re.findall(r"[a-z]: [a-z]", text)))
    m["triads /1kw"] = per1kw(len(re.findall(TRIAD, text)))
    m["  (anaphoric-possessive triads, count)"] = len(re.findall(ANAPHORIC, text))
    m["rhetorical-? /1kw"] = per1kw(len(re.findall(r"\?(?=[\s\"')\]]|$)", text)))
    return m

def read_jsonl(path, field):
    blocks, skipped = [], 0
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                skipped += 1
                continue
            val = obj.get(field) if isinstance(obj, dict) else None
            if isinstance(val, str) and val.strip():
                blocks.append(normalize(val.strip()))
            else:
                skipped += 1
    if skipped:
        print(f"  [warn] {path}: {skipped} record(s) skipped "
              f"(non-dict, no string field {field!r}, or unparseable)", file=sys.stderr)
    return blocks

EXTS = ("md", "txt")

def collect(spec_parts, field):
    paths = []
    def add_dir(d):
        for ext in EXTS + (("jsonl",) if field else ()):
            paths.extend(glob.glob(os.path.join(d, "**", f"*.{ext}"), recursive=True))
    for part in spec_parts:
        if os.path.isdir(part):
            add_dir(part)
        elif os.path.isfile(part):
            paths.append(part)   # explicit file: accepted as-is (deliberate)
        else:
            matched = glob.glob(part)
            if not matched:
                sys.exit(f"error: no such file, directory, or glob match: {part}")
            for p in matched:
                if os.path.isdir(p):
                    add_dir(p)
                elif p.endswith(EXTS) or p.endswith(".jsonl"):
                    # .jsonl is appended even without --jsonl-field so the deliberate
                    # refusal fires downstream rather than a silent skip here.
                    paths.append(p)
                else:
                    print(f"  [warn] skipping glob match with unhandled extension: {p}",
                          file=sys.stderr)
    blocks, ndocs = [], 0
    for p in sorted(set(paths)):
        if p.endswith(".jsonl"):
            if not field:
                sys.exit(f"error: {p} is JSONL — pass --jsonl-field=<name> "
                         f"(measuring raw JSON syntax would pollute every rate)")
            recs = read_jsonl(p, field)
            blocks.extend(recs)
            ndocs += len(recs)
        else:
            blocks.append(normalize(open(p, encoding="utf-8", errors="replace").read()))
            ndocs += 1
    return blocks, len(set(paths)), ndocs

OVERRIDE_KEYS = [
    ("em-dash", "em-dash /1kw", "/1kw"),
    ("contrast-family", "contrast-family /1kw", "/1kw"),
    ("epigram-closers", "epigram-closer %paras", "%"),
    ("punch-fragments", "punch-fragment %sents", "%"),
    ("clause-colons", "clause-colon /1kw", "/1kw"),
    ("triads", "triads /1kw", "/1kw"),
]

def main(argv):
    field = None
    genres = {}
    for a in argv:
        if a.startswith("--jsonl-field="):
            field = a.split("=", 1)[1]
            continue
        if "=" not in a:
            sys.exit(__doc__)
        g, spec = a.split("=", 1)
        genres.setdefault(g, []).extend(spec.split(","))
    if not genres:
        sys.exit(__doc__)
    print(f"# measure_rates.py {VERSION}\n")
    override_lines = []
    for genre, parts in genres.items():
        blocks, nfiles, ndocs = collect(parts, field)
        m = measure(blocks)
        flags = []
        if m["words"] < MIN_WORDS:
            flags.append(f"INSUFFICIENT: <{MIN_WORDS} words — do not quote rates")
        elif ndocs < MIN_DOCS:
            flags.append(f"CAUTION: only {ndocs} document(s) — rates rest on a narrow base")
        print(f"## {genre} — {nfiles} file(s), {ndocs} doc(s), {m['words']} words"
              + (f"  [{'; '.join(flags)}]" if flags else ""))
        for k, v in m.items():
            if k == "words":
                continue
            if isinstance(v, float):
                print(f"  {k:44s} {'n/a':>6s}" if math.isnan(v) else f"  {k:44s} {v:6.1f}")
            else:
                print(f"  {k:44s} {v:6d}")
        print()
        if m["words"] >= MIN_WORDS:
            caution = f"  # CAUTION: narrow base, {ndocs} doc(s)" if ndocs < MIN_DOCS else ""
            lines = [f"# genre: {genre} ({m['words']}w, {ndocs} docs; script v2.0){caution}"]
            for key, metric, unit in OVERRIDE_KEYS:
                v = m[metric]
                if math.isnan(v):
                    lines.append(f"# {key}: not measurable (no qualifying input)")
                elif unit == "%":
                    lines.append(f"{key}: {v:.0f}%")
                else:
                    lines.append(f"{key}: {v:.1f}/1kw")
            override_lines.append("\n".join(lines))
    if override_lines:
        print("## reference-rates (paste into voice-profile.md / .ai/graylist.md)\n")
        print("\n\n".join(override_lines))

if __name__ == "__main__":
    main(sys.argv[1:])
