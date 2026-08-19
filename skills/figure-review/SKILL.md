---
name: figure-review
description: 'Audit a scientific figure for publication-readiness: colormaps, uncertainty, axis labels, caption completeness, and claim support. Panel-aware — judges one panel of a composite against what its shared caption and sibling panels supply, and raises a likely-deliberate choice as `by-design?` instead of a defect. Use this whenever the user shares or references a figure, plot, panel, or colorbar for a paper, report, or brief and wants it checked, reviewed, or made publication-ready — even if they just say "does this figure work?" or "review my plot." Emits a per-criterion report and archives it to .ai/reviews/; never silently rewrites plotting code.'
allowed-tools: Bash Read Write Glob Grep
argument-hint: "[--style] [--no-archive]"
catalog:
  order: 110
  summary: 'Audit a scientific figure for publication-readiness: colormaps, uncertainty, axes, caption, and claim support; panel-aware, and raises likely-deliberate choices as `by-design?`; `--style` adds CC house style.'
---

## Colorblind reference

```!
D="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/figure-review}"; D="${D:-$HOME/.claude/skills/figure-review}"; cat "$D/COLORBLIND.md" 2>/dev/null || echo "(colorblind guide not found)"
```

## House style

```!
D="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/figure-review}"; D="${D:-$HOME/.claude/skills/figure-review}"; cat "$D/CC-STYLE.md" 2>/dev/null || echo "(no house style configured — criterion 6 skipped)"
```

## Inputs

Accept any subset of: figure image, plotting code, caption, surrounding text claim. Mark `cant-assess` for any criterion that requires input not provided.

## Scope — establish this before applying any criterion

Determine each of the following from the inputs.

**Standalone figure, or one panel of a composite?** Look for siblings before deciding — list the directory, and if plotting code is an input, check whether one script saves several panels. Signals: a panel-style filename (`fig2C.pdf`, `Fig_3B.pdf`); a sibling differing by one letter. A panel delegates its **legend and symbol definitions** to the composite; do not flag those. It does **not** reliably delegate **n or data source** — a composite caption routinely covers several panels without mapping which is which — so keep checking them. When the composite is not itself an input, mark delegated items `cant-assess`; never pass them silently.

**Draft, or published?** Published means post-peer-review: apparent defects are far more likely to be considered choices, journal requirements, or context carried by the caption. For a published figure, raise concerns as `by-design?` rather than `flag`.

## Deliberate-choice discipline

An author's considered tradeoff is not a defect. Before flagging, ask whether a competent author would plausibly have chosen this on purpose — journal or house constraints, panel economy, or fidelity to a figure being reproduced. If so, use `by-design?` and name *why* it might be intentional, so the author can confirm or overrule in one line.

When the author says a choice was deliberate, **withdraw it immediately and do not re-raise it in any later pass.**

**Reproductions are out of scope for criteria 1–4.** When a figure deliberately reproduces a published one, its choices are inherited rather than chosen. Review it for fidelity to the source instead, and say so.

**Routing — this is what makes the verdicts above reachable.** Criteria 1–6 emit `flag` on their own terms; they do not consider scope or intent. Before reporting, apply `## Scope` and the rules above to every `flag`: it may be dropped (panel delegation), or reclassified `by-design?`. A criterion's bare "flag" is never the final verdict.

## Criteria

**1. Colormap**
Flag colormaps listed as unsafe in the colorblind reference above (jet, rainbow, red–green). Verify sequential vs diverging choice matches data type — a diverging map on an ordered non-diverging sequence (warming levels, time, dose) misreads as opposite signs, and a light midpoint can render a series member invisible. Assess luminance contrast. Warn if color is the sole encoding channel.

**2. Uncertainty**
Distinguish two different objects before judging:

- **Variability is the subject.** A PDF, histogram, violin, box, or ensemble-spread plot already represents spread. `pass` — do not ask for a confidence band around a density.
- **A point estimate or derived scalar is claimed** (mean, trend, ratio, probability, count, fraction). Estimation uncertainty is then required: CI, error bars, ensemble range, or shading. Flag if absent. Significance masking does **not** satisfy this — stippling is a binary test result, and no interval is recoverable from it.

Before prescribing a band, check whether the inputs to compute one are present. If only aggregated output is available, report that instead of prescribing a fix.

**3. Axes**
Labels and units on all axes. Ticks legible. Scale: for a **positive-definite** quantity, flag if plotted values span **≥2 orders of magnitude on a linear axis** — and compute the span rather than asserting it (e.g. "daily rainfall 0.3–420 mm = 3.1 decades"). This test does **not** apply to signed anomalies (log is undefined) or to probability densities (a tail always →0, and log destroys the area comparison a density exists to convey). Flag a truncated axis or colorbar floor that renders small nonzero values identically to zero. Flag inconsistent limits across panels that invite cross-panel comparison.

**4. Caption**
Judge self-containment **at the level of the artifact under review** (see `## Scope`): defines all symbols, abbreviations, and line styles; states n, time period, data source. Never infer a caption's contents from the image.

**5. Claim support**
The figure shows what the surrounding text asserts. Flag over-reach.
*Example over-reach: figure shows 2°C warming at one station; text claims "warming is accelerating across the region."*

**6. House style** *(only when `--style` is passed)*
Check colors against the CC palette above, graphic fonts (Effra/Bebas/Work Sans), and visual direction (minimal clutter, white space).

## Report

Open with one line stating the scope determined above: standalone vs panel, draft vs published, and any assumption made.

**[Criterion]**: `pass` / `flag` / `by-design?` / `cant-assess` — [detail; if flagged, specific fix]

*Example: **Colormap**: `flag` — Uses jet. Replace with viridis or cmo.thermal.*
*Example: **Colormap**: `by-design?` — Grayscale only, no redundant line styles. Ignore if the journal requires grayscale.*

## Archive

Unless `--no-archive` was passed: after emitting the report, write it verbatim to `<repo-root>/.ai/reviews/<YYYY-MM-DD>-figure-review[-<figure-slug>].md` (`mkdir -p "$(git rev-parse --show-toplevel)/.ai/reviews"`; suffix `-2`, `-3`… on filename collision). Best-effort — if the cwd isn't a git repo or the write fails, add a one-line note and move on; never alter the review itself. Probe the ignore with the **file path at repo root**, not the bare directory: if `git check-ignore -q "$(git rev-parse --show-toplevel)/.ai/reviews/probe.md"` exits non-zero, warn and suggest adding `.ai/` to `.gitignore`. (`git check-ignore -q .ai` false-negatives for the directory-form `.ai/` pattern whenever the directory does not yet exist.)

**Provenance header.** Prepend a YAML block to the **archived file only** (never to the
report shown to the user), so a report re-read months later is still interpretable — in
particular, so you can tell whether it predates a revision of this skill's criteria:

```yaml
---
skill: figure-review
skill-version: <toolkit version>
reviewed-repo: <repo basename> @ <short SHA>[ (dirty)]
cli: <claude --version>
date: <YYYY-MM-DD>
---
```

Collect the values with:

```bash
SD="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/figure-review}"; SD="${SD:-$HOME/.claude/skills/figure-review}"
cat "$SD/.version" 2>/dev/null || echo unknown    # skill-version ("unknown" under plugin install)
git rev-parse --short HEAD 2>/dev/null || echo unknown
git status --porcelain 2>/dev/null | head -1      # non-empty → append " (dirty)"
claude --version 2>/dev/null || echo unknown
```

`.version` is written into the deployed skill dir by `sync.sh push`; it is absent under a
plugin install, which is expected. Resolve any value that fails to `unknown` — never drop
the key, and never let a failed lookup block or alter the archive.

## Does not

- Make aesthetic or branding calls beyond the six criteria.
- Rewrite plotting code unless explicitly asked after the report.
