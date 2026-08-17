#!/usr/bin/env python3
"""Regression fixture for measure_rates.py — catches definition drift and the
bug classes found by the 2026-08-13 ai-review (NaN emission, list-token
fragments, non-dict JSONL crash, glob/dir handling, smart apostrophes).

Run from anywhere: python3 <skill>/tests/test_measure_rates.py
Wire into sync.sh's lint battery at go-public (pattern: tests/smoke_repo_init.py).
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "scripts", "measure_rates.py")

FIXTURE_MD = """---
title: frontmatter must not count
---
# Heading must not count

It's not the model. That's not the data, but the pipeline. We chose X, not Y,
rather than Z — and the plan held. This paragraph needs to reach thirty words of
real prose so the epigram check has one qualifying paragraph to look at, which it
now does comfortably. The work is where I put it.

1. First list item long enough to be a sentence.
2. Second list item long enough to be a sentence.

| table | row |
|---|---|

Your models, your data, and your methods. It’s not finished.
"""

FIXTURE_JSONL = "\n".join([
    '{"body": "ok"}',
    '{"body": "sounds good"}',
    '{"body": "It’s not urgent, but soon."}',
    '["not", "a", "dict"]',
    '{"other": 1}',
]) + "\n"

def run(args):
    return subprocess.run([sys.executable, SCRIPT] + args,
                          capture_output=True, text=True)

def main():
    fails = []
    with tempfile.TemporaryDirectory() as d:
        md = os.path.join(d, "fixture.md")
        jl = os.path.join(d, "fixture.jsonl")
        open(md, "w", encoding="utf-8").write(FIXTURE_MD)
        open(jl, "w", encoding="utf-8").write(FIXTURE_JSONL)

        r = run(["--jsonl-field=body", f"m={md}", f"j={jl}"])
        out, err = r.stdout, r.stderr
        def check(cond, name):
            (fails.append(name) if not cond else None)
            print(("ok  " if cond else "FAIL") + f"  {name}")

        check(r.returncode == 0, "exit 0")
        check("m — 1 file(s), 1 doc(s)" in out, "md counts as 1 doc")
        check("j — 1 file(s), 3 doc(s)" in out, "jsonl records count as docs (3, not 5)")
        check("2 record(s) skipped" in err, "non-dict + field-less records skipped, not fatal")
        check("nan" not in out.lower().replace("not measurable", ""), "no NaN ever printed")
        # frontmatter 'title:' line stripped -> not a clause-colon; heading/table stripped
        check("Heading" not in out, "no corpus text echoed")
        # smart apostrophe normalized: 'It’s not finished' must count in contrast family
        fam_line = [l for l in out.splitlines() if "contrast-family /1kw" in l][0]
        check(float(fam_line.split()[-1]) > 0, "contrast family fires (incl. smart apostrophe)")
        # list tokens must not be punch fragments (module-level: exact exclusion check)
        import importlib.util
        spec = importlib.util.spec_from_file_location("mr", SCRIPT)
        mr = importlib.util.module_from_spec(spec); spec.loader.exec_module(mr)
        ss = mr.sentences(mr.normalize(FIXTURE_MD))
        frags = [s for s in ss if 0 < len(s.split()) <= 4
                 and not s.startswith(mr.FRAG_EXCLUDE) and not mr.LIST_TOKEN.match(s)]
        check("1." in ss and "2." in ss and all(not mr.LIST_TOKEN.match(f) for f in frags)
              and len(frags) == 2, "list tokens excluded from punch fragments (2 real frags)")
        # anaphoric triad detected
        ana = [l for l in out.splitlines() if "anaphoric-possessive" in l][0]
        check(int(ana.split()[-1]) >= 1, "anaphoric-possessive triad detected")
        # JSONL genre <1500 words -> insufficient, and no override block for it
        check("INSUFFICIENT" in out, "insufficient flag fires on tiny genres")

        # glob matching a directory must not crash
        sub = os.path.join(d, "sub"); os.makedirs(sub)
        open(os.path.join(sub, "a.md"), "w").write("Words here. More words follow.")
        r2 = run([f"g={os.path.join(d, 'su*')}"])
        check(r2.returncode == 0, "glob-matched directory recursed, no crash")

    if fails:
        print(f"\n{len(fails)} FAILURE(S): {fails}")
        sys.exit(1)
    print("\nall checks passed")

if __name__ == "__main__":
    main()
