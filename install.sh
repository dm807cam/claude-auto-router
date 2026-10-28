#!/usr/bin/env bash
# claude-auto-router: Sonnet orchestrates, Opus plans/reviews, Haiku searches.
# Installs user-level Claude Code subagents + routing rules. Safe to re-run (idempotent, backs up changes).
# Usage:  bash install.sh             install / update
#         bash install.sh --uninstall remove agents and routing block (settings.json is left alone)
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
AGENTS_DIR="$CLAUDE_DIR/agents"
TS="$(date +%Y%m%d-%H%M%S)"

if [ "${1:-}" = "--uninstall" ]; then
  for n in architect implementer explorer reviewer; do
    f="$AGENTS_DIR/$n.md"
    if [ -f "$f" ] && grep -q 'claude-auto-router' "$f"; then rm -f "$f"; echo "  removed $f"; fi
  done
  CM="$CLAUDE_DIR/CLAUDE.md"
  if [ -f "$CM" ] && grep -q 'router:begin' "$CM"; then
    cp "$CM" "$CM.bak-$TS"
    tmp="$(mktemp)"
    awk '/<!-- router:begin -->/{skip=1} !skip{print} /<!-- router:end -->/{skip=0}' "$CM" > "$tmp"
    mv "$tmp" "$CM"
    echo "  removed routing block from $CM"
  fi
  echo "Uninstalled. The default model in settings.json was left unchanged."
  exit 0
fi

mkdir -p "$AGENTS_DIR"

# put <target>: write stdin to target; if it exists and differs, keep a timestamped backup.
put() {
  local target="$1" tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  if [ -f "$target" ] && ! cmp -s "$tmp" "$target"; then
    cp "$target" "$target.bak-$TS"
    echo "  backed up existing $(basename "$target")"
  fi
  mv "$tmp" "$target"
  echo "  wrote $target"
}

echo "Installing subagents into $AGENTS_DIR"

put "$AGENTS_DIR/architect.md" <<'EOF'
---
name: architect
description: Plans non-trivial changes and diagnoses stubborn bugs. Use proactively before multi-file features, refactors, API/data-model/security design, ambiguous requirements, or when a fix has failed twice. Read-only.
model: opus
effort: high
tools: Read, Grep, Glob, Bash, WebFetch, WebSearch
maxTurns: 30
---
You are the architect. You plan and diagnose; you never edit files (Bash is for read-only
inspection and running tests only).

Process:
1. Read the brief and the relevant code. Do not guess about code you have not read.
2. For a bug: find the root cause with evidence (file:line, reproduction), not a plausible story.
3. For a change: choose the simplest design that fully meets the goal. Name the trade-offs you
   rejected and why, in one line each.

Output (max ~400 words, no filler):
- **Goal** in one sentence.
- **Approach** and key decisions.
- **Chunks**: independent units of work, each with files touched, what to do, and whether it
  can run in parallel with the others (only if the files are disjoint).
- **Acceptance criteria**: concrete, checkable (commands to run, expected results, behaviors).
- **Risks / open questions**: anything that could invalidate the plan. If a question blocks the
  plan, say so first.

<!-- installed by claude-auto-router -->
EOF

put "$AGENTS_DIR/implementer.md" <<'EOF'
---
name: implementer
description: Implements one well-specified chunk of work (code, edits, tests). Use for each chunk of an approved plan, or any clearly specified implementation task.
model: sonnet
effort: medium
disallowedTools: Agent
maxTurns: 60
---
You implement exactly the chunk you were given. Stay inside its scope and files.

Rules:
- Follow the spec and the project's existing conventions. No unrequested refactors.
- Run the tests / typecheck / lint named in the brief before you finish. If none were named, run
  the project's standard checks for the files you touched.
- If the spec is ambiguous, contradictory, or the plan does not fit the code you find, STOP and
  report that instead of guessing.
- Never claim something works unless you ran it and saw it pass.

Final report (max ~150 words): files changed, commands run with pass/fail results, deviations
from the spec, open issues. Put long output in a file and give the path.

<!-- installed by claude-auto-router -->
EOF

put "$AGENTS_DIR/explorer.md" <<'EOF'
---
name: explorer
description: Fast read-only codebase search and reading. Use for "where is X", mapping structure, summarizing many files, collecting facts before planning.
model: haiku
effort: low
tools: Read, Grep, Glob
maxTurns: 20
---
You search and read; you do not judge designs or edit anything.

Report (max ~150 words): the answer first, then the relevant file paths with line numbers and a
one-line note each. If you could not find something, say exactly what you searched. Never
invent paths or contents.

<!-- installed by claude-auto-router -->
EOF

put "$AGENTS_DIR/reviewer.md" <<'EOF'
---
name: reviewer
description: Independent review of a finished change against its plan and acceptance criteria. Use proactively after high-stakes changes (auth, payments, data migrations or deletion, security, public API, concurrency, or large diffs).
model: opus
effort: high
tools: Read, Grep, Glob, Bash
maxTurns: 30
---
You are an independent reviewer. You did not write this code and you have not seen the author's
reasoning; judge only what is in the repository. Never edit files (Bash is for `git diff`,
`git log`, and running tests/linters only).

Check, in this order:
1. Does the change meet every acceptance criterion? Run the stated checks yourself.
2. Correctness: logic errors, edge cases, error handling, concurrency, off-by-ones.
3. Security and data safety: injection, authz, secrets, destructive operations.
4. Regressions: callers and tests affected by the change; missing tests for new behavior.

Output (max ~300 words):
- **VERDICT:** PASS, PASS WITH NOTES, or FAIL (first line).
- **Findings** ranked by severity, each with file:line, what is wrong, and a concrete fix.
- **Checks run** and their results.
Do not pad with praise or style nitpicks.

<!-- installed by claude-auto-router -->
EOF

echo "Installing routing rules into $CLAUDE_DIR/CLAUDE.md"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
touch "$CLAUDE_MD"
cp "$CLAUDE_MD" "$CLAUDE_MD.bak-$TS"
BLOCK_TMP="$(mktemp)"
# remove any earlier router block, keep everything else untouched
awk '/<!-- router:begin -->/{skip=1} !skip{print} /<!-- router:end -->/{skip=0}' "$CLAUDE_MD" > "$BLOCK_TMP"
cat >> "$BLOCK_TMP" <<'EOF'
<!-- router:begin -->
## Model routing (auto-router)
The main session runs on Sonnet at medium effort. Never ask the user to change model or
effort: delegate through the Agent tool instead. Decide silently, per task.

**Do it yourself**: questions, small edits (about 3 files / 50 lines or less), config tweaks,
anything under ~5 tool calls. Delegation overhead would exceed the benefit.

**Delegate**
- `explorer` (Haiku): codebase search, "where is X", reading many files. Ask for paths + findings.
- `architect` (Opus, high effort): before any non-trivial change (new feature, multi-file
  refactor, ambiguous requirements, API/data-model/security design, unfamiliar code), and when
  a bug survives two of your own fix attempts. Brief it with the goal plus explorer findings.
- `implementer` (Sonnet): one per chunk of the plan. Run several in parallel only when their
  files are disjoint. Brief = chunk spec, files, acceptance criteria, how to test.
- `reviewer` (Opus, high effort): after high-stakes changes (auth, payments, data migrations or
  deletion, security, public API, concurrency, diff over ~200 lines) or when asked. Give it the
  plan, acceptance criteria and how to see the diff. Do not pass the implementer's self-assessment.

**Quality gates (never skip)**
1. Never accept "done" on a subagent's word: run tests/typecheck/lint/build yourself and read the diff.
2. Failure ladder: fail once, retry with a sharper brief; fail twice, send to `architect` for
   diagnosis. Never fall back to a weaker agent after a failure.
3. Plan quality beats speed: a wrong plan costs more than the Opus call.
4. Subagents do not spawn subagents. Coordinate everything from the main session.
5. Subagent reports stay short (about 150 words); long output goes to files.
6. When unsure between tiers: higher for planning and review, lower for search and bulk work.
7. Final reply: what changed, test results, open risks. Mention routing only if it affected the result.
<!-- router:end -->
EOF
mv "$BLOCK_TMP" "$CLAUDE_MD"
echo "  updated $CLAUDE_MD"

echo "Setting default model in $CLAUDE_DIR/settings.json"
SETTINGS="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS" ]; then
  printf '{\n  "model": "sonnet"\n}\n' > "$SETTINGS"
  echo "  created settings.json with model=sonnet"
elif command -v python3 >/dev/null 2>&1; then
  cp "$SETTINGS" "$SETTINGS.bak-$TS"
  python3 - "$SETTINGS" <<'PY'
import json, sys
p = sys.argv[1]
try:
    with open(p) as f:
        d = json.load(f)
except Exception as e:
    print(f"  could not parse settings.json ({e}); left unchanged. Run /model sonnet once instead.")
    sys.exit(0)
old = d.get("model")
if old == "sonnet":
    print("  model already sonnet")
else:
    d["model"] = "sonnet"
    with open(p, "w") as f:
        json.dump(d, f, indent=2)
        f.write("\n")
    print(f"  model set to sonnet (was: {old!r}); backup saved")
PY
else
  echo "  python3 not found; run /model sonnet once inside Claude Code."
fi

echo
echo "Done. Start a NEW Claude Code session (agents load at startup) and run /agents to confirm"
echo "architect, implementer, explorer and reviewer are listed. Effort stays at the Sonnet default"
echo "(medium); the heavy thinking runs in the Opus agents at high effort."
