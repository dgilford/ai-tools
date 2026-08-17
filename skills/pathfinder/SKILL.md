---
name: pathfinder
description: SLASH COMMAND — type /pathfinder to get a navigable map of every skill and subagent and when to reach for each. Resolves the reviewer-2-vs-panel decision. Use when unsure which skill or agent to invoke, or when orienting a new session.
disable-model-invocation: true
catalog:
  order: 130
  summary: 'Router: a navigable map of every skill and subagent and when to reach for each; resolves the reviewer-2-vs-panel review decision.'
---

# Skill & Agent Router

Type `/pathfinder` when you need to know which skill or subagent to reach for.
Nothing here fires automatically; this is a navigation aid only.

---

## Session lifecycle

```
Start of session   →  /pickup
                         ↓ (do work)
End of session     →  /handoff           writes .ai/HANDOFF.md, then calls /evolve-claude-md
Standalone update  →  /evolve-claude-md  promote session knowledge to CLAUDE.md only
```

---

## Skills — user-invoked (type the slash command explicitly)

| Skill | Command | Reach for it when… |
|---|---|---|
| repo-init | `/repo-init [--package]` | Starting a new repo (or retrofitting an old one): scaffolds the standard structure — research mode by default, `--package` for a distributable library. Idempotent |
| pickup | `/pickup` | Starting a new session; reconstructs context from `.ai/HANDOFF.md`. Named `pickup`, not `resume`, so it doesn't shadow Claude Code's built-in `/resume` session picker |
| handoff | `/handoff` | Ending a session or switching agents; calls `evolve-claude-md` internally |
| evolve-claude-md | `/evolve-claude-md` | Standalone CLAUDE.md update without a full handoff |
| grill-me | `/grill-me` | Stress-testing a plan or design before implementing; thin launcher for the `grilling` core |
| slack-message | `/slack-message` | Drafting an internal Slack update grounded in git context |
| create-alert | `/create-alert [--spec-only]` | Getting pinged on Slack when something changes/happens: grills a "tell me when X" ask into a testable trigger, dry-runs it, and (on sign-off) creates a scheduled cloud routine. `--spec-only` stops at the spec |
| tab-setup | `/tab-setup [all]` | Naming / coloring this Claude Code tab; `all` recolors every active session |
| write-new-skill | `/write-new-skill` | Scaffolding a new skill from scratch |
| spot-ai | `/spot-ai [path \| pasted text]` | Checking prose for **AI markers**: gray-list style tells (lane 1) and generation-mechanism substance tells like fabricated provenance or invented first-person testimony (lane 2). Flags only. Not a copy-editor — it reports AI markers, not writing advice |
| ai-review | `/ai-review` | Full comprehensive repo/project review; orchestrates code-review/security-review/unstale/overbaked/reviewer-2 in parallel and adds gap-hunting + grounded ideation + prioritized synthesis. Run on fable at high+ effort |
| pathfinder | `/pathfinder` | This router |

## Skills — model-invokable (reachable by the model or another skill mid-task)

| Skill | Reach for it when… |
|---|---|
| `grilling` | Stress-testing a plan one decision at a time — and *proactively* before a step that changes running state, grabs a shared resource (GPUs/ports/memory), or could invalidate an earlier decision. `/grill-me` is the explicit launcher |
| `figure-review` | User shares or references a figure/plot and wants it checked for publication readiness |
| `lit-review` | Searching or synthesizing scientific literature; citation checks from a review flow |
| `overbaked` | Auditing any artifact for over-engineering, verbosity, or scope creep |
| `reviewer-2` | Quick generalist stress-test of a claim, result, or section (any domain) |
| `unstale` | Cleaning up dead imports, stale comments, resolved TODOs after a refactor |
| `evolve-claude-md` | Promoting session knowledge to CLAUDE.md (called by `handoff`; also invokable standalone) |

---

## Subagents — domain reviewer panel

Subagents are spawned with the Agent tool (`subagent_type:`), not slash commands.
All four are **review-only** (report findings; never rewrite).

| Subagent | Domain | Reach for it when… |
|---|---|---|
| `attribution-reviewer` | Climate attribution | An attribution claim, result, or draft section needs expert scrutiny (PR/OR/ChIP, storyline, D&A) |
| `meteo-reviewer` | Meteorology (AMS CCM) | A weather analysis or mechanistic argument needs dynamical / thermodynamic review |
| `stats-reviewer` | Statistics / ML | A statistical analysis, methods section, or quantitative result needs estimator/causal/inference review |
| `scicomm-reviewer` | Science communication | A public-facing product (article, press release, talk abstract) needs communication-effectiveness review |

---

## Review decision tree

```
Need a review?
│
├── Quick generalist stress-test — one skill, any domain, fast
│   → /reviewer-2
│     Baseline, counterfactual, alternatives, uncertainty consistency.
│     No domain expertise assumed.
│
├── Deep single-domain review — expert read on one dimension
│   ├── Attribution claim / result     → attribution-reviewer subagent
│   ├── Weather / synoptic mechanism   → meteo-reviewer subagent
│   ├── Statistical analysis / ML      → stats-reviewer subagent
│   └── Public-facing science product  → scicomm-reviewer subagent
│
└── Full multi-lens review — manuscript, full section, ≥2 dimensions
    → Spawn the relevant subset of the 4 subagents in a SINGLE message
      (parallel, independent — no cross-anchoring).
      Synthesize findings after all return.
      Use /reviewer-2 first if you want a fast generalist pass before the panel.
```

### When NOT to use the panel

- Single-domain question → one reviewer, not all four.
- `/reviewer-2` covers the generalist case; don't over-convene the panel for a claim check.
- **Prose checks split three ways:** `/spot-ai` = does this read as machine-written (AI markers only) · `/overbaked` = is it over-engineered or verbose · `/reviewer-2` = is the claim defensible. spot-ai deliberately refers the other two out rather than duplicating them.
- `scicomm-reviewer` is for public-facing products, not internal methods or data.

### Citing literature during a review

Any reviewer can flag missing citations. To retrieve them, route to `/lit-review`
(Zotero, arxiv, bioRxiv, Google Scholar, Consensus).

---

## Composition rule (for skills that call other skills)

A user-invoked skill may call model-invokable skills; never another user-invoked one.
(Examples: `handoff` → `evolve-claude-md`; `grill-me` → `grilling`.)
