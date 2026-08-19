---
name: unstale
description: Detect and repair staleness residue in Python library code and notebooks — dead imports, dead code, resolved TODOs, stale comments/docstrings, and HANDOFF blockers. Use this whenever you want to clean up after a refactor, fix a comment that no longer matches the code, remove unused imports, check for leftover TODOs, detect doc drift, or tidy a notebook before sharing or submission — even without the word "unstale." Default mode auto-detects library .py scope and runs ruff + vulture (deterministic), then LLM semantic checks; never touches notebooks. `--artifact <nb.ipynb>` cleans a notebook as a deliverable (full treatment including dead-code detection). `--exploratory <nb.ipynb>` tidies a working notebook non-destructively (structural + semantic only, no removals ever). Always emits a structured report before any edit.
allowed-tools: Bash Read Edit Write
argument-hint: "[--auto] [--artifact <paths>] [--exploratory <paths>] [--no-archive]"
catalog:
  order: 100
  summary: 'Detect and repair staleness residue in Python library code and notebooks — dead imports, dead code, resolved TODOs, stale comments/docstrings, and HANDOFF blockers; `--auto` applies HIGH-confidence fixes.'
---

**Governing principle: deterministic where you can, LLM where you must — adapt to the repo, never dictate its structure.**

## Live state

```!
git status --short 2>/dev/null || echo "(not a git repo)"
```

## Mode overview

| Invocation | Target | Edits? |
|---|---|---|
| `/unstale` | Auto-detected .py library scope | Report only |
| `/unstale --auto` | Same | Apply HIGH fixes |
| `/unstale --artifact <nb.ipynb>` | Notebook as deliverable | Report only |
| `/unstale --artifact <nb.ipynb> --auto` | Same | Apply HIGH fixes |
| `/unstale --exploratory <nb.ipynb>` | Working notebook | Report only (always) |

`--artifact` and `--exploratory` are **notebook-only**. If a path ends in `.py`, warn and skip it.

---

## Default mode — scope auto-detection

| Signal | Scope |
|---|---|
| `pyproject.toml` / `setup.py` / `src/` / importable package dir | Library → run both lanes |
| Top-level `.py` with no package structure | Ambiguous → skip Lane A (dead-code) |
| Only `.ipynb` files | No .py scope → nudge to `--artifact` / `--exploratory` |

Check for a CLAUDE.md override line: `unstale library scope: <path>; treat <glob> as exploratory`. Use it if present.

Always state the detected scope in the report. If notebooks exist but weren't scanned, emit:
> "N notebooks present — run `/unstale --artifact <path>` (clean as deliverable) or `--exploratory <path>` (tidy) to check them."

---

## Default mode — two lanes

### Lane A — Deterministic

Run on detected library scope. Tag findings `DETERMINISTIC-LINT` or `DETERMINISTIC-DEADCODE`.

```bash
ruff check --select F401 <library-scope>       # unused imports
vulture <library-scope> --min-confidence 80    # dead code
```

### Lane B — LLM judgment

Do **not** re-detect dead code or unused imports — Lane A owns them. Scan for:

- Comments describing logic that has since changed
- Contradictory or outdated docstrings
- Resolved TODOs (is the work actually done?)
- Stale filepaths / README instructions (verify against repo tree)
- Outdated `.ai/HANDOFF.md` blockers

Tag findings `LLM-JUDGED`.

---

## Tool availability

Before running Lane A, check `which ruff && which vulture` (add `nbqa` for `--artifact`).

- If absent: install into the project venv (`uv pip install` if uv present, else `pip install`); add to `pyproject.toml` dev deps if one exists.
- If a tool can't be installed: skip its lane, run the remaining lanes, and state what was skipped and why.

---

## Whitelist

Maintain `.vulture_whitelist.py` at the repo root (committed — not in `.ai/`). Apply to all vulture invocations (default mode and `--artifact`). Report whitelist hits as "suppressed" — never silently dropped.

---

## Confidence tiers and `--auto` gating

| Source | Confidence | Tier | `--auto` eligible |
|---|---|---|---|
| ruff F401 | — | HIGH | yes |
| vulture 100% | unreachable / unused | HIGH | yes |
| vulture 80–99% | probable dead code | MED | flag only |
| LLM-judged | all | flag only | never |

**Chesterton's Fence:** `--auto` never touches anything below 100% vulture confidence under any flag. Code that might be dead is code you don't fully understand yet. The 80% floor widens what the **report** shows; never what `--auto` applies.

---

## --artifact mode (notebook as deliverable)

`--artifact` asserts the notebook is a deliverable, not exploratory scratch. That assertion licenses dead-code detection (the opposite of default mode).

**Deterministic structural** (parse `.ipynb` JSON):
- Execution-order integrity: flag non-monotonic / missing `execution_count`
- Hardcoded path literals: regex code cells for `/home/`, `/mnt/`, `s3://`, etc.

Tag: `DETERMINISTIC-STRUCTURAL`.

**Deterministic dead-code + lint:**
- `ruff check --select F401 <nb.ipynb>` → HIGH
- `nbqa vulture <nb.ipynb> --min-confidence 80` (or jupytext → `.py` → vulture if nbqa unavailable)

**LLM semantic:**
- Markdown↔code drift: a markdown cell describes behavior the code lacks
- Stale outputs: stored output inconsistent with current code (judge from code + stored output; do NOT re-execute)

Under `--auto`: apply HIGH findings (ruff F401 + vulture 100%). Structural and semantic findings remain flag-only.

---

## --exploratory mode (working notebook)

Same as `--artifact` **minus** the destructive parts:

- **Run:** structural checks + LLM semantic
- **Skip entirely:** dead-code lane (vulture / nbqa) — exploratory "unused" code is expected, not stale
- **Unused imports (ruff F401):** flag only — never removed (may be staged for a not-yet-written cell)
- **`--auto` performs NO removals** — all findings flag-only, always

---

## Report format (always emitted before any edit)

State mode and detected scope at the top. Then one row per finding:

| Item | Location | Category | Tier | Source | Action |
|---|---|---|---|---|---|
| `import foo` unused | `utils.py:3` | dead import | HIGH | ruff F401 | remove |
| `MyClass._cache` | `store.py:88` | dead attr (92%) | MED | vulture 92% | flag only |
| `# uses requests not httpx` | `api.py:14` | stale comment | — | LLM-JUDGED | flag only |

## Archive

Unless `--no-archive` was passed: after emitting the report, write it verbatim to `<repo-root>/.ai/reviews/<YYYY-MM-DD>-unstale[-<scope-slug>].md` (`mkdir -p "$(git rev-parse --show-toplevel)/.ai/reviews"`; suffix `-2`, `-3`… on filename collision). Best-effort — a failed write never blocks or alters the run. Probe the ignore with the **file path at repo root**, not the bare directory: if `git check-ignore -q "$(git rev-parse --show-toplevel)/.ai/reviews/probe.md"` exits non-zero, warn and suggest adding `.ai/` to `.gitignore`. (`git check-ignore -q .ai` false-negatives for the directory-form `.ai/` pattern whenever the directory does not yet exist.) This is distinct from the `--auto` apply log below, which records only applied edits.

**Provenance header.** Prepend a YAML block to the **archived file only** (never to the
report shown to the user), so a report re-read months later is still interpretable — in
particular, so you can tell whether it predates a revision of this skill's criteria:

```yaml
---
skill: unstale
skill-version: <toolkit version>
reviewed-repo: <repo basename> @ <short SHA>[ (dirty)]
cli: <claude --version>
date: <YYYY-MM-DD>
---
```

Collect the values with:

```bash
SD="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/unstale}"; SD="${SD:-$HOME/.claude/skills/unstale}"
cat "$SD/.version" 2>/dev/null || echo unknown    # skill-version ("unknown" under plugin install)
git rev-parse --short HEAD 2>/dev/null || echo unknown
git status --porcelain 2>/dev/null | head -1      # non-empty → append " (dirty)"
claude --version 2>/dev/null || echo unknown
```

`.version` is written into the deployed skill dir by `sync.sh push`; it is absent under a
plugin install, which is expected. Resolve any value that fails to `unknown` — never drop
the key, and never let a failed lookup block or alter the archive.

## Apply log (`--auto` only)

Append to `.ai/unstale-<timestamp>.md`:

```
Applied fixes:
- utils.py:3 — removed unused import `foo`
```

---

## Anti-Rationalization

| Excuse | Reality |
|---|---|
| "This comment looks fine" | Does it still match the code path it describes, or just the code that used to be there? |
| "This TODO looks resolved" | Is the work actually merged into this file, or just started somewhere? |
| "vulture flagged this but it's probably used" | That's what `.vulture_whitelist.py` is for — whitelist it, don't suppress the finding |

## Does not

- Flag style, quality, or verbosity — that is `/overbaked`'s domain.
- Re-detect dead code or unused imports in the LLM pass (Lane A owns them).
- Touch `.ipynb` files in default mode.
- Remove anything in `--exploratory` mode, even with `--auto`.
- Mandate any repo directory layout.
