#!/usr/bin/env bash
# Sync skills and agents between this repo and ~/.claude/
#
# Usage:
#   ./scripts/sync.sh push             — deploy skills/ → ~/.claude/skills/; agents/ → ~/.claude/agents/
#   ./scripts/sync.sh push <name>...   — deploy only the named skills/agents (plus hard dependencies)
#   ./scripts/sync.sh pull             — pull ~/.claude/skills/ → skills/; ~/.claude/agents/ → agents/
#   ./scripts/sync.sh lint             — lint frontmatter, skill refs, repo-init templates, extension drift, shell (used by CI)
#
# Named push: each <name> is auto-detected as a skill (skills/<name>/) or an
# agent (agents/<name>.md). Skills that invoke other skills at runtime pull
# those in automatically (see skill_deps) so a partial install can't silently
# no-op. Hook/statusline registration runs only when tab-setup is included.
#
# Machine-local exclusions: list skill dir names (one per line) in
# ~/.claude/sync-skills-exclude to skip them during `push` on this machine only.
# An explicitly named skill overrides its exclusion; a dependency-added one
# does not.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DEST="$HOME/.claude/skills"
AGENTS_SRC="$REPO_DIR/agents"
AGENTS_DEST="$HOME/.claude/agents"
# External skill repos — cloned/updated into REPO_DIR on push.
# Format: "owner/repo:dest_subdir"
EXTERNAL_SKILLS=(
  "dgilford/tab-setup:tab-setup"
)

# Machine-local push exclusions. Names (one skill dir per line, # comments ok)
# listed in ~/.claude/sync-skills-exclude are skipped by `push` on THIS machine
# only — the file is not tracked in the repo, so the choice stays machine-local.
EXCLUDE_FILE="$HOME/.claude/sync-skills-exclude"

is_excluded() {
  [ -f "$EXCLUDE_FILE" ] || return 1
  local name="$1" line
  while IFS= read -r line; do
    line="${line%%#*}"                       # strip comments
    line="$(echo "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && [ "$line" = "$name" ] && return 0
  done < "$EXCLUDE_FILE"
  return 1
}

usage() {
  echo "Usage: $0 [push [name...]|pull|lint|orphans]"
  echo "  push           Deploy all skills to ~/.claude/skills/ and agents to ~/.claude/agents/"
  echo "  push <name>... Deploy only the named skills/agents, plus their hard dependencies"
  echo "  pull           Pull skills from ~/.claude/skills/ into repo"
  echo "  lint           Lint frontmatter, skill references, repo-init templates, claude-tab extension drift, and tracked shell scripts"
  echo "  orphans        Report deployed skills/agents with no repo counterpart (read-only; deletes nothing)"
  exit 1
}

# `push` is an overlay (never deletes), so a skill or agent renamed or removed in
# the repo keeps resolving from ~/.claude/, and `pull` re-adds it to the repo.
# Read-only: it cannot distinguish "orphaned by a rename" from "installed from a
# plugin bundle", so it reports and never deletes.
#
# Names are printed with `%q` deliberately. This function inspects a directory
# that third-party bundles write to, so a name may contain spaces, newlines, or
# ANSI escapes — raw `echo` would let one forge a section header or repaint the
# report, defeating the audit. %q also makes each path safe to copy-paste.
# Known blind spots: dot-prefixed deployed dirs (the `*/` glob skips them), and
# files deleted from inside a still-tracked skill.
report_orphans() {
  local found=0 name
  echo "Deployed skills with no skills/<name>/ in this repo:"
  for skill_dir in "$SKILLS_DEST"/*/; do
    [ -d "$skill_dir" ] || continue
    name=$(basename "$skill_dir")
    if [ ! -d "$SKILLS_SRC/$name" ]; then
      printf '  ? %q\n' "$name"
      found=$((found + 1))
    fi
  done
  [ "$found" -eq 0 ] && echo "  (none)"
  local agents_found=0
  echo "Deployed agents with no agents/<name>.md in this repo:"
  for agent_file in "$AGENTS_DEST"/*.md; do
    [ -f "$agent_file" ] || continue
    name=$(basename "$agent_file")
    if [ ! -f "$AGENTS_SRC/$name" ]; then
      printf '  ? %q\n' "$name"
      agents_found=$((agents_found + 1))
    fi
  done
  [ "$agents_found" -eq 0 ] && echo "  (none)"
  echo
  echo "Third-party skills are expected here. Renamed or removed repo skills are not —"
  echo "delete those by hand before the next \`pull\` re-adds them to the repo:"
  printf '  rm -rf %q/<name>\n' "$SKILLS_DEST"
  echo "(Files deleted from inside a still-tracked skill won't show here.)"
}

# Co-deployed runtime dependencies: a launcher or orchestrator that invokes another
# skill mid-run degrades without it — some silently no-op (grill-me), others
# fall back to a weaker inline path (repo-init asks its intake questions itself).
# Named pushes expand these transitively. (lint_skill_refs catches in-repo
# renames; this map keeps *partial installs* coherent — update it when wiring changes.)
skill_deps() {
  case "$1" in
    grill-me)     echo "grilling" ;;
    commit-batch) echo "commit-batching" ;;
    handoff)      echo "worklog evolve-claude-md" ;;
    ai-review)    echo "unstale overbaked reviewer-2" ;;
    repo-init)    echo "grilling" ;;
  esac
}

# Named-push resolution state (space-separated; bash-3.2-safe, no assoc arrays).
RESOLVED_SKILLS=""
RESOLVED_AGENTS=""
EXPLICIT_NAMES=""

is_explicit() { case "$EXPLICIT_NAMES" in *" $1 "*) return 0 ;; esac; return 1; }

is_resolved() { case " $RESOLVED_SKILLS $RESOLVED_AGENTS " in *" $1 "*) return 0 ;; esac; return 1; }

# Classify a name as skill or agent and recurse into its hard dependencies.
resolve_name() {
  local name="$1" dep
  is_resolved "$name" && return 0
  if [ -d "$SKILLS_SRC/$name" ]; then
    RESOLVED_SKILLS="$RESOLVED_SKILLS $name"
    for dep in $(skill_deps "$name"); do
      resolve_name "$dep"
    done
  elif [ -f "$AGENTS_SRC/$name.md" ]; then
    RESOLVED_AGENTS="$RESOLVED_AGENTS $name"
  else
    echo "✗ '$name' is neither a skill (skills/$name/) nor an agent (agents/$name.md)" >&2
    echo "  skills: $(cd "$SKILLS_SRC" && printf '%s ' */ | tr -d '/')" >&2
    echo "  agents: $(cd "$AGENTS_SRC" && for f in *.md; do printf '%s ' "${f%.md}"; done)" >&2
    exit 1
  fi
}

deploy_skill() {
  mkdir -p "$SKILLS_DEST/$1"
  cp -r "$SKILLS_SRC/$1/." "$SKILLS_DEST/$1/"
  # Stamp the toolkit version into the DEPLOYED copy so an archived review report
  # can name the skill version that produced it (read back by each report-producing
  # skill's ## Archive section). The deployed dir is not a git checkout, so this
  # file is the only way that provenance is reachable at review time.
  # Never written to $SKILLS_SRC, and gitignored (skills/*/.version) so that
  # `sync.sh pull` cannot round-trip it back into the repo as a tracked file.
  printf '%s\n' "$(git -C "$REPO_DIR" describe --always --dirty --tags 2>/dev/null || echo unknown)" \
    > "$SKILLS_DEST/$1/.version"
}

deploy_agent() {
  mkdir -p "$AGENTS_DEST"
  cp "$AGENTS_SRC/$1.md" "$AGENTS_DEST/$1.md"
}

sync_external_skills() {
  for entry in "${EXTERNAL_SKILLS[@]}"; do
    local repo="${entry%%:*}"
    local dest="${entry##*:}"
    local dest_path="$REPO_DIR/$dest"
    if [ -d "$dest_path/.git" ]; then
      echo "  ↻ $repo (pull)"
      local before after
      before=$(git -C "$dest_path" rev-parse HEAD)
      git -C "$dest_path" pull --ff-only --quiet
      after=$(git -C "$dest_path" rev-parse HEAD)
      # Review gate: fetched scripts become a SessionStart hook, so never deploy
      # unseen upstream changes. Show what changed and require explicit consent
      # (SYNC_EXTERNAL_ACCEPT=1 for non-interactive runs).
      if [ "$before" != "$after" ]; then
        echo "  ! $repo changed since last sync:"
        git -C "$dest_path" log --oneline "$before..$after" | sed 's/^/      /'
        git -C "$dest_path" diff --stat "$before" "$after" -- scripts/ vscode-extension/ | sed 's/^/      /'
        if [ "${SYNC_EXTERNAL_ACCEPT:-0}" != "1" ]; then
          printf "  Deploy these upstream changes? [y/N] "
          read -r reply
          if [ "$reply" != "y" ] && [ "$reply" != "Y" ]; then
            echo "  ✗ declined — rolling back to $before (re-run to review again)"
            git -C "$dest_path" reset --hard --quiet "$before"
            continue
          fi
        fi
      fi
    else
      echo "  ↓ $repo (clone)"
      git clone --quiet "https://github.com/$repo" "$dest_path"
    fi
    # Copy scripts (and vscode-extension if present) into the skills deploy dir
    local skill_name
    skill_name=$(basename "$dest")
    mkdir -p "$SKILLS_SRC/$skill_name/scripts"
    cp -r "$dest_path/scripts/." "$SKILLS_SRC/$skill_name/scripts/"
    if [ -d "$dest_path/vscode-extension" ]; then
      mkdir -p "$SKILLS_SRC/$skill_name/vscode-extension"
      cp -r "$dest_path/vscode-extension/." "$SKILLS_SRC/$skill_name/vscode-extension/"
      echo "  → vscode-extension synced"
    fi
  done
}

# Validate that every agent's and skill's YAML frontmatter parses and has a
# name, and that descriptions stay under the selection-context cap.
# Catches the silent-drop failure mode where a malformed .md deploys fine but
# the agent/skill never registers (e.g. an unquoted multi-line description
# containing a ": " colon-space, which YAML reads as a stray mapping key).
# Aborts the push so the breakage surfaces here, not later.
lint_frontmatter() {
  python3 - "$AGENTS_SRC" "$SKILLS_SRC" <<'EOF'
import glob, os, re, sys
agents_dir, skills_dir = sys.argv[1], sys.argv[2]
try:
    import yaml
except ImportError:
    print("  ! PyYAML not installed — skipping frontmatter lint", file=sys.stderr)
    sys.exit(0)

targets = sorted(glob.glob(os.path.join(agents_dir, "*.md")))
targets += sorted(glob.glob(os.path.join(skills_dir, "*", "SKILL.md")))

DESC_CAP = 1536  # description chars kept in the model's selection context

failures = []
for path in targets:
    fn = os.path.relpath(path, os.path.dirname(agents_dir))
    text = open(path).read()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        failures.append(f"{fn}: no YAML frontmatter block")
        continue
    try:
        data = yaml.safe_load(m.group(1))
    except yaml.YAMLError as e:
        msg = str(e).splitlines()[0]
        failures.append(f"{fn}: frontmatter does not parse ({msg})")
        continue
    if not isinstance(data, dict) or not data.get("name"):
        failures.append(f"{fn}: frontmatter missing required 'name' field")
        continue
    desc = data.get("description") or ""
    if len(desc) > DESC_CAP:
        failures.append(f"{fn}: description is {len(desc)} chars (cap {DESC_CAP})")

if failures:
    print("  ✗ frontmatter lint failed:", file=sys.stderr)
    for f in failures:
        print(f"      {f}", file=sys.stderr)
    print("    Fix: quote multi-line descriptions, e.g. description: '...'", file=sys.stderr)
    sys.exit(1)
print(f"  ✓ frontmatter lint passed ({len(targets)} files)")
EOF
}

# Verify every backticked `/slash-command` resolves to a real skill in skills/
# (or a known Claude Code built-in / delegated command).
# Catches a launcher whose target was renamed or deleted — e.g. grill-me's body
# is just "Run a `/grilling` session.", so if `grilling` vanished the launcher
# would deploy fine and silently no-op. Frontmatter lint can't see this.
#
# Scope: skill bodies and their companion .md files (at any depth), agent files,
# and the prose docs (CLAUDE.md, README.md, docs/**.md) — renames routinely land
# in skills/ but not in the surrounding prose, and nothing checked the prose.
lint_skill_refs() {
  python3 - "$SKILLS_SRC" "$AGENTS_SRC" <<'EOF'
import glob, os, re, sys
# normpath first: a trailing slash on the skills arg would otherwise make
# dirname() return the skills dir itself, silently dropping the prose docs from
# scope and mangling every relpath used for SCOPED_REFS matching.
skills_dir, agents_dir = os.path.normpath(sys.argv[1]), os.path.normpath(sys.argv[2])
repo_root = os.path.dirname(skills_dir)

known = {os.path.basename(os.path.dirname(p))
         for p in glob.glob(os.path.join(skills_dir, "*", "SKILL.md"))}

# Slash commands that are NOT skills in this repo and so are legitimate to
# reference ANYWHERE: Claude Code built-ins plus the external review commands
# ai-review delegates to. Add to this set when a body starts citing a new
# built-in.
BUILTINS = {
    "code-review", "security-review",
    "rename", "color", "clear", "compact", "model", "effort", "review",
    "help", "cost", "fast", "memory", "plugin",
}

# Generic prose stand-ins, not commands — `/slash` and `/slash-command` appear
# when the docs talk ABOUT the syntax rather than naming a command. Kept
# separate from BUILTINS so that list stays an honest inventory of real
# built-ins. For a new placeholder prefer the angle form (`/<name>`), which the
# regex already ignores, over growing this set.
PLACEHOLDERS = {"slash", "slash-command"}

# (repo-relative path, command) pairs — a reference legitimate only in the ONE
# file that has a reason to name it. Prefer this over BUILTINS: a repo-wide
# entry silently disables detection everywhere else.
#
# /resume is the built-in past-session picker. The repo's own skill is named
# `pickup` precisely so it doesn't shadow it, and these files cite `/resume` by
# name to explain why.
SCOPED_REFS = {
    ("CLAUDE.md", "resume"),
    ("docs/harness-behavior.md", "resume"),
    ("skills/pickup/SKILL.md", "resume"),
    ("skills/pathfinder/SKILL.md", "resume"),
}

# Optional args before the closing backtick — bracket form (`/repo-init [--package]`,
# `/tab-setup [all]`) or flag form (`/unstale --auto`) — are part of the reference.
# Caveat: the arg group can also match non-command prose shaped like `/word [x]`
# or `/word --x`; no such instance exists in the tree, but if one appears, prefer
# rewording the prose over widening this regex.
REF = re.compile(r"`/([a-z][a-z0-9-]+)(?: (?:\[[^`\]]*\]|--[^`]+))?`")
targets = sorted(glob.glob(os.path.join(skills_dir, "*", "SKILL.md")))
targets += sorted(glob.glob(os.path.join(skills_dir, "*", "**", "*.md"), recursive=True))
targets += sorted(glob.glob(os.path.join(agents_dir, "*.md")))
targets += [os.path.join(repo_root, "CLAUDE.md"), os.path.join(repo_root, "README.md")]
targets += sorted(glob.glob(os.path.join(repo_root, "docs", "**", "*.md"), recursive=True))
# The two skills globs overlap on SKILL.md; dedupe, keep a stable order, and
# tolerate a missing CLAUDE.md/README.md (a consumer repo may not have both).
targets = sorted({p for p in targets if os.path.isfile(p)})

failures = []
for path in targets:
    fn = os.path.relpath(path, repo_root)
    # encoding is explicit: this lint reads the widest set of files in the repo,
    # and Windows' cp1252 default raises UnicodeDecodeError on the non-ASCII
    # already present in these bodies.
    with open(path, encoding="utf-8") as fh:
        body = fh.read()
    for name in sorted(set(REF.findall(body))):
        if (name in known or name in BUILTINS or name in PLACEHOLDERS
                or (fn, name) in SCOPED_REFS):
            continue
        failures.append(f"{fn}: references `/{name}`, neither a skill in skills/ nor a known built-in")

if failures:
    print("  ✗ skill-reference lint failed:", file=sys.stderr)
    for f in failures:
        print(f"      {f}", file=sys.stderr)
    print("    Fix: correct the reference, add the missing skill, allowlist a new built-in in", file=sys.stderr)
    print("    BUILTINS, or scope a one-file exception in SCOPED_REFS (prefer SCOPED_REFS).", file=sys.stderr)
    sys.exit(1)
print(f"  ✓ skill-reference lint passed ({len(targets)} files)")
EOF
}

# Templates a skill stamps into OTHER repos (repo-init's TEMPLATES.md) are the
# one artifact class frontmatter/ref lints can't see — a broken pyproject or CI
# block ships silently. Delegate to the smoke test, which parses every fenced
# toml/yaml/python block and asserts the gitignore tracked/ignored contract.
lint_templates() {
  smoke="$(dirname "$0")/../tests/smoke_repo_init.py"
  if [ -f "$smoke" ]; then
    python3 "$smoke" || exit 1
  else
    echo "  ! tests/smoke_repo_init.py missing — repo-init templates NOT linted" >&2
  fi
}

# spot-ai ships a measurement script whose definitions ARE the calibration behind
# GRAYLIST.md's reference rates: change a regex and every published rate silently
# stops meaning what it says. The fixture asserts doc counts, the JSONL contract,
# and the bug classes found by execution in review (NaN emitted into a profile,
# list tokens counted as punch fragments, non-dict records crashing a run).
lint_spot_ai_rates() {
  fixture="$(dirname "$0")/../skills/spot-ai/tests/test_measure_rates.py"
  if [ -f "$fixture" ]; then
    python3 "$fixture" >/dev/null || { python3 "$fixture"; exit 1; }
    echo "  ✓ spot-ai measurement fixture passed"
  else
    echo "  ! skills/spot-ai/tests/test_measure_rates.py missing — measurement definitions NOT linted" >&2
  fi
}

# The claude-tab extension exists in two places on purpose: tab-setup/ (the fork
# checkout) is what actually deploys, but it's gitignored here, so the tracked
# copy in vscode-extension/ is the only one CI can review and unit test. They
# drifted for weeks in both directions — the fork missed a lib/ the deployed
# install.sh never copied (extension dead on arrival, silent), the tracked copy
# missed the CLEAR_LINE prompt fix. Authoring order is fork first, then mirror
# to vscode-extension/; this fails the push when the mirror was skipped.
# Skipped when tab-setup/ is absent (fresh clone, CI) — nothing to compare.
lint_vscode_extension() {
  local tracked fork
  tracked="$REPO_DIR/vscode-extension"
  fork="$REPO_DIR/tab-setup/vscode-extension"
  [ -d "$fork" ] || return 0
  if [ ! -d "$tracked" ]; then
    echo "  ! vscode-extension/ missing — claude-tab extension NOT drift-checked" >&2
    return 0
  fi
  if ! diff -r "$tracked" "$fork" >/dev/null 2>&1; then
    echo "  ✗ claude-tab extension drift: vscode-extension/ != tab-setup/vscode-extension/" >&2
    diff -r "$tracked" "$fork" 2>&1 | sed 's/^/      /' >&2
    echo "    Fix: author in tab-setup/vscode-extension/ (the fork, which deploys), then" >&2
    echo "    mirror into vscode-extension/ (the tracked, CI-tested copy) so both match." >&2
    exit 1
  fi
  echo "  ✓ claude-tab extension in sync (vscode-extension/ == fork)"
}

# Shell lint, delegated to scripts/lint-shell.sh so CI and this push gate check
# the same files. Was CI-only: an SC2115 landed on main because the local gate
# never ran shellcheck (it was installed, just not on PATH).
lint_shell() {
  local script="$REPO_DIR/scripts/lint-shell.sh"
  if [ -f "$script" ]; then
    bash "$script" || exit 1
  else
    echo "  ! scripts/lint-shell.sh missing — shell scripts NOT linted" >&2
  fi
}

install_startup_hook() {
  local config_dest="$HOME/.claude/session-init-config.json"
  local hook_cmd="bash ~/.claude/skills/tab-setup/scripts/hook-startup.sh"

  # session-init-config.json is still read by hook-startup.sh for the default_env reminder
  if [ ! -f "$config_dest" ]; then
    echo '{ "default_env": "" }' > "$config_dest"
    echo "  → session-init-config.json created at ~/.claude/"
  else
    echo "  → session-init-config.json already present, skipping"
  fi

  python3 - "$hook_cmd" <<'EOF'
import json, os, sys

hook_cmd = sys.argv[1]
settings_path = os.path.expanduser("~/.claude/settings.json")
if not os.path.exists(settings_path):
    print("  ! ~/.claude/settings.json not found, skipping hook merge", file=sys.stderr)
    sys.exit(0)

with open(settings_path) as f:
    settings = json.load(f)

hook_entry = {
    "matcher": "",
    "hooks": [{"type": "command", "command": hook_cmd}],
}
hooks = settings.setdefault("hooks", {})
existing = hooks.get("SessionStart", [])

if not any("hook-startup" in str(h) for h in existing):
    # Remove any stale session-init.py entries while we're here
    existing = [h for h in existing if "session-init" not in str(h)]
    existing.append(hook_entry)
    hooks["SessionStart"] = existing
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print("  → SessionStart hook added to ~/.claude/settings.json")
else:
    print("  → SessionStart hook already present, skipping")
EOF
}

install_statusline() {
  # Deploy the status-line command script and ensure settings.json references it.
  # Reconciles the statusLine block to settings/settings.json on every push, so
  # footer config changes propagate (a non-destructive merge silently skipped them).
  local script_src="$REPO_DIR/settings/statusline-command.sh"
  local script_dest="$HOME/.claude/statusline-command.sh"

  if [ ! -f "$script_src" ]; then
    echo "  ! settings/statusline-command.sh not found, skipping status line"
    return 0
  fi
  cp "$script_src" "$script_dest"
  chmod +x "$script_dest"
  echo "  → statusline-command.sh deployed to ~/.claude/"

  REPO_DIR="$REPO_DIR" python3 - <<'EOF'
import json, os
settings_path = os.path.expanduser("~/.claude/settings.json")
if not os.path.exists(settings_path):
    print("  ! ~/.claude/settings.json not found, skipping statusLine merge")
    raise SystemExit(0)

# Canonical statusLine block lives in the repo's settings/settings.json.
repo_settings = os.path.join(os.environ["REPO_DIR"], "settings", "settings.json")
with open(repo_settings) as f:
    desired = json.load(f)["statusLine"]

with open(settings_path) as f:
    settings = json.load(f)

if settings.get("statusLine") == desired:
    print("  → statusLine already up to date, skipping")
else:
    settings["statusLine"] = desired
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print("  → statusLine block reconciled in ~/.claude/settings.json")
EOF
}

[ "${1:-}" = "" ] && usage

case "$1" in
  push)
    shift
    if [ "$#" -gt 0 ]; then
      # Named push: deploy only the requested skills/agents (+ hard deps).
      EXPLICIT_NAMES=" $* "
      for name in "$@"; do
        resolve_name "$name"
      done
      # Refresh external checkouts only when one of them was requested.
      if is_resolved "tab-setup"; then
        echo "Syncing external skills"
        sync_external_skills
      fi
      echo "Linting skill + agent frontmatter"
      lint_frontmatter
      lint_skill_refs
      lint_templates
      lint_spot_ai_rates
      lint_vscode_extension
      lint_shell
      if [ -n "$RESOLVED_SKILLS" ]; then
        echo "Deploying skills → $SKILLS_DEST"
        for name in $RESOLVED_SKILLS; do
          if is_excluded "$name" && ! is_explicit "$name"; then
            echo "  ⤫ $name (dependency; excluded on this machine via $EXCLUDE_FILE)"
            continue
          fi
          if is_explicit "$name"; then
            if is_excluded "$name"; then
              echo "  → $name (explicitly named — overriding machine-local exclusion)"
            else
              echo "  → $name"
            fi
          else
            echo "  + $name (auto-included dependency)"
          fi
          deploy_skill "$name"
        done
      fi
      if [ -n "$RESOLVED_AGENTS" ]; then
        echo "Deploying agents → $AGENTS_DEST"
        for name in $RESOLVED_AGENTS; do
          echo "  → $name.md"
          deploy_agent "$name"
        done
      fi
      # Settings registration is tab-setup's concern; skip it otherwise so a
      # one-skill install never touches ~/.claude/settings.json.
      if is_resolved "tab-setup"; then
        install_startup_hook
      fi
      echo "Done."
    else
      echo "Syncing external skills"
      sync_external_skills
      echo "Linting skill + agent frontmatter"
      lint_frontmatter
      lint_skill_refs
      lint_templates
      lint_spot_ai_rates
      lint_vscode_extension
      lint_shell
      echo "Deploying skills/ → $SKILLS_DEST"
      for skill_dir in "$SKILLS_SRC"/*/; do
        name=$(basename "$skill_dir")
        if is_excluded "$name"; then
          echo "  ⤫ $name (excluded on this machine via $EXCLUDE_FILE)"
          continue
        fi
        echo "  → $name"
        deploy_skill "$name"
      done
      echo "Deploying agents/ → $AGENTS_DEST"
      for agent_file in "$AGENTS_SRC"/*.md; do
        [ -f "$agent_file" ] || continue
        name=$(basename "$agent_file" .md)
        echo "  → $name.md"
        deploy_agent "$name"
      done
      install_startup_hook
      install_statusline
      echo "Done."
    fi
    ;;
  pull)
    echo "Pulling $SKILLS_DEST → skills/"
    for skill_dir in "$SKILLS_DEST"/*/; do
      name=$(basename "$skill_dir")
      echo "  ← $name"
      mkdir -p "$SKILLS_SRC/$name"
      cp -r "$skill_dir/." "$SKILLS_SRC/$name/"
    done
    echo "Pulling $AGENTS_DEST → agents/"
    mkdir -p "$AGENTS_SRC"
    for agent_file in "$AGENTS_DEST"/*.md; do
      [ -f "$agent_file" ] || continue
      name=$(basename "$agent_file")
      echo "  ← $name"
      cp "$agent_file" "$AGENTS_SRC/$name"
    done
    echo "Done. Review changes with: git diff skills/ agents/"
    ;;
  lint)
    lint_frontmatter
    lint_skill_refs
    lint_templates
    lint_spot_ai_rates
    lint_vscode_extension
    lint_shell
    ;;
  orphans)
    report_orphans
    ;;
  *)
    usage
    ;;
esac
