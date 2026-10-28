---
name: auto-router
description: Route work to the cheapest model that does it well (Haiku/Sonnet/Opus subagents). Use at the start of any multi-step task: coding, research, writing, file or data work.
---

# Auto Router

Goal: lower token and usage cost WITHOUT lowering quality. The main model (Sonnet, medium effort) orchestrates and talks to the user; substantial self-contained work goes to subagents via the Agent tool's `model` parameter. Decide silently and fast; this skill should cost almost nothing. Quality always wins over savings: when a downgrade could plausibly hurt the result, don't downgrade.

Hard facts: subagents cannot start subagents in this chat environment (Claude Code allows nesting, but it is not needed). All coordination happens from the main session. The user never has to set model or effort: effort comes from the main session default, and heavy thinking is bought by sending the hard part to Opus.

## Step 1: Inline or delegate?

Do it INLINE (no subagent) when any of these hold:
- conversation, a quick answer, advice, a single lookup or short edit
- roughly 5 tool calls or fewer
- it depends on nuance from this conversation that is hard to hand over

A subagent starts from zero (no chat history), so delegation only pays off for substantial, self-contained chunks. Never delegate what is cheaper to just do.

## Step 2: Pick the tier

**haiku**: mechanical AND easy to verify
- extract or convert data (PDF/CSV/JSON/XLSX), clean data with explicit rules
- bulk reading, sweeping folders, collecting facts from search results
- renaming, reformatting, boilerplate, simple scripts with a clear spec
- never for anything where a subtle mistake would go unnoticed

**sonnet**: default for real work
- most coding, debugging, refactoring, tests
- research with synthesis, comparisons, reports
- drafting and editing documents, decks, artifacts, posts

**opus**: where judgment decides quality (use it, don't ration it here)
- PLANNING of any non-trivial task: new features, multi-file changes, ambiguous requirements, architecture, anything where a wrong plan wastes more than the Opus call
- a problem that survived two attempts
- high-stakes output (legal, financial, security, data loss, investor-facing)
- independent REVIEW of high-stakes work, by a fresh agent that did not write it

**fable**: only when the user explicitly asks.

When unsure between two tiers: higher for planning, review and final synthesis; lower for searching and bulk gathering.

## Step 3: Delegate well

- Self-contained prompt: goal, inputs (paths, URLs, data), constraints, acceptance criteria, exact output format.
- Cap reports (about 150 words); big outputs go to files, not into the reply.
- Independent chunks run in parallel in one turn, only if they do not touch the same files.
- Typical pipeline for substantial work: haiku gathers -> opus plans (short, with checkable acceptance criteria) -> sonnet builds the chunks -> main session verifies -> opus reviews only if high-stakes.
- Follow-ups to the same subagent go through SendMessage (keeps context, saves tokens).

## Quality gates (never skip)

1. Never accept "done" on a subagent's word. Verify: run the code or tests, open the file, check a sample against the source, recompute key numbers.
2. Failure ladder: fail once, retry with a sharper brief at the same tier; fail twice, escalate one tier or have Opus diagnose. Never drop to a weaker tier after a failure.
3. For high-stakes deliverables, the reviewer must be a fresh Opus agent given the criteria and the output, NOT the author's self-assessment.
4. If a subagent reports a blocker or ambiguity, resolve it yourself or ask the user; do not let it guess.

## Depending on the main model

- Main = Sonnet (recommended): do small work inline; plan and review on Opus; build and research on Sonnet; gather on Haiku.
- Main = Opus: keep conversation, judgment and synthesis; push mechanical and bulk work down.
- Main = Haiku: escalate anything needing judgment to Sonnet or Opus.

## Output discipline

- Don't narrate routing. At most one short clause in the final summary when it mattered (e.g. "plan reviewed on Opus").
- Keep your own replies short; savings vanish if the orchestrator writes long recaps.
