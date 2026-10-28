# claude-auto-router

Stop picking a model and effort level before every task. Keep **Sonnet at medium effort** as your
default and let it delegate the right work to the right model, without lowering quality.

```bash
curl -fsSL https://raw.githubusercontent.com/dm807cam/claude-auto-router/main/install.sh | bash
```

Then start a **new** Claude Code session and run `/agents` to confirm `architect`, `implementer`,
`explorer` and `reviewer` are listed.

Prefer to read before you run? Open [`install.sh`](install.sh); it only writes into `~/.claude`.

## What you get

| Piece | Model / effort | Job |
|---|---|---|
| Main session | Sonnet, medium (default) | Talks to you, does small work, orchestrates, runs the checks |
| `explorer` | Haiku, low | Codebase search and bulk reading |
| `architect` | Opus, high | Plans non-trivial changes, diagnoses bugs that survived two fixes |
| `implementer` | Sonnet, medium | Builds one chunk of the plan |
| `reviewer` | Opus, high | Independent review of high-stakes changes |

Effort is set per agent in its frontmatter, so heavy thinking happens only where it pays off and
you never touch `/effort`.

## Design choices (quality first)

- **Sonnet orchestrates, Opus does not.** Opus planning and review are short, high-value calls.
  Putting Opus in the middle of every worker report would burn your usage on bookkeeping.
- **Plan quality beats speed.** Non-trivial work gets an Opus plan with checkable acceptance criteria.
- **"Done" is verified, not trusted.** The main session runs tests/typecheck/lint/build itself and
  reads the diff. The reviewer never sees the implementer's self-assessment.
- **Failure ladder.** Fail once: retry with a sharper brief. Fail twice: the architect diagnoses.
  Never fall back to a weaker model after a failure.
- **Small stuff stays inline.** Roughly under five tool calls, it is cheaper to just do it.
- **Workers cannot spawn subagents**, so cost cannot snowball.

## What the installer changes

- `~/.claude/agents/{architect,implementer,explorer,reviewer}.md`
- A marked block (`<!-- router:begin -->` ... `<!-- router:end -->`) appended to `~/.claude/CLAUDE.md`
- `"model": "sonnet"` in `~/.claude/settings.json` (created if missing)

Any file it would change is backed up as `<file>.bak-<timestamp>`. Re-running updates in place.
Set `CLAUDE_DIR=/some/dir` to install somewhere other than `~/.claude`.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/dm807cam/claude-auto-router/main/install.sh | bash -s -- --uninstall
```

Removes the four agents (only if they carry this project's marker) and the CLAUDE.md block. Your
default model in `settings.json` is left as is.

## Claude chat (claude.ai)

[`skill/SKILL.md`](skill/SKILL.md) is the same routing logic as a skill for the chat app, where
subagents can be started with a model of your choice. Nesting is not available there.

## Customize

Edit the agent files in `~/.claude/agents/` (model, effort, `maxTurns`, tools) or the routing
block in `~/.claude/CLAUDE.md`. Re-running the installer overwrites them (with backups), so keep
your tweaks in copies if you re-run it.

## Notes

- Agents load at session start; restart Claude Code after installing.
- The `opus`, `sonnet` and `haiku` aliases resolve to the latest versions on the Anthropic API.
- Needs `bash`, `awk` and (optionally, for merging an existing `settings.json`) `python3`.

## License

MIT
