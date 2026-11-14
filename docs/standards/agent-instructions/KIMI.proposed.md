# Kimi Code instructions (draft — not active)

Kimi Code adapter for Project Flash. The file name and location Kimi Code reads have not been confirmed; check its documentation before activating this draft. If it reads `AGENTS.md`, delete this draft and use that file alone.

The project rules are in `AGENTS.md` and `docs/standards/`. Read `AGENTS.md` first and follow it in full. This file adds only what is specific to Kimi Code.

本项目的规则以 `AGENTS.md` 与 `docs/standards/` 为准，请先完整阅读 `AGENTS.md`。本文件只补充 Kimi Code 的特有事项，不重复也不改写任何规则。

## Kimi Code specifics

- **Branch prefix:** `kimi/<topic>`.
- **Language:** identifiers, file names, JSON keys, resource names and branch names are ASCII. Comments, commit bodies and handoffs may be Chinese or English (FS-NAME-16). The Simplified Chinese column of the localization catalog is source text: edit it only under a task that covers `docs/i18n/`.
- **Provider cap:** no more than two models from the same provider active on the project at once (FS-AGENT-05).
- **No prior convention exists for Kimi Code in this repository.** Do not infer one from `claude/…` or `codex/…` branch history; follow the task brief.
- **Translations:** output produced by a model is recorded as `machine`. Never mark a translation `reviewed` (FS-L10N-31).
