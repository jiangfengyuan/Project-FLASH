# Agent instruction drafts

> **Status: Drafts — not active.** These files do nothing while they sit here. An agent tool only picks up an instruction file at the location and name it expects (normally the repository root).

> **中文摘要**：这里是 `AGENTS.md`、`CLAUDE.md` 与 Kimi Code 指令文件的草稿，目前不生效。所有者需先将其与工作区中已有的 `AGENTS.md`（不在本仓库内，本次未能读取）对照，确认无冲突后再放到仓库根目录。三份文件都只是 `docs/standards/` 的适配层，不重复、不改写规则。

## Why drafts

The hardening documents on `feat/paper-writing` refer to a parent `AGENTS.md` kept in the owner's workspace, outside this repository. It could not be read when these standards were written, so its compatibility with them has not been assessed. Placing new instruction files at the root would make them live for every agent as soon as the branch merges, possibly contradicting that file. Activation is owner decision OD-14.

## Files

| Draft | Intended location | Read by |
| --- | --- | --- |
| [AGENTS.proposed.md](AGENTS.proposed.md) | `/AGENTS.md` | OpenAI Codex and other tools that follow the `AGENTS.md` convention |
| [CLAUDE.proposed.md](CLAUDE.proposed.md) | `/CLAUDE.md` | Claude Code |
| [KIMI.proposed.md](KIMI.proposed.md) | To be confirmed against Kimi Code's documentation; if it reads `AGENTS.md`, this draft is unnecessary | Kimi Code |

## Activation checklist

1. Compare each rule in the workspace-level `AGENTS.md` with `docs/standards/`. For every difference decide which text wins and update the standard, not the adapter.
2. Confirm which file name and location each tool reads.
3. Copy the drafts to their locations in one PR that touches nothing else.
4. Keep the adapters short. If a rule is needed, add it to a standard and reference it.
